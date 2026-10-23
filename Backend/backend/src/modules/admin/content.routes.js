import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery, searchQuery, monthSchema, dateSchema } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { notifyAllMembers } from '../../services/notifications.js';
import { isoDate } from '../../lib/dates.js';
import { getSetting } from '../../lib/settings.js';
import { programmeShape, monthShape, weeklyShape } from '../../lib/contentShapes.js';

export const contentRouter = Router();

// ---------------------------------------------------------------------------
// Annual programmes
// ---------------------------------------------------------------------------

const programmeBody = z.object({
  title: z.string().trim().min(1).max(200),
  year: z.coerce.number().int().min(2000).max(2100),
  ministry: z.string().trim().min(1).max(200).optional(),
  // Mobile-client alias for `ministry`.
  ministryName: z.string().trim().min(1).max(200).optional(),
  description: z.string().max(10000).nullable().optional(),
  annualPrayerFocus: z.string().max(4000).nullable().optional(),
  // Mobile-client alias for `annualPrayerFocus`.
  prayerFocus: z.string().max(4000).nullable().optional(),
  dailyAffirmation: z.string().max(4000).nullable().optional(),
  startDate: dateSchema.nullable().optional(),
  endDate: dateSchema.nullable().optional(),
  status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
  quarterlyConfession: z.string().max(4000).nullable().optional(),
  quarterlyReviewTopics: z.array(z.string().max(200)).max(30).nullable().optional(),
  annualReflectionTemplate: z.any().nullable().optional(),
});

const d = (v) => (v ? new Date(`${v}T00:00:00.000Z`) : null);

/** Map the accepted programme body (including client aliases) to columns. */
function programmeData(b) {
  const data = {};
  if (b.title !== undefined) data.title = b.title;
  if (b.year !== undefined) data.year = b.year;
  const ministry = b.ministry ?? b.ministryName;
  if (ministry !== undefined) data.ministry = ministry;
  if (b.description !== undefined) data.description = b.description;
  const focus = b.annualPrayerFocus ?? b.prayerFocus;
  if (focus !== undefined) data.annualPrayerFocus = focus;
  if (b.dailyAffirmation !== undefined) data.dailyAffirmation = b.dailyAffirmation;
  if (b.startDate !== undefined) data.startDate = d(b.startDate);
  if (b.endDate !== undefined) data.endDate = d(b.endDate);
  if (b.quarterlyConfession !== undefined) data.quarterlyConfession = b.quarterlyConfession;
  if (b.quarterlyReviewTopics !== undefined) data.quarterlyReviewTopics = b.quarterlyReviewTopics;
  if (b.annualReflectionTemplate !== undefined) data.annualReflectionTemplate = b.annualReflectionTemplate;
  if (b.status !== undefined) data.status = b.status;
  return data;
}

contentRouter.get(
  '/programmes',
  validate({ query: paginationQuery.extend({ year: z.coerce.number().int().optional(), status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional() }) }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, year, status } = req.valid.query;
    const where = {};
    if (year) where.year = year;
    if (status) where.status = status;
    const result = await paginate(prisma.programme, {
      where,
      orderBy: [{ year: 'desc' }, { createdAt: 'desc' }],
      include: { _count: { select: { monthlyPlans: true, weeklyPlans: true, dailyActivities: true } } },
      page,
      pageSize,
    });
    res.json({
      data: result.data.map((p) => ({ ...programmeShape(p), _count: p._count })),
      meta: result.meta,
    });
  })
);

contentRouter.post(
  '/programmes',
  validate({ body: programmeBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const ministry = b.ministry ?? b.ministryName;
    if (!ministry) throw errors.badRequest('ministry (or ministryName) is required', 'VALIDATION_ERROR');
    const data = programmeData(b);
    data.ministry = ministry;
    if (data.description === undefined) data.description = null;
    if (data.annualPrayerFocus === undefined) data.annualPrayerFocus = null;
    if (data.dailyAffirmation === undefined) data.dailyAffirmation = null;
    const programme = await prisma.programme.create({
      data: { ...data, createdById: req.user.id, updatedById: req.user.id },
    });
    await audit({ actor: req.user, action: 'programme_created', targetType: 'programme', targetId: programme.id, details: { title: programme.title, year: programme.year }, req });
    res.status(201).json({ programme: programmeShape(programme) });
  })
);

