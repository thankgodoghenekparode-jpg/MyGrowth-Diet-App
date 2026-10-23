import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery, searchQuery, monthSchema, dateSchema } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { notifyAllMembers } from '../../services/notifications.js';
import { uploadLimiter } from '../../middleware/rateLimiters.js';
import { uploadSingle, persistUpload } from '../../middleware/upload.js';
import { validateFileType, validateFileSize } from '../../services/storage/index.js';

export const materialsRouter = Router();
export const filesRouter = Router();

const fileShape = (f) => ({
  id: f.id,
  originalName: f.originalName,
  mimeType: f.mimeType,
  sizeBytes: f.sizeBytes,
  createdAt: f.createdAt,
  url: `/api/v1/files/${f.id}`,
});

/**
 * POST /api/v1/admin/files — multipart upload (pdf, docx, txt, audio, image, video),
 * validated for type and size, stored via the pluggable storage adapter.
 */
filesRouter.post(
  '/files',
  uploadLimiter,
  uploadSingle,
  asyncHandler(async (req, res) => {
    if (!req.file) throw errors.badRequest('No file provided (field name: file)', 'FILE_REQUIRED');
    // Belt-and-braces: validate again after upload (mimetype can be spoofed by clients).
    validateFileType(req.file.mimetype, req.file.originalname);
    validateFileSize(req.file.size);

    const file = await prisma.file.create({
      data: await persistUpload(req, req.user.id),
    });
    await audit({
      actor: req.user,
      action: 'file_uploaded',
      targetType: 'file',
      targetId: file.id,
      details: { originalName: file.originalName, sizeBytes: file.sizeBytes, mimeType: file.mimeType },
      req,
    });
    res.status(201).json({ file: fileShape(file) });
  })
);

filesRouter.get(
  '/files',
  validate({ query: paginationQuery }),
  asyncHandler(async (req, res) => {
    const { page, pageSize } = req.valid.query;
    const result = await paginate(prisma.file, {
      where: {},
      orderBy: { createdAt: 'desc' },
      page,
      pageSize,
    });
    res.json({ data: result.data.map(fileShape), meta: result.meta });
  })
);

