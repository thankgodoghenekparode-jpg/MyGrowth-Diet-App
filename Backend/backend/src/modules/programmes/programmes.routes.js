import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, monthSchema, yearSchema, dateSchema } from '../../lib/validate.js';
import { resolveProgrammeForDate, resolveMonthlyPlan, monthOf, yearOf } from '../../lib/programme.js';
import { programmeShape, monthShape, weeklyShape } from '../../lib/contentShapes.js';
import { DateTime } from 'luxon';

/**
 * Member-facing programme content.
 *
 * Mounted at `/api/v1/programmes`, so every path below is relative to that
 * prefix (e.g. `GET /api/v1/programmes/:id`). Administrators holding granted
 * admin access additionally see DRAFT/ARCHIVED content so the same routes can
 * back the admin content editors.
 */
const router = Router();

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const YEAR_RE = /^\d{4}$/;

/** True when the caller is an administrator with granted access. */
function isAdmin(req) {
  const u = req.user;
  return (u?.role === 'ADMIN' || u?.role === 'MAIN_ADMIN') && u?.adminAccess === 'ACTIVE';
}

/** Resolve a programme by UUID or 4-digit year, honouring member visibility. */
async function resolveProgramme(req, key) {
  const admin = isAdmin(req);
  let programme = null;
  if (YEAR_RE.test(key)) {
    programme = await prisma.programme.findFirst({
      where: { year: Number(key), ...(admin ? {} : { status: 'PUBLISHED' }) },
      orderBy: { createdAt: 'desc' },
    });
  } else if (UUID_RE.test(key)) {
    programme = await prisma.programme.findUnique({ where: { id: key } });
    if (programme && !admin && programme.status !== 'PUBLISHED') programme = null;
  }
  if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
  return programme;
}

// ---------------------------------------------------------------------------
// Today — quick entry point for the dashboard / day view.
// ---------------------------------------------------------------------------

router.get(
  '/today',
  validate({ query: z.object({ date: dateSchema.optional() }) }),
  asyncHandler(async (req, res) => {
    const tzName = req.user.timezone || 'Africa/Lagos';
    const dateISO = req.valid.query.date || DateTime.now().setZone(tzName).toFormat('yyyy-MM-dd');
    const { programme, dateInProgramme } = await resolveProgrammeForDate(dateISO);
    if (!programme) return res.json({ date: dateISO, programme: null, monthlyPlan: null });
    const monthlyPlan = await resolveMonthlyPlan(programme.id, monthOf(dateISO), yearOf(dateISO));
    res.json({
      date: dateISO,
      dateInProgramme,
      programme: programmeShape(programme),
      monthlyPlan: monthlyPlan ? monthShape(monthlyPlan) : null,
    });
  })
);

// ---------------------------------------------------------------------------
// Weekly plans (list by year/month, or fetch one by id)
// ---------------------------------------------------------------------------

router.get(
  '/weekly-plans',
  validate({
    query: z.object({
      year: yearSchema.optional(),
      month: monthSchema.optional(),
      programmeId: uuidSchema.optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const admin = isAdmin(req);
    const { year, month, programmeId } = req.valid.query;

    let programme = null;
    if (programmeId) {
      programme = await prisma.programme.findUnique({ where: { id: programmeId } });
      if (programme && !admin && programme.status !== 'PUBLISHED') programme = null;
    } else if (year) {
      programme = await prisma.programme.findFirst({
        where: { year, ...(admin ? {} : { status: 'PUBLISHED' }) },
        orderBy: { createdAt: 'desc' },
      });
    } else {
      const { programme: current } = await resolveProgrammeForDate(
        DateTime.now().setZone(req.user.timezone || 'Africa/Lagos').toFormat('yyyy-MM-dd')
      );
      programme = current;
    }
    if (!programme) return res.json({ data: [] });

    const where = { programmeId: programme.id, ...(admin ? {} : { status: 'PUBLISHED' }) };
    if (month) where.monthlyPlan = { month };

    const weeks = await prisma.weeklyPlan.findMany({
      where,
      orderBy: [{ weekNumber: 'asc' }, { startDate: 'asc' }],
    });
    res.json({ data: weeks.map(weeklyShape) });
  })
);

router.get(
  '/weekly-plans/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const w = await prisma.weeklyPlan.findUnique({
      where: { id: req.valid.params.id },
      include: { programme: { select: { status: true } } },
    });
    const admin = isAdmin(req);
    if (!w || (!admin && (w.status !== 'PUBLISHED' || w.programme.status !== 'PUBLISHED'))) {
      throw errors.notFound('Weekly plan not found', 'NOT_FOUND');
    }
    res.json({ weeklyPlan: weeklyShape(w) });
  })
);

