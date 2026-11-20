import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';

const router = Router();

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

router.post('/prayer-requests', asyncHandler(async (req, res) => {
  const { name, email, phone, request, liveServiceId } = req.body || {};
  if (typeof name !== 'string' || !name.trim() || name.length > 160) {
    throw errors.badRequest('A name is required');
  }
  if (typeof request !== 'string' || !request.trim() || request.length > 5000) {
    throw errors.badRequest('Enter a prayer request (up to 5000 characters)');
  }
  if (email != null && (typeof email !== 'string' || email.length > 254)) {
    throw errors.badRequest('Enter a valid email address');
  }
  if (liveServiceId) {
    const service = await prisma.liveService.findUnique({ where: { id: liveServiceId }, select: { id: true } });
    if (!service) throw errors.notFound('Live service not found');
  }
  const record = await prisma.prayerRequest.create({
    data: {
      liveServiceId: liveServiceId || null,
      name: name.trim(),
      email: email?.trim() || null,
      phone: typeof phone === 'string' ? phone.trim().slice(0, 40) || null : null,
      request: request.trim(),
      isGuest: true,
    },
    select: { id: true, createdAt: true },
  });
  res.status(201).json({ data: { submitted: true, ...record } });
}));

export default router;
