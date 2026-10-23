import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler } from '../../lib/errors.js';
import { validate, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';

/**
 * Administrator oversight of prayer partnerships — safety and support only.
 *
 * This view exposes partnership *metadata* (who is partnered with whom, and
 * the state of the request/partnership). It deliberately never returns prayer
 * session content, notes or private reflections: those stay with the members.
 */
export const adminPartnersRouter = Router();

function fullName(user) {
  if (!user) return 'Member';
  const name = `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim();
  return name || 'Member';
}

/** GET /api/v1/admin/prayer-partnerships — paginated partnerships. */
adminPartnersRouter.get(
  '/prayer-partnerships',
  validate({
    query: paginationQuery.extend({
      status: z.enum(['ACTIVE', 'PAUSED', 'ENDED', 'BLOCKED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status } = req.valid.query;
    const where = status ? { status } : {};
    const result = await paginate(prisma.prayerPartnership, {
      where,
      orderBy: [{ status: 'asc' }, { startedAt: 'desc' }],
      include: {
        userA: { select: { firstName: true, lastName: true } },
        userB: { select: { firstName: true, lastName: true } },
      },
      page,
      pageSize,
    });
    const data = result.data.map((p) => ({
      id: p.id,
      status: p.status,
      startedAt: p.startedAt,
      endedAt: p.endedAt,
      memberAName: fullName(p.userA),
      memberBName: fullName(p.userB),
    }));
    res.json({ data, meta: result.meta });
  })
);

/** GET /api/v1/admin/prayer-partner-requests — paginated partner requests. */
adminPartnersRouter.get(
  '/prayer-partner-requests',
  validate({
    query: paginationQuery.extend({
      status: z
        .enum(['PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'BLOCKED', 'REPORTED'])
        .optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status } = req.valid.query;
    const where = status ? { status } : {};
    const result = await paginate(prisma.prayerPartnerRequest, {
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        requester: { select: { firstName: true, lastName: true } },
        recipient: { select: { firstName: true, lastName: true } },
      },
      page,
      pageSize,
    });
    const data = result.data.map((r) => ({
      id: r.id,
      status: r.status,
      message: r.message,
      createdAt: r.createdAt,
      respondedAt: r.respondedAt,
      senderName: fullName(r.requester),
      recipientName: fullName(r.recipient),
    }));
    res.json({ data, meta: result.meta });
  })
);