const materialBody = z.object({
  title: z.string().trim().min(1).max(300),
  description: z.string().max(10000).nullable().optional(),
  category: z.enum([
    'PDF_DOCUMENT', 'AUDIO_MESSAGE', 'VIDEO', 'BIBLE_STUDY_NOTES', 'LITERATURE_REFERENCE',
    'PRAYER_GUIDE', 'SCRIPTURE_READING_LINK', 'CONFESSION_DECLARATION', 'ANNOUNCEMENT', 'OTHER',
  ]),
  programmeYear: z.coerce.number().int().min(2000).max(2100).nullable().optional(),
  programmeId: uuidSchema.nullable().optional(),
  month: monthSchema.nullable().optional(),
  week: z.coerce.number().int().min(1).max(6).nullable().optional(),
  fileId: uuidSchema.nullable().optional(),
  thumbnailFileId: uuidSchema.nullable().optional(),
  externalUrl: z
    .string()
    .trim()
    .max(1000)
    .refine((v) => /^https?:\/\//i.test(v), 'External URL must be http(s)')
    .nullable()
    .optional(),
  authorSpeaker: z.string().max(200).nullable().optional(),
  publicationDate: dateSchema.nullable().optional(),
  visibility: z.enum(['ALL_MEMBERS', 'ADMINS_ONLY']).default('ALL_MEMBERS'),
  trackCompletion: z.boolean().default(false),
  sortOrder: z.coerce.number().int().min(0).max(10000).default(0),
});

const materialInclude = {
  file: true,
  thumbnailFile: true,
  createdBy: { select: { id: true, firstName: true, lastName: true } },
};

materialsRouter.get(
  '/materials',
  validate({
    query: paginationQuery.extend({
      search: searchQuery,
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
      category: z.string().trim().max(40).optional(),
      year: z.coerce.number().int().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, search, status, category, year } = req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (category) where.category = category;
    if (year) where.programmeYear = year;
    if (search) {
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { authorSpeaker: { contains: search, mode: 'insensitive' } },
      ];
    }
    const result = await paginate(prisma.material, {
      where,
      orderBy: [{ createdAt: 'desc' }],
      include: materialInclude,
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

materialsRouter.post(
  '/materials',
  validate({ body: materialBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    if (!b.fileId && !b.externalUrl) {
      throw errors.badRequest('Provide either fileId (upload first) or externalUrl', 'VALIDATION_ERROR');
    }
    if (b.fileId) {
      const file = await prisma.file.findUnique({ where: { id: b.fileId } });
      if (!file) throw errors.badRequest('fileId does not exist', 'VALIDATION_ERROR');
    }

    const material = await prisma.material.create({
      data: {
        title: b.title,
        description: b.description ?? null,
        category: b.category,
        programmeYear: b.programmeYear ?? null,
        programmeId: b.programmeId ?? null,
        month: b.month ?? null,
        week: b.week ?? null,
        fileId: b.fileId ?? null,
        thumbnailFileId: b.thumbnailFileId ?? null,
        externalUrl: b.externalUrl ?? null,
        authorSpeaker: b.authorSpeaker ?? null,
        publicationDate: b.publicationDate ? new Date(`${b.publicationDate}T00:00:00.000Z`) : null,
        visibility: b.visibility,
        trackCompletion: b.trackCompletion,
        sortOrder: b.sortOrder,
        createdById: req.user.id,
        updatedById: req.user.id,
        status: 'DRAFT',
      },
      include: materialInclude,
    });
    await audit({ actor: req.user, action: 'material_created', targetType: 'material', targetId: material.id, details: { title: material.title, category: material.category }, req });
    res.status(201).json({ material });
  })
);

materialsRouter.get(
  '/materials/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const material = await prisma.material.findUnique({ where: { id: req.valid.params.id }, include: materialInclude });
    if (!material) throw errors.notFound('Material not found', 'NOT_FOUND');
    res.json({ material });
  })
);

materialsRouter.patch(
  '/materials/:id',
  validate({ params: z.object({ id: uuidSchema }), body: materialBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.material.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Material not found', 'NOT_FOUND');
    const b = { ...req.valid.body };
    if ('publicationDate' in b) b.publicationDate = b.publicationDate ? new Date(`${b.publicationDate}T00:00:00.000Z`) : null;
    const material = await prisma.material.update({
      where: { id: existing.id },
      data: { ...b, updatedById: req.user.id },
      include: materialInclude,
    });
    await audit({ actor: req.user, action: 'material_updated', targetType: 'material', targetId: material.id, details: { fields: Object.keys(b) }, req });
    res.json({ material });
  })
);

materialsRouter.post(
  '/materials/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.material.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Material not found', 'NOT_FOUND');
    if (!existing.fileId && !existing.externalUrl) {
      throw errors.badRequest('Add a file or external link before publishing', 'VALIDATION_ERROR');
    }
    const material = await prisma.material.update({
      where: { id: existing.id },
      data: {
        status: 'PUBLISHED',
        publishedAt: new Date(),
        archivedAt: null,
        updatedById: req.user.id,
        publicationDate: existing.publicationDate ?? new Date(),
      },
      include: materialInclude,
    });
    await audit({ actor: req.user, action: 'material_published', targetType: 'material', targetId: material.id, details: { title: material.title }, req });

    let notified = 0;
    if (material.visibility === 'ALL_MEMBERS') {
      notified = await notifyAllMembers({
        eventType: 'material_published',
        eventKey: material.id,
        title: `New material: ${material.title}`,
        body: material.description?.slice(0, 300) || 'A new study material is available.',
        data: { materialId: material.id },
      });
    }
    res.json({ material, notified });
  })
);

materialsRouter.post(
  '/materials/:id/archive',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.material.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Material not found', 'NOT_FOUND');
    const material = await prisma.material.update({
      where: { id: existing.id },
      data: { status: 'ARCHIVED', archivedAt: new Date(), publishedAt: null, updatedById: req.user.id },
      include: materialInclude,
    });
    await audit({ actor: req.user, action: 'material_archived', targetType: 'material', targetId: material.id, req });
    res.json({ material });
  })
);

materialsRouter.delete(
  '/materials/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.material.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Material not found', 'NOT_FOUND');
    await prisma.material.delete({ where: { id: existing.id } });
    await audit({ actor: req.user, action: 'material_deleted', targetType: 'material', targetId: existing.id, details: { title: existing.title }, req });
    res.json({ ok: true });
  })
);
