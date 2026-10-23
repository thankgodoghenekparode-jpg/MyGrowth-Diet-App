import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery, searchQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';

const router = Router();

// ---------------------------------------------------------------------------
// Category naming: the Flutter client uses short names; Prisma has verbose
// enum values. Accept either on input and emit the short names on output.
// ---------------------------------------------------------------------------
const FLUTTER_TO_PRISMA = {
  PDF: 'PDF_DOCUMENT',
  AUDIO: 'AUDIO_MESSAGE',
  VIDEO: 'VIDEO',
  STUDY_NOTES: 'BIBLE_STUDY_NOTES',
  LITERATURE: 'LITERATURE_REFERENCE',
  PRAYER_GUIDE: 'PRAYER_GUIDE',
  SCRIPTURE_LINK: 'SCRIPTURE_READING_LINK',
  CONFESSION: 'CONFESSION_DECLARATION',
  ANNOUNCEMENT: 'ANNOUNCEMENT',
  OTHER: 'OTHER',
};
const PRISMA_TO_FLUTTER = Object.fromEntries(
  Object.entries(FLUTTER_TO_PRISMA).map(([k, v]) => [v, k])
);

function toPrismaCategory(category) {
  if (!category) return undefined;
  return FLUTTER_TO_PRISMA[category] ?? category; // pass through Prisma enum names
}

const materialShape = (m, { isCompleted = false, savedToReadingList = false } = {}) => ({
  id: m.id,
  title: m.title,
  description: m.description,
  category: PRISMA_TO_FLUTTER[m.category] ?? m.category,
  programmeYear: m.programmeYear,
  programmeId: m.programmeId,
  month: m.month,
  week: m.week,
  fileId: m.fileId,
  thumbnailFileId: m.thumbnailFileId,
  externalUrl: m.externalUrl,
  authorSpeaker: m.authorSpeaker,
  publicationDate: m.publicationDate,
  visibility: m.visibility,
  trackCompletion: m.trackCompletion,
  status: m.status,
  publishedAt: m.publishedAt,
  // Flutter aliases.
  year: m.programmeYear,
  author: m.authorSpeaker,
  fileType: m.file?.mimeType ?? null,
  isCompleted,
  savedToReadingList,
  file: m.file
    ? { id: m.file.id, originalName: m.file.originalName, mimeType: m.file.mimeType, sizeBytes: m.file.sizeBytes }
    : null,
});

async function flagsFor(userId, materialId) {
  const [completion, saved] = await Promise.all([
    prisma.materialCompletion.findUnique({
      where: { userId_materialId: { userId, materialId } },
      select: { id: true },
    }),
    prisma.readingListEntry.findUnique({
      where: { userId_materialId: { userId, materialId } },
      select: { id: true },
    }),
  ]);
  return { isCompleted: Boolean(completion), savedToReadingList: Boolean(saved) };
}

async function loadVisibleMaterial(id) {
  const m = await prisma.material.findUnique({ where: { id }, include: { file: true } });
  if (!m || m.status !== 'PUBLISHED' || m.visibility !== 'ALL_MEMBERS') {
    throw errors.notFound('Material not found', 'NOT_FOUND');
  }
  return m;
}

/**
 * GET /api/v1/materials — server-side search, filter, sort and pagination.
 * Members only see published, all-members materials.
 */
router.get(
  '/',
  validate({
    query: paginationQuery.extend({
      search: searchQuery,
      category: z.string().trim().max(40).optional(),
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: z.coerce.number().int().min(1).max(12).optional(),
      saved: z.enum(['true', 'false']).optional(),
      sort: z.enum(['newest', 'title', 'programme']).default('newest'),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, search, category, year, month, saved, sort } = req.valid.query;
    const where = { status: 'PUBLISHED', visibility: 'ALL_MEMBERS' };
    if (search) {
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { authorSpeaker: { contains: search, mode: 'insensitive' } },
      ];
    }
    const prismaCategory = toPrismaCategory(category);
    if (prismaCategory) where.category = prismaCategory;
    if (year) where.programmeYear = year;
    if (month) where.month = month;
    if (saved === 'true') where.readingList = { some: { userId: req.user.id } };

    const orderBy =
      sort === 'title'
        ? { title: 'asc' }
        : sort === 'programme'
          ? [{ programmeYear: 'desc' }, { month: 'asc' }, { sortOrder: 'asc' }]
          : [{ publishedAt: 'desc' }, { createdAt: 'desc' }];

    const result = await paginate(prisma.material, {
      where,
      orderBy,
      include: { file: true },
      page,
      pageSize,
    });

    const ids = result.data.map((m) => m.id);
    const [completions, saves] = ids.length
      ? await Promise.all([
          prisma.materialCompletion.findMany({
            where: { userId: req.user.id, materialId: { in: ids } },
            select: { materialId: true },
          }),
          prisma.readingListEntry.findMany({
            where: { userId: req.user.id, materialId: { in: ids } },
            select: { materialId: true },
          }),
        ])
      : [[], []];
    const completedIds = new Set(completions.map((c) => c.materialId));
    const savedIds = new Set(saves.map((s) => s.materialId));

    res.json({
      data: result.data.map((m) =>
        materialShape(m, {
          isCompleted: completedIds.has(m.id),
          savedToReadingList: savedIds.has(m.id),
        })
      ),
      meta: result.meta,
    });
  })
);

router.get(
  '/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const m = await loadVisibleMaterial(req.valid.params.id);
    const flags = await flagsFor(req.user.id, m.id);
    const shaped = materialShape(m, flags);
    res.json({
      ...shaped,
      completed: flags.isCompleted,
      material: shaped,
    });
  })
);

/**
 * POST /api/v1/materials/:id/complete — toggles completion for the member
 * (Flutter's single button flips between completed and not completed).
 */
router.post(
  '/:id/complete',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const m = await loadVisibleMaterial(req.valid.params.id);
    const key = { userId_materialId: { userId: req.user.id, materialId: m.id } };
    const existing = await prisma.materialCompletion.findUnique({ where: key });
    if (existing) {
      await prisma.materialCompletion.delete({ where: key });
    } else {
      await prisma.materialCompletion.create({ data: { userId: req.user.id, materialId: m.id } });
    }
    const flags = await flagsFor(req.user.id, m.id);
    const shaped = materialShape(m, flags);
    res.json({ ...shaped, completed: flags.isCompleted, material: shaped });
  })
);

/**
 * POST /api/v1/materials/:id/save — add/remove the material from the
 * member's reading list. Body: { saved: boolean }.
 */
router.post(
  '/:id/save',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({ saved: z.boolean().default(true) }),
  }),
  asyncHandler(async (req, res) => {
    const m = await loadVisibleMaterial(req.valid.params.id);
    const key = { userId_materialId: { userId: req.user.id, materialId: m.id } };
    if (req.valid.body.saved) {
      await prisma.readingListEntry.upsert({
        where: key,
        create: { userId: req.user.id, materialId: m.id },
        update: {},
      });
    } else {
      await prisma.readingListEntry.deleteMany({
        where: { userId: req.user.id, materialId: m.id },
      });
    }
    const flags = await flagsFor(req.user.id, m.id);
    const shaped = materialShape(m, flags);
    res.json({ ...shaped, completed: flags.isCompleted, material: shaped });
  })
);

export { materialShape };
export default router;