contentRouter.get(
  '/programmes/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const programme = await prisma.programme.findUnique({
      where: { id: req.valid.params.id },
      include: { monthlyPlans: { orderBy: { month: 'asc' } } },
    });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    res.json({ programme });
  })
);

contentRouter.patch(
  '/programmes/:id',
  validate({ params: z.object({ id: uuidSchema }), body: programmeBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const data = programmeData(req.valid.body);
    const programme = await prisma.programme.update({
      where: { id: existing.id },
      data: { ...data, updatedById: req.user.id },
    });
    await audit({ actor: req.user, action: 'programme_updated', targetType: 'programme', targetId: programme.id, details: { fields: Object.keys(data) }, req });
    res.json({ programme: programmeShape(programme) });
  })
);

contentRouter.post(
  '/programmes/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const programme = await prisma.programme.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED', publishedAt: new Date(), archivedAt: null, updatedById: req.user.id },
    });
    await audit({ actor: req.user, action: 'programme_published', targetType: 'programme', targetId: programme.id, details: { title: programme.title, year: programme.year }, req });
    const notified = await notifyAllMembers({
      eventType: 'programme_published',
      eventKey: programme.id,
      title: `${programme.title} published`,
      body: 'A new annual growth programme is now available.',
      data: { programmeId: programme.id },
    });
    res.json({ programme: programmeShape(programme), notified });
  })
);

contentRouter.post(
  '/programmes/:id/archive',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const programme = await prisma.programme.update({
      where: { id: existing.id },
      data: { status: 'ARCHIVED', archivedAt: new Date(), updatedById: req.user.id },
    });
    await audit({ actor: req.user, action: 'programme_archived', targetType: 'programme', targetId: programme.id, details: { title: programme.title }, req });
    res.json({ programme: programmeShape(programme) });
  })
);

// ---------------------------------------------------------------------------
// Monthly plans
// ---------------------------------------------------------------------------

const jsonListBody = z
  .union([z.array(z.any()).max(100), z.string().max(8000)])
  .nullable()
  .optional();

const monthlyBody = z.object({
  month: monthSchema,
  year: z.coerce.number().int().min(2000).max(2100).optional(),
  // Mobile-client alias for `year`.
  programmeYear: z.coerce.number().int().min(2000).max(2100).optional(),
  programmeId: uuidSchema.optional(),
  theme: z.string().max(300).nullable().optional(),
  prayerFocus: z.string().max(4000).nullable().optional(),
  bibleReadingGuidance: z.string().max(2000).nullable().optional(),
  literatureList: jsonListBody,
  audioMessages: jsonListBody,
  // Mobile-client alias for `audioMessages`.
  audioMessageList: jsonListBody,
  fastingGuidance: z.string().max(1000).nullable().optional(),
  monthlyConfession: z.string().max(4000).nullable().optional(),
  // Mobile-client alias for `monthlyConfession`.
  confession: z.string().max(4000).nullable().optional(),
  monthlyGoalsGuidance: z.string().max(4000).nullable().optional(),
  // Mobile-client alias for `monthlyGoalsGuidance`.
  goalsGuidance: z.string().max(4000).nullable().optional(),
  reflectionQuestions: z.array(z.string().max(500)).max(20).nullable().optional(),
});