// ---------------------------------------------------------------------------
// Programmes (list + detail)
// ---------------------------------------------------------------------------

router.get(
  '/',
  validate({
    query: z.object({
      year: yearSchema.optional(),
      includeArchived: z.enum(['true', 'false']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const admin = isAdmin(req);
    const { year, includeArchived } = req.valid.query;
    const where = {};
    if (year) where.year = year;
    if (!admin || includeArchived !== 'true') where.status = 'PUBLISHED';

    const programmes = await prisma.programme.findMany({
      where,
      orderBy: { year: 'desc' },
      select: {
        id: true,
        title: true,
        year: true,
        ministry: true,
        description: true,
        annualPrayerFocus: true,
        dailyAffirmation: true,
        startDate: true,
        endDate: true,
        status: true,
        publishedAt: true,
        updatedAt: true,
        _count: { select: { monthlyPlans: true } },
      },
    });
    res.json({
      data: programmes.map((p) => ({
        ...programmeShape(p),
        monthlyPlanCount: p._count.monthlyPlans,
      })),
      meta: { page: 1, pageSize: programmes.length || 0, total: programmes.length, totalPages: 1 },
    });
  })
);

router.get(
  '/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const admin = isAdmin(req);
    const p = await prisma.programme.findUnique({
      where: { id: req.valid.params.id },
      include: { monthlyPlans: { where: admin ? {} : { status: 'PUBLISHED' }, orderBy: { month: 'asc' } } },
    });
    if (!p || (!admin && p.status !== 'PUBLISHED')) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const shape = programmeShape(p);
    res.json({
      // Spread for clients that read the programme fields at the top level
      // (admin editors); `programme` for clients that expect the wrapper.
      ...shape,
      programme: shape,
      quarterlyConfession: p.quarterlyConfession,
      quarterlyReviewTopics: p.quarterlyReviewTopics,
      annualReflectionTemplate: p.annualReflectionTemplate,
      monthlyPlans: p.monthlyPlans.map(monthShape),
    });
  })
);

// ---------------------------------------------------------------------------
// Monthly plans (by programme UUID or by year)
// ---------------------------------------------------------------------------

router.get(
  '/:idOrYear/monthly-plans',
  validate({ params: z.object({ idOrYear: z.string().trim().min(1).max(40) }) }),
  asyncHandler(async (req, res) => {
    const admin = isAdmin(req);
    const programme = await resolveProgramme(req, req.valid.params.idOrYear);
    const months = await prisma.monthlyPlan.findMany({
      where: { programmeId: programme.id, ...(admin ? {} : { status: 'PUBLISHED' }) },
      orderBy: { month: 'asc' },
    });
    res.json({ data: months.map(monthShape) });
  })
);

router.get(
  '/:idOrYear/monthly-plans/:month',
  validate({ params: z.object({ idOrYear: z.string().trim().min(1).max(40), month: monthSchema }) }),
  asyncHandler(async (req, res) => {
    const admin = isAdmin(req);
    const programme = await resolveProgramme(req, req.valid.params.idOrYear);
    const m = await prisma.monthlyPlan.findFirst({
      where: {
        programmeId: programme.id,
        month: req.valid.params.month,
        ...(admin ? {} : { status: 'PUBLISHED' }),
      },
    });
    if (!m) throw errors.notFound('Monthly plan not found', 'NOT_FOUND');

    const weeks = await prisma.weeklyPlan.findMany({
      where: { monthlyPlanId: m.id, ...(admin ? {} : { status: 'PUBLISHED' }) },
      orderBy: { weekNumber: 'asc' },
    });

    res.json({ monthlyPlan: monthShape(m), weeklyPlans: weeks.map(weeklyShape) });
  })
);

export default router;
export { programmeShape, monthShape, weeklyShape };
