import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, dateSchema, uuidSchema } from '../../lib/validate.js';
import { assertOwner } from '../../middleware/auth.js';
import { dateFromISO, isoDate } from '../../lib/dates.js';
import { resolveProgrammeForDate, resolveMonthlyPlan, monthOf, yearOf } from '../../lib/programme.js';

const router = Router();

const ACTIVITY_STATUSES = ['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED', 'NOT_APPLICABLE'];
const CATEGORIES = [
  'prayer', 'scripture_reading', 'bible_study', 'literature_reading', 'proverbs_reading',
  'fasting_and_prayer', 'prayer_and_affirmations', 'confessions_declarations',
  'audio_message', 'prayer_partner_session', 'personal_reflection', 'custom',
];

function humanizeCategory(key) {
  if (!key) return null;
  return String(key)
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

function recordShape(r) {
  if (!r) return null;
  return {
    id: r.id,
    activityId: r.activityId,
    date: isoDate(r.date),
    // Flutter aliases.
    plannedDate: isoDate(r.date),
    categoryKey: r.category,
    actualDuration: r.actualDurationMinutes,
    title: r.title,
    category: r.category,
    source: r.source,
    status: r.status,
    note: r.note,
    actualDurationMinutes: r.actualDurationMinutes,
    actualQuantity: r.actualQuantity,
    completedAt: r.completedAt,
    updatedAt: r.updatedAt,
  };
}

/**
 * GET /api/v1/me/activities?date=YYYY-MM-DD  (day view)
 * Also accepts from/to (YYYY-MM-DD) for range views (week/month).
 * Generates the checklist from the published plan and merges the member's own
 * activity records for the same dates.
 */
router.get(
  '/activities',
  validate({
    query: z
      .object({
        date: dateSchema.optional(),
        from: dateSchema.optional(),
        to: dateSchema.optional(),
      })
      .refine((q) => q.date || (q.from && q.to), 'Provide date or from+to'),
  }),
  asyncHandler(async (req, res) => {
    const q = req.valid.query;
    const single = Boolean(q.date);
    const fromISO = q.date || q.from;
    const toISO = q.date || q.to;
    if (fromISO > toISO) throw errors.badRequest('from must be on or before to', 'VALIDATION_ERROR');

    const { programme, dateInProgramme } = await resolveProgrammeForDate(fromISO);
    const month = monthOf(fromISO);
    const year = yearOf(fromISO);
    const monthlyPlan = programme
      ? await resolveMonthlyPlan(programme.id, month, year)
      : null;

    const fromDate = dateFromISO(fromISO);
    const toDate = dateFromISO(toISO);

    const [planActivities, records] = await Promise.all([
      programme
        ? prisma.dailyActivity.findMany({
            where: {
              programmeId: programme.id,
              status: 'PUBLISHED',
              date: { gte: fromDate, lte: toDate },
            },
            orderBy: [{ date: 'asc' }, { sortOrder: 'asc' }],
            include: { relatedMaterial: { select: { id: true, title: true, category: true, status: true } } },
          })
        : Promise.resolve([]),
      prisma.userActivityRecord.findMany({
        where: { userId: req.user.id, date: { gte: fromDate, lte: toDate } },
        orderBy: [{ date: 'asc' }, { updatedAt: 'desc' }],
      }),
    ]);

    // One record per plan activity per date (duplicate creation is blocked).
    const recordByActivity = new Map();
    for (const r of records) {
      if (r.activityId && !recordByActivity.has(`${r.activityId}|${isoDate(r.date)}`)) {
        recordByActivity.set(`${r.activityId}|${isoDate(r.date)}`, r);
      }
    }

    const activities = planActivities.map((a) => {
      const key = `${a.id}|${isoDate(a.date)}`;
      return {
        id: a.id,
        date: isoDate(a.date),
        title: a.title,
        description: a.description,
        category: a.category,
        // Flutter aliases.
        categoryKey: a.category,
        categoryLabel: humanizeCategory(a.category),
        source: 'PROGRAMME',
        targetDuration: a.durationMinutes != null ? `${a.durationMinutes} min` : null,
        instructions: a.completionInstructions,
        trackingEnabled: a.trackCompletion,
        noteAllowed: a.allowNote,
        materialId: a.relatedMaterialId ?? null,
        sortOrder: a.sortOrder,
        startTime: a.startTime,
        durationMinutes: a.durationMinutes,
        quantityTarget: a.quantityTarget,
        quantityUnit: a.quantityUnit,
        completionInstructions: a.completionInstructions,
        trackCompletion: a.trackCompletion,
        allowNote: a.allowNote,
        relatedMaterial: a.relatedMaterial && a.relatedMaterial.status === 'PUBLISHED' ? a.relatedMaterial : null,
        record: recordShape(recordByActivity.get(key) || null),
      };
    });

    // Personal/custom records not tied to a plan activity.
    const customRecords = records
      .filter((r) => !r.activityId || !planActivities.some((a) => a.id === r.activityId))
      .map(recordShape);

    res.json({
      from: fromISO,
      to: toISO,
      date: q.date || null,
      singleDay: single,
      dateInProgramme,
      programme: programme ? { id: programme.id, title: programme.title, year: programme.year } : null,
      monthlyPlan: monthlyPlan
        ? {
            id: monthlyPlan.id,
            month: monthlyPlan.month,
            year: monthlyPlan.year,
            theme: monthlyPlan.theme,
            prayerFocus: monthlyPlan.prayerFocus,
            bibleReadingGuidance: monthlyPlan.bibleReadingGuidance,
            fastingGuidance: monthlyPlan.fastingGuidance,
            monthlyConfession: monthlyPlan.monthlyConfession,
            reflectionQuestions: monthlyPlan.reflectionQuestions,
          }
        : null,
      activities,
      customRecords,
      // Flutter's dailyChecklistProvider looks for a `data` array here.
      data: activities,
    });
  })
);

// ---------------------------------------------------------------------------
// Activity records
// ---------------------------------------------------------------------------

const durationAlias = z.coerce.number().int().min(0).max(24 * 60).nullable().optional();

const createRecordSchema = z
  .object({
    activityId: uuidSchema.optional(),
    date: dateSchema,
    category: z.enum(CATEGORIES).optional(),
    title: z.string().trim().min(1).max(200).optional(),
    status: z.enum(ACTIVITY_STATUSES).default('NOT_STARTED'),
    note: z.string().max(4000).nullable().optional(),
    actualDurationMinutes: durationAlias,
    // Flutter names the recorded minutes `actualDuration` (often a string).
    actualDuration: durationAlias,
    actualQuantity: z.coerce.number().int().min(0).max(100000).nullable().optional(),
  })
  .refine((v) => v.activityId || (v.title && v.category), {
    message: 'Provide either activityId or (title + category)',
  });

/** Normalise the two duration spellings into the storage column. */
function durationOf(body) {
  const value = body.actualDurationMinutes ?? body.actualDuration;
  return value === undefined ? undefined : value;
}

router.post(
  '/activity-records',
  validate({ body: createRecordSchema }),
  asyncHandler(async (req, res) => {
    const body = req.valid.body;
    const date = dateFromISO(body.date);

    let category = body.category;
    let title = body.title;

    if (body.activityId) {
      const activity = await prisma.dailyActivity.findUnique({
        where: { id: body.activityId },
        include: { programme: { select: { status: true } } },
      });
      if (!activity || activity.status !== 'PUBLISHED' || activity.programme.status !== 'PUBLISHED') {
        throw errors.notFound('Activity not found in a published programme', 'NOT_FOUND');
      }
      category = activity.category;
      title = activity.title;

      const dup = await prisma.userActivityRecord.findFirst({
        where: { userId: req.user.id, activityId: activity.id, date },
      });
      if (dup) {
        throw errors.conflict('You already have a record for this activity on this date', 'DUPLICATE_RECORD');
      }
    } else {
      const dup = await prisma.userActivityRecord.findFirst({
        where: { userId: req.user.id, activityId: null, date, title: title },
      });
      if (dup) {
        throw errors.conflict('You already have a record for this activity on this date', 'DUPLICATE_RECORD');
      }
    }

    const data = {
      userId: req.user.id,
      activityId: body.activityId ?? null,
      source: body.activityId ? 'PLAN' : 'CUSTOM',
      category,
      title,
      date,
      status: body.status,
      note: body.note ?? null,
      actualDurationMinutes: durationOf(body) ?? null,
      actualQuantity: body.actualQuantity ?? null,
      completedAt: body.status === 'COMPLETED' ? new Date() : null,
    };

    try {
      const record = await prisma.userActivityRecord.create({ data });
      res.status(201).json({ record: recordShape(record) });
    } catch (err) {
      if (err?.code === 'P2002') {
        throw errors.conflict('You already have a record for this activity on this date', 'DUPLICATE_RECORD');
      }
      throw err;
    }
  })
);

router.get(
  '/activity-records',
  validate({
    query: z.object({
      from: dateSchema.optional(),
      to: dateSchema.optional(),
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce.number().int().min(1).max(100).default(50),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { from, to, page, pageSize } = req.valid.query;
    const where = { userId: req.user.id };
    if (from || to) {
      where.date = {};
      if (from) where.date.gte = dateFromISO(from);
      if (to) where.date.lte = dateFromISO(to);
    }
    const [rows, total] = await Promise.all([
      prisma.userActivityRecord.findMany({
        where,
        orderBy: [{ date: 'desc' }, { updatedAt: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      prisma.userActivityRecord.count({ where }),
    ]);
    res.json({
      data: rows.map(recordShape),
      meta: { page, pageSize, total, totalPages: Math.max(1, Math.ceil(total / pageSize)) },
    });
  })
);

const updateRecordSchema = z.object({
  status: z.enum(ACTIVITY_STATUSES).optional(),
  note: z.string().max(4000).nullable().optional(),
  actualDurationMinutes: durationAlias,
  actualDuration: durationAlias,
  actualQuantity: z.coerce.number().int().min(0).max(100000).nullable().optional(),
});

router.patch(
  '/activity-records/:id',
  validate({ params: z.object({ id: uuidSchema }), body: updateRecordSchema }),
  asyncHandler(async (req, res) => {
    const record = await prisma.userActivityRecord.findUnique({ where: { id: req.valid.params.id } });
    if (!record) throw errors.notFound('Activity record not found', 'NOT_FOUND');
    assertOwner(req, record);

    const body = req.valid.body;
    const data = {};
    if (body.status !== undefined) data.status = body.status;
    if (body.note !== undefined) data.note = body.note;
    if (body.actualQuantity !== undefined) data.actualQuantity = body.actualQuantity;
    const duration = durationOf(body);
    if (duration !== undefined) data.actualDurationMinutes = duration;
    if (body.status === 'COMPLETED' && record.status !== 'COMPLETED') data.completedAt = new Date();
    if (body.status && body.status !== 'COMPLETED') data.completedAt = null;

    const updated = await prisma.userActivityRecord.update({ where: { id: record.id }, data });
    res.json({ record: recordShape(updated) });
  })
);

router.delete(
  '/activity-records/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const record = await prisma.userActivityRecord.findUnique({ where: { id: req.valid.params.id } });
    if (!record) throw errors.notFound('Activity record not found', 'NOT_FOUND');
    assertOwner(req, record);
    await prisma.userActivityRecord.delete({ where: { id: record.id } });
    res.json({ ok: true });
  })
);

export { ACTIVITY_STATUSES, CATEGORIES };
export default router;