/** Map the accepted monthly-plan body (including client aliases) to columns. */
function monthlyData(b) {
  const data = {};
  if (b.theme !== undefined) data.theme = b.theme;
  if (b.prayerFocus !== undefined) data.prayerFocus = b.prayerFocus;
  if (b.bibleReadingGuidance !== undefined) data.bibleReadingGuidance = b.bibleReadingGuidance;
  if (b.literatureList !== undefined) data.literatureList = b.literatureList;
  const audio = b.audioMessages ?? b.audioMessageList;
  if (audio !== undefined) data.audioMessages = audio;
  if (b.fastingGuidance !== undefined) data.fastingGuidance = b.fastingGuidance;
  const confession = b.monthlyConfession ?? b.confession;
  if (confession !== undefined) data.monthlyConfession = confession;
  const goals = b.monthlyGoalsGuidance ?? b.goalsGuidance;
  if (goals !== undefined) data.monthlyGoalsGuidance = goals;
  if (b.reflectionQuestions !== undefined) data.reflectionQuestions = b.reflectionQuestions;
  return data;
}

/** GET /api/v1/admin/monthly-plans — list monthly plans by year/programme. */
contentRouter.get(
  '/monthly-plans',
  validate({
    query: paginationQuery.extend({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      programmeId: uuidSchema.optional(),
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, year, programmeId, status } = req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (programmeId) where.programmeId = programmeId;
    if (year) where.year = year;
    const result = await paginate(prisma.monthlyPlan, {
      where,
      orderBy: [{ year: 'desc' }, { month: 'asc' }],
      page,
      pageSize,
    });
    res.json({ data: result.data.map(monthShape), meta: result.meta });
  })
);

/** POST /api/v1/admin/monthly-plans — create a monthly plan for a programme. */
contentRouter.post(
  '/monthly-plans',
  validate({ body: monthlyBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const year = b.year ?? b.programmeYear;
    let programme = null;
    if (b.programmeId) {
      programme = await prisma.programme.findUnique({ where: { id: b.programmeId } });
    } else if (year) {
      programme = await prisma.programme.findFirst({ where: { year }, orderBy: { createdAt: 'desc' } });
    }
    if (!programme) {
      throw errors.badRequest('A valid programmeId or programmeYear is required', 'VALIDATION_ERROR');
    }
    try {
      const plan = await prisma.monthlyPlan.create({
        data: { ...monthlyData(b), month: b.month, year: year ?? programme.year, programmeId: programme.id },
      });
      await audit({ actor: req.user, action: 'monthly_plan_created', targetType: 'monthly_plan', targetId: plan.id, details: { month: plan.month, year: plan.year }, req });
      return res.status(201).json({ monthlyPlan: monthShape(plan) });
    } catch (err) {
      if (err?.code === 'P2002') throw errors.conflict('A monthly plan for this month already exists', 'DUPLICATE_MONTH');
      throw err;
    }
  })
);

contentRouter.post(
  '/programmes/:id/monthly-plans',
  validate({ params: z.object({ id: uuidSchema }), body: monthlyBody }),
  asyncHandler(async (req, res) => {
    const programme = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const b = req.valid.body;
    const year = b.year ?? b.programmeYear ?? programme.year;
    try {
      const plan = await prisma.monthlyPlan.create({
        data: { ...monthlyData(b), month: b.month, year, programmeId: programme.id },
      });
      await audit({ actor: req.user, action: 'monthly_plan_created', targetType: 'monthly_plan', targetId: plan.id, details: { month: plan.month, year: plan.year }, req });
      return res.status(201).json({ monthlyPlan: monthShape(plan) });
    } catch (err) {
      if (err?.code === 'P2002') throw errors.conflict('A monthly plan for this month already exists', 'DUPLICATE_MONTH');
      throw err;
    }
  })
);

contentRouter.patch(
  '/monthly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }), body: monthlyBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.monthlyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    const data = monthlyData(req.valid.body);
    const plan = await prisma.monthlyPlan.update({ where: { id: existing.id }, data });
    await audit({ actor: req.user, action: 'monthly_plan_updated', targetType: 'monthly_plan', targetId: plan.id, details: { fields: Object.keys(data) }, req });
    res.json({ monthlyPlan: monthShape(plan) });
  })
);

