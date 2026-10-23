import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { assertOwner } from '../../middleware/auth.js';
import { getSetting } from '../../lib/settings.js';
import { DateTime } from 'luxon';
import { weekKey, monthKey } from '../../lib/dates.js';

const router = Router();

const goalShape = (g, extra = {}) => {
  const startISO = g.startDate ? DateTime.fromJSDate(g.startDate, { zone: 'utc' }).toFormat('yyyy-MM-dd') : null;
  return {
    id: g.id,
    title: g.title,
    description: g.description,
    periodType: g.periodType,
    startDate: startISO,
    targetDate: g.targetDate ? DateTime.fromJSDate(g.targetDate, { zone: 'utc' }).toFormat('yyyy-MM-dd') : null,
    targetQuantity: g.targetQuantity,
    unit: g.unit,
    // Flutter aliases.
    targetUnit: g.unit,
    privateNote: g.privateNotes,
    periodKey: startISO
      ? (g.periodType === 'WEEKLY' ? weekKey(startISO, 'utc') : monthKey(startISO, 'utc'))
      : null,
    completedAt: g.status === 'COMPLETED' ? g.updatedAt : null,
    currentProgress: g.currentProgress,
    progressPercent: g.targetQuantity ? Math.min(100, Math.round((g.currentProgress / g.targetQuantity) * 100)) : null,
    status: g.status,
    privateNotes: g.privateNotes,
    createdAt: g.createdAt,
    updatedAt: g.updatedAt,
    ...extra,
  };
};

