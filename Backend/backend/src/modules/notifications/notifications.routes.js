import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';

const router = Router();

// Flutter reads `type`, `read`/`isRead` and `link`; keep the raw columns too.
function notificationShape(n) {
  if (!n) return null;
  const data = n.data && typeof n.data === 'object' && !Array.isArray(n.data) ? n.data : {};
  const link = typeof data.link === 'string' ? data.link : null;
  return {
    ...n,
    type: n.eventType,
    read: Boolean(n.readAt),
    isRead: Boolean(n.readAt),
    link,
  };
}

router.get(
  '/notifications',
  validate({
    query: paginationQuery.extend({
      unreadOnly: z
        .enum(['true', 'false'])
        .transform((v) => v === 'true')
        .optional(),
      eventType: z.string().trim().max(60).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, unreadOnly, eventType } = req.valid.query;
    const where = { userId: req.user.id };
    if (unreadOnly) where.readAt = null;
    if (eventType) where.eventType = eventType;

    const [result, unreadCount] = await Promise.all([
      paginate(prisma.notification, {
        where,
        orderBy: { createdAt: 'desc' },
        page,
        pageSize,
      }),
      prisma.notification.count({ where: { userId: req.user.id, readAt: null } }),
    ]);

    res.json({ data: result.data.map(notificationShape), meta: result.meta, unreadCount });
  })
);

router.post(
  '/notifications/:id/read',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const n = await prisma.notification.findUnique({ where: { id: req.valid.params.id } });
    if (!n || n.userId !== req.user.id) throw errors.notFound('Notification not found', 'NOT_FOUND');
    const updated = n.readAt ? n : await prisma.notification.update({ where: { id: n.id }, data: { readAt: new Date() } });
    const shaped = notificationShape(updated);
    res.json({ ...shaped, notification: shaped });
  })
);

router.post(
  '/notifications/read-all',
  asyncHandler(async (req, res) => {
    const result = await prisma.notification.updateMany({
      where: { userId: req.user.id, readAt: null },
      data: { readAt: new Date() },
    });
    res.json({ ok: true, updated: result.count });
  })
);

router.delete(
  '/notifications/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const n = await prisma.notification.findUnique({ where: { id: req.valid.params.id } });
    if (!n || n.userId !== req.user.id) throw errors.notFound('Notification not found', 'NOT_FOUND');
    await prisma.notification.delete({ where: { id: n.id } });
    res.json({ ok: true });
  })
);

export default router;
