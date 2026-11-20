import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { getStorage } from '../../services/storage/index.js';
import { requireAuth } from '../../middleware/auth.js';
import { emailSchema, validate, uuidSchema } from '../../lib/validate.js';
import { notify } from '../../services/notifications.js';
import { z } from 'zod';

const router = Router();

// Only images currently attached to a public programme or a scheduled/live
// service are exposed without authentication.
router.get('/media/:id', validate({ params: z.object({ id: uuidSchema }) }), asyncHandler(async (req, res) => {
  const file = await prisma.file.findFirst({
    where: {
      id: req.params.id,
      mimeType: { startsWith: 'image/' },
      OR: [
        { eventBanners: { some: { status: { in: ['PUBLISHED', 'COMPLETED'] } } } },
        { serviceThumbnails: { some: { status: { in: ['SCHEDULED', 'LIVE'] } } } },
      ],
    },
  });
  if (!file) throw errors.notFound('Ministry image not found');
  const storage = getStorage();
  if (!(await storage.exists(file.storageKey))) throw errors.notFound('Image content is missing');
  res.setHeader('Content-Type', file.mimeType);
  res.setHeader('Content-Length', String(file.sizeBytes));
  res.setHeader('Content-Disposition', 'inline');
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  const stream = await storage.createReadStream(file.storageKey);
  stream.on('error', () => {
    if (!res.headersSent) res.status(500).json({ error: { code: 'FILE_READ_ERROR', message: 'Failed to read image' } });
    else res.destroy();
  });
  stream.pipe(res);
}));

// Public service information lets visitors view a broadcast without creating
// an account. Prayer requests are intentionally collected as private records.
router.get('/current', asyncHandler(async (_req, res) => {
  const [live, next] = await Promise.all([
    prisma.liveService.findFirst({
      where: { status: 'LIVE' },
      orderBy: { startedAt: 'desc' },
      include: { thumbnailFile: { select: { id: true, originalName: true } } },
    }),
    prisma.liveService.findFirst({
      where: { status: 'SCHEDULED', scheduledAt: { gte: new Date() } },
      orderBy: { scheduledAt: 'asc' },
      include: { thumbnailFile: { select: { id: true, originalName: true } } },
    }),
  ]);
  res.json({ data: { live, next } });
}));

router.post('/prayer-requests', (req, res, next) => {
  if (!req.get('authorization')) return next();
  return requireAuth(req, res, next);
}, validate({ body: z.object({
  name: z.string().trim().min(1).max(160),
  email: emailSchema.optional(),
  phone: z.string().trim().max(40).optional(),
  request: z.string().trim().min(1).max(5000),
  liveServiceId: uuidSchema.optional(),
}) }), asyncHandler(async (req, res) => {
  const { name, email, phone, request, liveServiceId } = req.valid.body;
  if (liveServiceId) {
    const service = await prisma.liveService.findUnique({ where: { id: liveServiceId }, select: { id: true } });
    if (!service) throw errors.notFound('Live service not found');
  }
  const record = await prisma.prayerRequest.create({
    data: {
      liveServiceId: liveServiceId || null,
      userId: req.user?.id ?? null,
      name,
      email: email || null,
      phone: phone || null,
      request,
      isGuest: !req.user,
    },
    select: { id: true, createdAt: true },
  });
  const admins = await prisma.user.findMany({
    where: {
      role: { in: ['ADMIN', 'MAIN_ADMIN'] },
      adminAccess: 'ACTIVE',
      status: 'ACTIVE',
    },
    select: { id: true },
  });
  await Promise.all(admins.map((admin) => notify({
    userId: admin.id,
    eventType: 'prayer_request_received',
    eventKey: record.id,
    title: 'New prayer request',
    body: `A prayer request was submitted by ${name}. Open Ministry Platform to review it.`,
    data: { prayerRequestId: record.id, liveServiceId: liveServiceId || null },
  })));
  res.status(201).json({ data: { submitted: true, ...record } });
}));

export default router;