router.get(
  '/goals',
  validate({
    query: paginationQuery.extend({
      periodType: z.enum(['WEEKLY', 'MONTHLY']).optional(),
      status: z.enum(['ACTIVE', 'COMPLETED', 'PAUSED', 'ABANDONED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize } = req.valid.query;
    const where = { userId: req.user.id };
    if (req.valid.query.periodType) where.periodType = req.valid.query.periodType;
    if (req.valid.query.status) where.status = req.valid.query.status;
    const result = await paginate(prisma.personalGoal, {
      where,
      orderBy: [{ status: 'asc' }, { targetDate: 'asc' }],
      page,
      pageSize,
    });
    res.json({ data: result.data.map((g) => goalShape(g)), meta: result.meta });
  })
);

const createGoalSchema = z.object({
  title: z.string().trim().min(1).max(200),
  description: z.string().trim().max(4000).nullable().optional(),
  periodType: z.enum(['WEEKLY', 'MONTHLY']),
  // Dates are optional for the Flutter client; defaults are derived below.
  startDate: dateSchema.optional(),
  targetDate: dateSchema.optional(),
  targetQuantity: z.coerce.number().int().min(1).max(100000).nullable().optional(),
  unit: z.string().trim().max(40).nullable().optional(),
  // Flutter aliases.
  targetUnit: z.string().trim().max(40).nullable().optional(),
  privateNote: z.string().max(4000).nullable().optional(),
  currentProgress: z.coerce.number().min(0).max(100000).optional(),
  privateNotes: z.string().max(4000).nullable().optional(),
  programmeId: uuidSchema.optional(),
});

function defaultStartDate(timezone) {
  return DateTime.now().setZone(timezone || 'Africa/Lagos').toFormat('yyyy-MM-dd');
}

function defaultTargetDate(periodType, startISO) {
  const dt = DateTime.fromISO(startISO, { zone: 'utc' });
  return (periodType === 'WEEKLY' ? dt.endOf('week') : dt.endOf('month')).toFormat('yyyy-MM-dd');
}

router.post(
  '/goals',
  validate({ body: createGoalSchema }),
  asyncHandler(async (req, res) => {
    const body = req.valid.body;
    // Resolve optional dates to concrete values (Flutter may omit them).
    const startDate = body.startDate ?? defaultStartDate(req.user.timezone);
    const targetDate = body.targetDate ?? defaultTargetDate(body.periodType, startDate);
    if (targetDate < startDate) {
      throw errors.badRequest('targetDate must be on or after startDate', 'VALIDATION_ERROR');
    }

    // Monthly goal slots: up to N suggested slots unless admins allow extras.
    if (body.periodType === 'MONTHLY') {
      const maxSlots = Number(await getSetting('goals.maxMonthlySuggested'));
      const allowExtra = Boolean(await getSetting('goals.allowExtra'));
      if (!allowExtra) {
        const start = DateTime.fromISO(startDate, { zone: 'utc' });
        const monthStart = start.startOf('month');
        const monthEnd = start.endOf('month');
        const count = await prisma.personalGoal.count({
          where: {
            userId: req.user.id,
            periodType: 'MONTHLY',
            status: { not: 'ABANDONED' },
            startDate: { gte: monthStart.toJSDate(), lte: monthEnd.toJSDate() },
          },
        });
        if (count >= maxSlots) {
          throw errors.badRequest(
            `You have used all ${maxSlots} suggested monthly goal slots for this month. Additional goals are currently disabled by the ministry administrator.`,
            'GOAL_LIMIT_REACHED',
            { maxSlots }
          );
        }
      }
    }

    if (body.currentProgress != null && body.targetQuantity != null && body.currentProgress > body.targetQuantity) {
      body.currentProgress = body.targetQuantity;
    }

    const goal = await prisma.personalGoal.create({
      data: {
        userId: req.user.id,
        programmeId: body.programmeId ?? null,
        title: body.title,
        description: body.description ?? null,
        periodType: body.periodType,
        startDate: dateFromISOSafe(startDate),
        targetDate: dateFromISOSafe(targetDate),
        targetQuantity: body.targetQuantity ?? null,
        unit: body.unit ?? body.targetUnit ?? null,
        currentProgress: body.currentProgress ?? 0,
        privateNotes: body.privateNotes ?? body.privateNote ?? null,
      },
    });
    const shaped = goalShape(goal);
    res.status(201).json({ ...shaped, goal: shaped });
  })
);

function dateFromISOSafe(v) {
  const [y, m, d] = v.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

router.get(
  '/goals/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const goal = await prisma.personalGoal.findUnique({
      where: { id: req.valid.params.id },
      include: { progressEntries: { orderBy: { createdAt: 'desc' }, take: 50 } },
    });
    if (!goal) throw errors.notFound('Goal not found', 'NOT_FOUND');
    assertOwner(req, goal);
    const shaped = goalShape(goal, {
      progressEntries: goal.progressEntries.map((e) => ({
        id: e.id,
        value: e.value,
        note: e.note,
        createdAt: e.createdAt,
      })),
    });
    res.json({ ...shaped, goal: shaped });
  })
);

const patchGoalSchema = z.object({
  title: z.string().trim().min(1).max(200).optional(),
  description: z.string().trim().max(4000).nullable().optional(),
  startDate: dateSchema.optional(),
  targetDate: dateSchema.optional(),
  targetQuantity: z.coerce.number().int().min(1).max(100000).nullable().optional(),
  unit: z.string().trim().max(40).nullable().optional(),
  targetUnit: z.string().trim().max(40).nullable().optional(),
  currentProgress: z.coerce.number().min(0).max(100000).optional(),
  status: z.enum(['ACTIVE', 'COMPLETED', 'PAUSED', 'ABANDONED']).optional(),
  privateNotes: z.string().max(4000).nullable().optional(),
  privateNote: z.string().max(4000).nullable().optional(),
});

router.patch(
  '/goals/:id',
  validate({ params: z.object({ id: uuidSchema }), body: patchGoalSchema }),
  asyncHandler(async (req, res) => {
    const goal = await prisma.personalGoal.findUnique({ where: { id: req.valid.params.id } });
    if (!goal) throw errors.notFound('Goal not found', 'NOT_FOUND');
    assertOwner(req, goal);

    const body = { ...req.valid.body };
    // Map Flutter aliases to their stored columns and drop the aliases so we
    // never pass unknown fields to Prisma.
    if (body.targetUnit !== undefined) {
      body.unit = body.targetUnit;
      delete body.targetUnit;
    }
    if (body.privateNote !== undefined) {
      body.privateNotes = body.privateNote;
      delete body.privateNote;
    }
    if (body.startDate && body.targetDate && body.targetDate < body.startDate) {
      throw errors.badRequest('targetDate must be on or after startDate', 'VALIDATION_ERROR');
    }
    if (body.startDate) body.startDate = dateFromISOSafe(body.startDate);
    if (body.targetDate) body.targetDate = dateFromISOSafe(body.targetDate);

    // Progress is clamped to logical limits; completing a quantitative goal
    // moves progress to its target.
    if (goal.targetQuantity != null && body.currentProgress != null) {
      body.currentProgress = Math.max(0, Math.min(body.currentProgress, goal.targetQuantity));
    }
    if (body.status === 'COMPLETED' && goal.targetQuantity != null) {
      body.currentProgress = goal.targetQuantity;
    }

    const updated = await prisma.personalGoal.update({ where: { id: goal.id }, data: body });
    const shaped = goalShape(updated);
    res.json({ ...shaped, goal: shaped });
  })
);

router.delete(
  '/goals/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const goal = await prisma.personalGoal.findUnique({ where: { id: req.valid.params.id } });
    if (!goal) throw errors.notFound('Goal not found', 'NOT_FOUND');
    assertOwner(req, goal);
    await prisma.personalGoal.delete({ where: { id: goal.id } });
    res.json({ ok: true });
  })
);

