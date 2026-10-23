import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { isoDate } from '../../lib/dates.js';

const router = Router();

const shape = (a) => ({
  id: a.id,
  title: a.title,
  body: a.body,
  link: a.link,
  materialId: a.materialId,
  // Flutter aliases.
  attachmentMaterialId: a.materialId,
  audience: a.audience,
  status: a.status,
  createdByName: a.createdBy
    ? [a.createdBy.firstName, a.createdBy.lastName].filter(Boolean).join(' ').trim() || null
    : null,
  startsAt: a.startsAt,
  endsAt: a.endsAt,
  publishedAt: a.publishedAt,
  createdAt: a.createdAt,
});

function activeWhere(now = new Date()) {
  return {
    status: 'PUBLISHED',
    audience: 'ALL_MEMBERS',
    OR: [{ startsAt: null }, { startsAt: { lte: now } }],
    AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
  };
}

/** Member-facing active announcements. */
router.get(
  '/',
  validate({ query: paginationQuery }),
  asyncHandler(async (req, res) => {
    const { page, pageSize } = req.valid.query;
    const result = await paginate(prisma.announcement, {
      where: activeWhere(),
      orderBy: { publishedAt: 'desc' },
      include: { createdBy: { select: { firstName: true, lastName: true } } },
      page,
      pageSize,
    });
    res.json({ data: result.data.map(shape), meta: result.meta });
  })
);

router.get(
  '/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const a = await prisma.announcement.findUnique({
      where: { id: req.valid.params.id },
      include: { createdBy: { select: { firstName: true, lastName: true } } },
    });
    if (!a) throw errors.notFound('Announcement not found', 'NOT_FOUND');
    const isActive = a.status === 'PUBLISHED' && a.audience === 'ALL_MEMBERS' &&
      (!a.startsAt || a.startsAt <= new Date()) && (!a.endsAt || a.endsAt >= new Date());
    if (!isActive && req.user.role === 'MEMBER') throw errors.notFound('Announcement not found', 'NOT_FOUND');
    const shaped = shape(a);
    res.json({ ...shaped, announcement: shaped });
  })
);

export { activeWhere, shape as announcementShape };
export default router;