contentRouter.post(
  '/monthly-plans/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.monthlyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    const plan = await prisma.monthlyPlan.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED', publishedAt: new Date() },
    });
    await audit({ actor: req.user, action: 'monthly_plan_published', targetType: 'monthly_plan', targetId: plan.id, details: { month: plan.month }, req });
    res.json({ monthlyPlan: monthShape(plan) });
  })
);

contentRouter.post(
  '/monthly-plans/:id/archive',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.monthlyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    const plan = await prisma.monthlyPlan.update({ where: { id: existing.id }, data: { status: 'ARCHIVED', publishedAt: null } });
    await audit({ actor: req.user, action: 'monthly_plan_archived', targetType: 'monthly_plan', targetId: plan.id, req });
    res.json({ monthlyPlan: monthShape(plan) });
  })
);

contentRouter.delete(
  '/monthly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.monthlyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    await prisma.monthlyPlan.delete({ where: { id: existing.id } });
    await audit({ actor: req.user, action: 'monthly_plan_deleted', targetType: 'monthly_plan', targetId: existing.id, req });
    res.json({ ok: true });
  })
);

contentRouter.get(
  '/monthly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const plan = await prisma.monthlyPlan.findUnique({
      where: { id: req.valid.params.id },
      include: { weeklyPlans: { orderBy: { weekNumber: 'asc' } } },
    });
    if (!plan) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    res.json({ monthlyPlan: { ...monthShape(plan), weeklyPlans: plan.weeklyPlans.map(weeklyShape) } });
  })
);

// ---------------------------------------------------------------------------
// Weekly plans
// ---------------------------------------------------------------------------

const weeklyBody = z.object({
  month: monthSchema,
  weekNumber: z.coerce.number().int().min(1).max(6),
  startDate: dateSchema.nullable().optional(),
  endDate: dateSchema.nullable().optional(),
  bibleReading: z.string().max(2000).nullable().optional(),
  prayerDurationTargetMinutes: z.coerce.number().int().min(1).max(600).nullable().optional(),
  bookReading: z.string().max(1000).nullable().optional(),
  fastingSchedule: z.string().max(1000).nullable().optional(),
  keyLessonPrompt: z.string().max(2000).nullable().optional(),
  memoryVerse: z.string().max(1000).nullable().optional(),
  studyMaterialIds: z.array(z.string().uuid()).max(30).nullable().optional(),
  audioMaterialIds: z.array(z.string().uuid()).max(30).nullable().optional(),
  extraActivities: z.array(z.string().max(300)).max(30).nullable().optional(),
  monthlyPlanId: uuidSchema.nullable().optional(),
});

contentRouter.post(
  '/programmes/:id/weekly-plans',
  validate({ params: z.object({ id: uuidSchema }), body: weeklyBody }),
  asyncHandler(async (req, res) => {
    const programme = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const b = { ...req.valid.body };
    const month = b.month;
    delete b.month;
    if (b.startDate) b.startDate = new Date(`${b.startDate}T00:00:00.000Z`);
    if (b.endDate) b.endDate = new Date(`${b.endDate}T00:00:00.000Z`);
    if (!b.monthlyPlanId) {
      const mp = await prisma.monthlyPlan.findFirst({
        where: { programmeId: programme.id, month },
      });
      b.monthlyPlanId = mp?.id ?? null;
    }
    try {
      const plan = await prisma.weeklyPlan.create({
        data: { ...b, programmeId: programme.id, weekNumber: req.valid.body.weekNumber },
      });
      await audit({ actor: req.user, action: 'weekly_plan_created', targetType: 'weekly_plan', targetId: plan.id, details: { weekNumber: plan.weekNumber }, req });
      return res.status(201).json({ weeklyPlan: weeklyShape(plan) });
    } catch (err) {
      if (err?.code === 'P2002') throw errors.conflict('A plan for this week already exists', 'DUPLICATE_WEEK');
      throw err;
    }
  })
);