router.post(
  '/goals/:id/progress',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z
      .object({
        // `value` (legacy) and `amount` (Flutter) are both accepted.
        value: z.coerce.number().min(0).max(100000).optional(),
        amount: z.coerce.number().min(0).max(100000).optional(),
        note: z.string().max(1000).nullable().optional(),
      })
      .refine((v) => v.value !== undefined || v.amount !== undefined, {
        message: 'value or amount is required',
        path: ['value'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const goal = await prisma.personalGoal.findUnique({ where: { id: req.valid.params.id } });
    if (!goal) throw errors.notFound('Goal not found', 'NOT_FOUND');
    assertOwner(req, goal);

    let value = req.valid.body.value ?? req.valid.body.amount;
    if (goal.targetQuantity != null) value = Math.min(value, goal.targetQuantity);

    const [, updated] = await prisma.$transaction([
      prisma.goalProgressEntry.create({
        data: { goalId: goal.id, value, note: req.valid.body.note ?? null },
      }),
      prisma.personalGoal.update({
        where: { id: goal.id },
        data: {
          currentProgress: value,
          ...(goal.targetQuantity != null && value >= goal.targetQuantity
            ? { status: 'COMPLETED' }
            : {}),
        },
      }),
    ]);
    const shaped = goalShape(updated);
    res.status(201).json({ ...shaped, goal: shaped });
  })
);

// ---------------------------------------------------------------------------
// Weekly / monthly progress reviews (lessons learned)
// ---------------------------------------------------------------------------

router.get(
  '/reviews',
  validate({ query: z.object({ periodType: z.enum(['WEEKLY', 'MONTHLY']).optional() }) }),
  asyncHandler(async (req, res) => {
    const where = { userId: req.user.id };
    if (req.valid.query.periodType) where.periodType = req.valid.query.periodType;
    const rows = await prisma.progressReview.findMany({ where, orderBy: { updatedAt: 'desc' } });
    res.json({ data: rows });
  })
);

router.post(
  '/reviews',
  validate({
    body: z.object({
      periodType: z.enum(['WEEKLY', 'MONTHLY']),
      periodKey: z.string().min(6).max(20),
      outcome: z.enum(['COMPLETED', 'PARTIAL', 'NOT_COMPLETED']),
      lessonsLearned: z.string().max(4000).nullable().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { periodType, periodKey, outcome, lessonsLearned } = req.valid.body;
    const review = await prisma.progressReview.upsert({
      where: { userId_periodType_periodKey: { userId: req.user.id, periodType, periodKey } },
      create: { userId: req.user.id, periodType, periodKey, outcome, lessonsLearned: lessonsLearned ?? null },
      update: { outcome, lessonsLearned: lessonsLearned ?? null },
    });
    res.status(201).json({ review });
  })
);

/** Current period keys helper used by the frontend for default filters. */
router.get(
  '/period-keys',
  asyncHandler(async (req, res) => {
    const now = DateTime.now().setZone(req.user.timezone || 'Africa/Lagos');
    res.json({
      timezone: req.user.timezone,
      now: now.toISO(),
      weekKey: weekKey(now.toISODate(), req.user.timezone),
      monthKey: monthKey(now.toISODate(), req.user.timezone),
      year: now.year,
      quarter: `${now.year}-Q${Math.ceil(now.month / 3)}`,
    });
  })
);

export default router;
