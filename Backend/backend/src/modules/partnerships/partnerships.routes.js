import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate } from '../../lib/validate.js';
import { audit } from '../../lib/audit.js';

export const partnershipsRouter = Router();

const shape = (p) => ({
  id: p.id,
  amount: Number(p.amount),
  currency: p.currency,
  frequency: p.frequency,
  status: p.status,
  note: p.note,
  createdAt: p.createdAt,
  updatedAt: p.updatedAt,
});

partnershipsRouter.get('/mine', asyncHandler(async (req, res) => {
  const pledge = await prisma.ministryPartnership.findUnique({ where: { userId: req.user.id } });
  res.json({ partnership: pledge ? shape(pledge) : null });
}));

partnershipsRouter.post(
  '/',
  validate({ body: z.object({
    amount: z.coerce.number().positive().max(100000000).finite(),
    frequency: z.enum(['WEEKLY', 'MONTHLY', 'YEARLY']),
    note: z.string().trim().max(500).optional().nullable(),
  }) }),
  asyncHandler(async (req, res) => {
    const { amount, frequency, note } = req.valid.body;
    const pledge = await prisma.ministryPartnership.upsert({
      where: { userId: req.user.id },
      create: { userId: req.user.id, amount, frequency, note: note || null },
      update: { amount, frequency, note: note || null, status: 'ACTIVE' },
    });
    await audit({ actor: req.user, action: 'ministry_partnership_saved', targetType: 'ministry_partnership', targetId: pledge.id, req });
    res.status(200).json({ partnership: shape(pledge) });
  })
);

partnershipsRouter.patch(
  '/mine',
  validate({ body: z.object({ status: z.enum(['PAUSED', 'ACTIVE', 'ENDED']) }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.ministryPartnership.findUnique({ where: { userId: req.user.id } });
    if (!existing) throw errors.notFound('Financial partnership not found', 'NOT_FOUND');
    const pledge = await prisma.ministryPartnership.update({ where: { id: existing.id }, data: { status: req.valid.body.status } });
    await audit({ actor: req.user, action: 'ministry_partnership_status_changed', targetType: 'ministry_partnership', targetId: pledge.id, req });
    res.json({ partnership: shape(pledge) });
  })
);