contentRouter.patch(
  '/weekly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }), body: weeklyBody.omit({ month: true, weekNumber: true }).partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.weeklyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Weekly plan not found', 'NOT_FOUND');
    const b = { ...req.valid.body };
    if ('startDate' in b) b.startDate = b.startDate ? new Date(`${b.startDate}T00:00:00.000Z`) : null;
    if ('endDate' in b) b.endDate = b.endDate ? new Date(`${b.endDate}T00:00:00.000Z`) : null;
    const plan = await prisma.weeklyPlan.update({ where: { id: existing.id }, data: b });
    await audit({ actor: req.user, action: 'weekly_plan_updated', targetType: 'weekly_plan', targetId: plan.id, details: { fields: Object.keys(b) }, req });
    res.json({ weeklyPlan: weeklyShape(plan) });
  })
);

contentRouter.post(
  '/weekly-plans/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.weeklyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Weekly plan not found', 'NOT_FOUND');
    const plan = await prisma.weeklyPlan.update({ where: { id: existing.id }, data: { status: 'PUBLISHED' } });
    await audit({ actor: req.user, action: 'weekly_plan_published', targetType: 'weekly_plan', targetId: plan.id, req });
    res.json({ weeklyPlan: weeklyShape(plan) });
  })
);

contentRouter.delete(
  '/weekly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.weeklyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Weekly plan not found', 'NOT_FOUND');
    await prisma.weeklyPlan.delete({ where: { id: existing.id } });
    await audit({ actor: req.user, action: 'weekly_plan_deleted', targetType: 'weekly_plan', targetId: existing.id, req });
    res.json({ ok: true });
  })
);

/**
 * GET /api/v1/admin/weekly-plans — admin list of weekly plans, optionally
 * scoped to a year/month. Metadata only (no member content).
 */
contentRouter.get(
  '/weekly-plans',
  validate({
    query: paginationQuery.extend({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: z.coerce.number().int().min(1).max(12).optional(),
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, year, month, status } = req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (year && month) where.monthlyPlan = { year, month };
    else if (year) where.monthlyPlan = { year };
    const result = await paginate(prisma.weeklyPlan, {
      where,
      orderBy: [{ startDate: 'asc' }, { weekNumber: 'asc' }],
      include: { monthlyPlan: { select: { id: true, year: true, month: true } } },
      page,
      pageSize,
    });
    res.json({
      data: result.data.map((w) => ({ ...weeklyShape(w), monthlyPlan: w.monthlyPlan })),
      meta: result.meta,
    });
  })
);

// ---------------------------------------------------------------------------
// Daily activities (programme activity definitions)
// ---------------------------------------------------------------------------

const CATEGORIES = [
  'prayer', 'scripture_reading', 'bible_study', 'literature_reading', 'proverbs_reading',
  'fasting_and_prayer', 'prayer_and_affirmations', 'confessions_declarations',
  'audio_message', 'prayer_partner_session', 'personal_reflection', 'custom',
];

const dailyBody = z.object({
  date: dateSchema.nullable().optional(),
  title: z.string().trim().min(1).max(300),
  description: z.string().max(4000).nullable().optional(),
  category: z.enum(CATEGORIES),
  startTime: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .nullable()
    .optional(),
  durationMinutes: z.coerce.number().int().min(1).max(600).nullable().optional(),
  quantityTarget: z.coerce.number().int().min(1).max(10000).nullable().optional(),
  quantityUnit: z.string().max(40).nullable().optional(),
  relatedMaterialId: uuidSchema.nullable().optional(),
  completionInstructions: z.string().max(2000).nullable().optional(),
  trackCompletion: z.boolean().optional(),
  allowNote: z.boolean().optional(),
  sortOrder: z.coerce.number().int().min(0).max(10000).optional(),
  month: monthSchema.nullable().optional(),
  weekId: uuidSchema.nullable().optional(),
});

async function createDailyActivity(req, res, scope) {
  const b = { ...req.valid.body };
  const date = b.date ? new Date(`${b.date}T00:00:00.000Z`) : null;
  delete b.date;

  let monthlyPlanId = scope.monthlyPlanId ?? null;
  if (!monthlyPlanId && b.month && scope.programmeId) {
    const mp = await prisma.monthlyPlan.findFirst({ where: { programmeId: scope.programmeId, month: b.month } });
    monthlyPlanId = mp?.id ?? null;
  }
  delete b.month;
  const weeklyPlanId = b.weekId ?? scope.weekId ?? null;
  delete b.weekId;

  const activity = await prisma.dailyActivity.create({
    data: {
      ...b,
      date,
      programmeId: scope.programmeId,
      monthlyPlanId,
      weeklyPlanId,
      status: 'DRAFT',
    },
  });
  await audit({ actor: req.user, action: 'daily_activity_created', targetType: 'daily_activity', targetId: activity.id, details: { title: activity.title, date: date ? isoDate(date) : null }, req });
  res.status(201).json({ dailyActivity: activity });
}

contentRouter.post(
  '/programmes/:id/daily-activities',
  validate({ params: z.object({ id: uuidSchema }), body: dailyBody }),
  asyncHandler(async (req, res) => {
    const programme = await prisma.programme.findUnique({ where: { id: req.valid.params.id } });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    await createDailyActivity(req, res, { programmeId: programme.id });
  })
);

contentRouter.post(
  '/monthly-plans/:id/daily-activities',
  validate({ params: z.object({ id: uuidSchema }), body: dailyBody }),
  asyncHandler(async (req, res) => {
    const mp = await prisma.monthlyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!mp) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');
    await createDailyActivity(req, res, { programmeId: mp.programmeId, monthlyPlanId: mp.id });
  })
);

