import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler } from '../../lib/errors.js';
import { paginationQuery, validate } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';

export const adminPartnershipsRouter = Router();

adminPartnershipsRouter.get('/ministry-partnerships', validate({ query: paginationQuery }), asyncHandler(async (req, res) => {
  const { page, pageSize } = req.valid.query;
  const result = await paginate(prisma.ministryPartnership, {
    where: {}, include: { user: { select: { id: true, firstName: true, lastName: true, email: true } } },
    orderBy: { updatedAt: 'desc' }, page, pageSize,
  });
  res.json({ ...result, data: result.data.map((p) => ({
    id: p.id, amount: Number(p.amount), currency: p.currency, frequency: p.frequency,
    status: p.status, note: p.note, createdAt: p.createdAt, updatedAt: p.updatedAt,
    user: { id: p.user.id, name: [p.user.firstName, p.user.lastName].filter(Boolean).join(' '), email: p.user.email },
  })) });
}));
