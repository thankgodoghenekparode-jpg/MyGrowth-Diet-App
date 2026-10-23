import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';
import { audit } from '../../lib/audit.js';
import { getStorage, validateFileType, validateFileSize } from '../../services/storage/index.js';
import { uploadSingle, persistUpload } from '../../middleware/upload.js';
import { uploadLimiter } from '../../middleware/rateLimiters.js';

const router = Router();

const fileShape = (f) => ({
  id: f.id,
  originalName: f.originalName,
  mimeType: f.mimeType,
  sizeBytes: f.sizeBytes,
  createdAt: f.createdAt,
  url: `/api/v1/files/${f.id}`,
});

/**
 * POST /api/v1/files — member upload (multipart, field name: `file`).
 *
 * Members upload their own report attachments and personal documents. The
 * file is owned by the uploader; it is only readable by them and by admins
 * unless it is attached to a published, all-members material.
 */
router.post(
  '/',
  uploadLimiter,
  uploadSingle,
  asyncHandler(async (req, res) => {
    if (!req.file) throw errors.badRequest('No file provided (field name: file)', 'FILE_REQUIRED');
    validateFileType(req.file.mimetype, req.file.originalname);
    validateFileSize(req.file.size);

    const data = await persistUpload(req, req.user.id);
    const file = await prisma.file.create({ data });
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

/**
 * DELETE /api/v1/files/:id — the uploader may remove a file they uploaded,
 * as long as nothing references it yet (a material, a Daily Diet report
 * attachment or a profile photo). Removing a referenced file would silently
 * break the material or report, so it is refused with 409 FILE_IN_USE.
 */
router.delete(
  '/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const file = await prisma.file.findUnique({
      where: { id: req.valid.params.id },
      include: {
        materialAsFile: { select: { id: true } },
        materialAsThumb: { select: { id: true } },
        dietAttachments: { select: { id: true } },
        avatarOf: { select: { id: true } },
      },
    });
    if (!file) throw errors.notFound('File not found', 'NOT_FOUND');
    if (file.uploadedById !== req.user.id) {
      throw errors.forbidden(
        'You can only delete files you uploaded',
        'FILE_ACCESS_DENIED'
      );
    }

    const inUse =
      file.materialAsFile.length +
      file.materialAsThumb.length +
      file.dietAttachments.length +
      file.avatarOf.length;
    if (inUse > 0) {
      throw errors.conflict(
        'This file is attached to a material, report or profile and cannot be deleted',
        'FILE_IN_USE'
      );
    }

    await getStorage().delete(file.storageKey);
    await prisma.file.delete({ where: { id: file.id } });
    await audit({
      actor: req.user,
      action: 'file_deleted',
      targetType: 'file',
      targetId: file.id,
      details: { originalName: file.originalName, sizeBytes: file.sizeBytes },
      req,
    });
    res.json({ ok: true });
  })
);

/**
 * GET /api/v1/files/:id — authenticated file download/stream.
 * Access rules:
 *  - the uploader and administrators may read any file;
 *  - members may read files attached to a PUBLISHED, all-members material;
 *  - members may read avatar files (profile photos).
 * Files are never served from a public static path.
 */
router.get(
  '/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const file = await prisma.file.findUnique({
      where: { id: req.valid.params.id },
      include: { materialAsFile: true },
    });
    if (!file) throw errors.notFound('File not found', 'NOT_FOUND');

    const user = req.user;
    const isAdmin = (user.role === 'ADMIN' || user.role === 'MAIN_ADMIN') && user.adminAccess === 'ACTIVE';
    const isUploader = file.uploadedById === user.id;

    const publishedMaterial = file.materialAsFile.some(
      (m) => m.status === 'PUBLISHED' && m.visibility === 'ALL_MEMBERS'
    );
    const isAvatar = await prisma.user.findFirst({
      where: { id: user.id, avatarFileId: file.id },
      select: { id: true },
    });

    if (!isUploader && !isAdmin && !publishedMaterial && !isAvatar) {
      await audit({
        actor: user,
        action: 'file_access_denied',
        targetType: 'file',
        targetId: file.id,
        outcome: 'DENIED',
        req,
      });
      throw errors.forbidden('You do not have access to this file', 'FILE_ACCESS_DENIED');
    }

    const storage = getStorage();
    if (!(await storage.exists(file.storageKey))) {
      throw errors.notFound('File content is missing from storage', 'FILE_MISSING');
    }

    res.setHeader('Content-Type', file.mimeType);
    res.setHeader('Content-Length', String(file.sizeBytes));
    res.setHeader('Cache-Control', 'private, max-age=300');
    const disposition = file.mimeType.startsWith('image/') || file.mimeType.startsWith('audio/') || file.mimeType.startsWith('video/') || file.mimeType === 'application/pdf'
      ? 'inline'
      : 'attachment';
    res.setHeader(
      'Content-Disposition',
      `${disposition}; filename="${encodeURIComponent(file.originalName)}"`
    );

    const stream = await storage.createReadStream(file.storageKey);
    stream.on('error', () => {
      if (!res.headersSent) res.status(500).json({ error: { code: 'FILE_READ_ERROR', message: 'Failed to read file' } });
      else res.destroy();
    });
    stream.pipe(res);
  })
);

export default router;