contentRouter.post(
  '/weekly-plans/:id/daily-activities',
  validate({ params: z.object({ id: uuidSchema }), body: dailyBody }),
  asyncHandler(async (req, res) => {
    const wp = await prisma.weeklyPlan.findUnique({ where: { id: req.valid.params.id } });
    if (!wp) throw errors.notFound('Weekly plan not found', 'NOT_FOUND');
    await createDailyActivity(req, res, { programmeId: wp.programmeId, monthlyPlanId: wp.monthlyPlanId, weekId: wp.id });
  })
);

contentRouter.patch(
  '/daily-activities/:id',
  validate({ params: z.object({ id: uuidSchema }), body: dailyBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyActivity.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Activity not found', 'NOT_FOUND');
    const b = { ...req.valid.body };
    if ('date' in b) b.date = b.date ? new Date(`${b.date}T00:00:00.000Z`) : null;
    delete b.month;
    delete b.weekId;
    const activity = await prisma.dailyActivity.update({ where: { id: existing.id }, data: b });
    await audit({ actor: req.user, action: 'daily_activity_updated', targetType: 'daily_activity', targetId: activity.id, details: { fields: Object.keys(b) }, req });
    res.json({ dailyActivity: activity });
  })
);

contentRouter.post(
  '/daily-activities/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyActivity.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Activity not found', 'NOT_FOUND');
    const activity = await prisma.dailyActivity.update({ where: { id: existing.id }, data: { status: 'PUBLISHED' } });
    await audit({ actor: req.user, action: 'daily_activity_published', targetType: 'daily_activity', targetId: activity.id, req });
    res.json({ dailyActivity: activity });
  })
);

contentRouter.delete(
  '/daily-activities/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyActivity.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Activity not found', 'NOT_FOUND');
    await prisma.dailyActivity.delete({ where: { id: existing.id } });
    await audit({ actor: req.user, action: 'daily_activity_deleted', targetType: 'daily_activity', targetId: existing.id, req });
    res.json({ ok: true });
  })
);

/**
 * GET /api/v1/admin/daily-activities — admin list of daily activities,
 * optionally scoped to a year/month or a single weekly plan.
 */
contentRouter.get(
  '/daily-activities',
  validate({
    query: paginationQuery.extend({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: z.coerce.number().int().min(1).max(12).optional(),
      weeklyPlanId: uuidSchema.optional(),
      monthlyPlanId: uuidSchema.optional(),
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, year, month, weeklyPlanId, monthlyPlanId, status } =
      req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (weeklyPlanId) where.weeklyPlanId = weeklyPlanId;
    else if (monthlyPlanId) where.monthlyPlanId = monthlyPlanId;
    else if (year && month) where.monthlyPlan = { year, month };
    else if (year) where.monthlyPlan = { year };
    const result = await paginate(prisma.dailyActivity, {
      where,
      orderBy: [{ date: 'asc' }, { sortOrder: 'asc' }],
      include: {
        monthlyPlan: { select: { id: true, year: true, month: true } },
        weeklyPlan: { select: { id: true, weekNumber: true } },
      },
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

// ---------------------------------------------------------------------------
// Announcements (admin)
// ---------------------------------------------------------------------------

const announcementBody = z.object({
  title: z.string().trim().min(1).max(300),
  body: z.string().min(1).max(20000),
  link: z
    .string()
    .trim()
    .max(500)
    .refine((v) => /^https?:\/\//i.test(v), 'Link must be http(s)')
    .nullable()
    .optional(),
  materialId: uuidSchema.nullable().optional(),
  audience: z.enum(['ALL_MEMBERS', 'ADMINS_ONLY']).default('ALL_MEMBERS'),
  startsAt: z.string().datetime().nullable().optional(),
  endsAt: z.string().datetime().nullable().optional(),
});

contentRouter.get(
  '/announcements',
  validate({ query: paginationQuery.extend({ status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional() }) }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status } = req.valid.query;
    const where = status ? { status } : {};
    const result = await paginate(prisma.announcement, {
      where,
      orderBy: { createdAt: 'desc' },
      include: { createdBy: { select: { id: true, firstName: true, lastName: true } } },
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

contentRouter.post(
  '/announcements',
  validate({ body: announcementBody }),
  asyncHandler(async (req, res) => {
    const b = { ...req.valid.body };
    const announcement = await prisma.announcement.create({
      data: {
        title: b.title,
        body: b.body,
        link: b.link ?? null,
        materialId: b.materialId ?? null,
        audience: b.audience,
        startsAt: b.startsAt ? new Date(b.startsAt) : null,
        endsAt: b.endsAt ? new Date(b.endsAt) : null,
        createdById: req.user.id,
      },
    });
    await audit({ actor: req.user, action: 'announcement_created', targetType: 'announcement', targetId: announcement.id, details: { title: announcement.title }, req });
    res.status(201).json({ announcement });
  })
);

contentRouter.patch(
  '/announcements/:id',
  validate({ params: z.object({ id: uuidSchema }), body: announcementBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.announcement.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Announcement not found', 'NOT_FOUND');
    const b = { ...req.valid.body };
    if ('startsAt' in b) b.startsAt = b.startsAt ? new Date(b.startsAt) : null;
    if ('endsAt' in b) b.endsAt = b.endsAt ? new Date(b.endsAt) : null;
    const announcement = await prisma.announcement.update({ where: { id: existing.id }, data: b });
    res.json({ announcement });
  })
);

contentRouter.post(
  '/announcements/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.announcement.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Announcement not found', 'NOT_FOUND');
    const announcement = await prisma.announcement.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED', publishedAt: new Date() },
    });
    await audit({ actor: req.user, action: 'announcement_published', targetType: 'announcement', targetId: announcement.id, req });

    let notified = 0;
    if (announcement.audience === 'ALL_MEMBERS' && (await getSetting('announcements.notifyOnPublish'))) {
      notified = await notifyAllMembers({
        eventType: 'new_announcement',
        eventKey: announcement.id,
        title: `Announcement: ${announcement.title}`,
        body: announcement.body.slice(0, 300),
        data: { announcementId: announcement.id },
      });
    }
    res.json({ announcement, notified });
  })
);

contentRouter.post(
  '/announcements/:id/archive',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.announcement.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Announcement not found', 'NOT_FOUND');
    const announcement = await prisma.announcement.update({
      where: { id: existing.id },
      data: { status: 'ARCHIVED', publishedAt: null },
    });
    await audit({ actor: req.user, action: 'announcement_archived', targetType: 'announcement', targetId: announcement.id, req });
    res.json({ announcement });
  })
);

contentRouter.delete(
  '/announcements/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.announcement.findUnique({ where: { id: req.valid.params.id } });
    if (!existing) throw errors.notFound('Announcement not found', 'NOT_FOUND');
    await prisma.announcement.delete({ where: { id: existing.id } });
    await audit({ actor: req.user, action: 'announcement_deleted', targetType: 'announcement', targetId: existing.id, req });
    res.json({ ok: true });
  })
);

// ---------------------------------------------------------------------------
// Category / notification-event definitions (configurable by administrators)
// ---------------------------------------------------------------------------

contentRouter.get(
  '/activity-categories',
  asyncHandler(async (req, res) => {
    const rows = await prisma.activityCategoryDef.findMany({ orderBy: { sortOrder: 'asc' } });
    res.json({ data: rows });
  })
);

contentRouter.patch(
  '/activity-categories/:key',
  validate({
    params: z.object({ key: z.string().min(1).max(60) }),
    body: z.object({
      label: z.string().trim().min(1).max(120).optional(),
      description: z.string().max(500).nullable().optional(),
      sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
      enabled: z.boolean().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const row = await prisma.activityCategoryDef.findUnique({ where: { key: req.valid.params.key } });
    if (!row) throw errors.notFound('Category not found', 'NOT_FOUND');
    const updated = await prisma.activityCategoryDef.update({ where: { key: row.key }, data: req.valid.body });
    await audit({ actor: req.user, action: 'activity_category_updated', targetType: 'activity_category', targetId: row.key, details: { fields: Object.keys(req.valid.body) }, req });
    res.json({ category: updated });
  })
);

contentRouter.get(
  '/notification-events',
  asyncHandler(async (req, res) => {
    const rows = await prisma.notificationEventDef.findMany({ orderBy: { key: 'asc' } });
    res.json({ data: rows });
  })
);

/**
 * GET /api/v1/admin/activity-definitions — alias for the daily-activity
 * catalogue. The Flutter admin client asks for `activity-definitions` first
 * (and falls back to `/admin/activities`), so both names resolve to the same
 * list to avoid a guaranteed 404 on every load.
 */
contentRouter.get(
  '/activity-definitions',
  validate({
    query: paginationQuery.extend({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: z.coerce.number().int().min(1).max(12).optional(),
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, year, month, status } = req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (year && month) where.monthlyPlan = { year, month };
    else if (year) where.monthlyPlan = { year };
    const result = await paginate(prisma.dailyActivity, {
      where,
      orderBy: [{ date: 'asc' }, { sortOrder: 'asc' }],
      include: {
        monthlyPlan: { select: { id: true, year: true, month: true } },
        weeklyPlan: { select: { id: true, weekNumber: true } },
      },
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

contentRouter.patch(
  '/notification-events/:key',
  validate({
    params: z.object({ key: z.string().min(1).max(60) }),
    body: z.object({
      label: z.string().trim().min(1).max(120).optional(),
      description: z.string().max(500).nullable().optional(),
      defaultEnabled: z.boolean().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const row = await prisma.notificationEventDef.findUnique({ where: { key: req.valid.params.key } });
    if (!row) throw errors.notFound('Notification event not found', 'NOT_FOUND');
    const updated = await prisma.notificationEventDef.update({ where: { key: row.key }, data: req.valid.body });
    await audit({ actor: req.user, action: 'notification_event_updated', targetType: 'notification_event', targetId: row.key, req });
    res.json({ event: updated });
  })
);
