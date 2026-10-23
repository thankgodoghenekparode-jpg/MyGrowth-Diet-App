import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema } from '../../lib/validate.js';
import { assertOwner } from '../../middleware/auth.js';
import { DateTime } from 'luxon';
import { isoDate, dateFromISO, weekKey, monthKey } from '../../lib/dates.js';
import { resolveProgrammeForDate, resolveMonthlyPlan, monthOf, yearOf } from '../../lib/programme.js';

const router = Router();

const PRAYER_CATEGORIES = ['prayer', 'fasting_and_prayer', 'prayer_and_affirmations', 'confessions_declarations'];

/**
 * GET /api/v1/me/dashboard — personalised member dashboard summary.
 * Every number comes from real database queries.
 */
router.get(
  '/dashboard',
  asyncHandler(async (req, res) => {
    const user = req.user;
    const tzName = user.timezone || 'Africa/Lagos';
    const now = DateTime.now().setZone(tzName);
    const todayISO = now.toFormat('yyyy-MM-dd');
    const wKey = weekKey(todayISO, tzName);
    const mKey = monthKey(todayISO, tzName);

    const { programme, dateInProgramme } = await resolveProgrammeForDate(todayISO);
    const monthlyPlan = programme
      ? await resolveMonthlyPlan(programme.id, monthOf(todayISO), yearOf(todayISO))
      : null;

    const todayStart = dateFromISO(todayISO);
    const weekStart = dateFromISO(wKey);
    const monthStart = dateFromISO(`${mKey}-01`);

    const [
      todayActivities,
      todayRecords,
      weekRecords,
      monthRecords,
      activeGoals,
      nextSession,
      pendingReports,
      reviewedReports,
      recentMaterials,
      announcements,
      unreadNotifications,
      safetyNotice,
    ] = await Promise.all([
      programme
        ? prisma.dailyActivity.count({
            where: { programmeId: programme.id, status: 'PUBLISHED', date: todayStart },
          })
        : Promise.resolve(0),
      prisma.userActivityRecord.findMany({
        where: { userId: user.id, date: todayStart },
        select: { status: true, actualDurationMinutes: true },
      }),
      prisma.userActivityRecord.findMany({
        where: { userId: user.id, date: { gte: weekStart } },
        select: { status: true, category: true, actualDurationMinutes: true },
      }),
      prisma.userActivityRecord.findMany({
        where: { userId: user.id, date: { gte: monthStart } },
        select: { status: true, category: true, actualDurationMinutes: true },
      }),
      prisma.personalGoal.findMany({
        where: { userId: user.id, status: { in: ['ACTIVE', 'PAUSED'] } },
        orderBy: { targetDate: 'asc' },
        take: 5,
      }),
      (async () => {
        const sessions = await prisma.prayerSession.findMany({
          where: {
            status: { in: ['PROPOSED', 'ACCEPTED'] },
            date: { gte: dateFromISO(todayISO) },
            partnership: {
              status: 'ACTIVE',
              OR: [{ userAId: user.id }, { userBId: user.id }],
            },
          },
          include: {
            partnership: { include: { userA: true, userB: true } },
          },
          orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
          take: 1,
        });
        const s = sessions[0];
        if (!s) return null;
        const partner = s.partnership.userAId === user.id ? s.partnership.userB : s.partnership.userA;
        return {
          id: s.id,
          date: isoDate(s.date),
          startTime: s.startTime,
          durationMinutes: s.durationMinutes,
          status: s.status,
          timezone: s.timezone,
          prayerFocus: s.prayerFocus,
          partner: { id: partner.id, firstName: partner.firstName, lastName: partner.lastName },
        };
      })(),
      (async () => {
        const [weekly, monthly] = await Promise.all([
          prisma.report.findFirst({
            where: { userId: user.id, periodType: 'WEEK', periodKey: wKey, reportType: 'WEEKLY' },
            select: { status: true },
          }),
          prisma.report.findFirst({
            where: { userId: user.id, periodType: 'MONTH', periodKey: mKey, reportType: 'MONTHLY' },
            select: { status: true },
          }),
        ]);
        return {
          weekly: { periodKey: wKey, status: weekly?.status || null, due: !weekly || weekly.status === 'DRAFT' },
          monthly: { periodKey: mKey, status: monthly?.status || null, due: !monthly || monthly.status === 'DRAFT' },
        };
      })(),
      prisma.report.count({ where: { userId: user.id, status: 'REVIEWED' } }),
      prisma.material.findMany({
        where: { status: 'PUBLISHED', visibility: 'ALL_MEMBERS' },
        orderBy: { publishedAt: 'desc' },
        take: 5,
        select: { id: true, title: true, category: true, authorSpeaker: true, publishedAt: true },
      }),
      prisma.announcement.findMany({
        where: {
          status: 'PUBLISHED',
          audience: 'ALL_MEMBERS',
          OR: [{ startsAt: null }, { startsAt: { lte: new Date() } }],
          AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }] }],
        },
        orderBy: { publishedAt: 'desc' },
        take: 3,
        select: { id: true, title: true, publishedAt: true },
      }),
      prisma.notification.count({ where: { userId: user.id, readAt: null } }),
      prisma.safetyReport.count({
        where: { reportedId: user.id, status: { in: ['OPEN'] } },
      }),
    ]);

    const completedToday = todayRecords.filter((r) => r.status === 'COMPLETED').length;
    const weekCompleted = weekRecords.filter((r) => r.status === 'COMPLETED').length;
    const monthCompleted = monthRecords.filter((r) => r.status === 'COMPLETED').length;
    const prayerMinutesMonth = monthRecords
      .filter((r) => PRAYER_CATEGORIES.includes(r.category))
      .reduce((sum, r) => sum + (r.actualDurationMinutes || 0), 0);

    res.json({
      now: now.toISO(),
      timezone: tzName,
      programme: programme
        ? {
            id: programme.id,
            title: programme.title,
            year: programme.year,
            ministry: programme.ministry,
            annualPrayerFocus: programme.annualPrayerFocus,
            dailyAffirmation: programme.dailyAffirmation,
            dateInProgramme,
          }
        : null,
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
      today: {
        date: todayISO,
        planActivityCount: todayActivities,
        completedCount: completedToday,
        records: todayRecords.length,
      },
      goals: activeGoals.map((g) => ({
        id: g.id,
        title: g.title,
        periodType: g.periodType,
        status: g.status,
        currentProgress: g.currentProgress,
        targetQuantity: g.targetQuantity,
        unit: g.unit,
        targetDate: isoDate(g.targetDate),
      })),
      nextPrayerSession: nextSession,
      reports: { ...pendingReports, reviewedCount: reviewedReports },
      recentMaterials,
      announcements,
      unreadNotifications,
      safetyNotice: safetyNotice > 0 ? 'A safety report you filed is being reviewed by the ministry team.' : null,
      progressSummary: {
        label: 'Recorded participation this month (self-reported)',
        weekCompletedActivities: weekCompleted,
        monthCompletedActivities: monthCompleted,
        monthPrayerMinutes: prayerMinutesMonth,
        weekKey: wKey,
        monthKey: mKey,
      },
    });
  })
);

/**
 * GET /api/v1/me/progress — honest aggregates over the member's own records.
 * All values are self-reported participation data, never a measure of worth.
 */
router.get(
  '/progress',
  validate({
    query: z.object({
      from: dateSchema.optional(),
      to: dateSchema.optional(),
      period: z.enum(['week', 'month', 'year', 'all']).default('month'),
    }),
  }),
  asyncHandler(async (req, res) => {
    const period = req.valid.query.period;
    const tzName = req.user.timezone || 'Africa/Lagos';
    const now = DateTime.now().setZone(tzName);
    let from = req.valid.query.from;
    // "all" is deliberately unbounded above so records stored for any
    // programme year (including future-dated plans) are included.
    let to = req.valid.query.to ?? (period === 'all' ? null : now.toFormat('yyyy-MM-dd'));
    if (!from) {
      if (period === 'week') from = weekKey(now.toFormat('yyyy-MM-dd'), tzName);
      else if (period === 'month') from = now.startOf('month').toFormat('yyyy-MM-dd');
      else if (period === 'year') from = `${now.year}-01-01`;
      else from = '2000-01-01';
    }

    const dateRange = { gte: dateFromISO(from), ...(to ? { lte: dateFromISO(to) } : {}) };
    const where = { userId: req.user.id, date: dateRange };

    const [records, goalCount, reportCount, sessionCount] = await Promise.all([
      prisma.userActivityRecord.findMany({ where, select: { status: true, category: true, actualDurationMinutes: true, date: true } }),
      prisma.personalGoal.count({ where: { userId: req.user.id } }),
      prisma.report.count({ where: { userId: req.user.id, status: { in: ['SUBMITTED', 'REVIEWED', 'REQUIRES_FOLLOW_UP'] } } }),
      prisma.prayerSession.count({
        where: {
          status: 'COMPLETED',
          date: dateRange,
          partnership: { OR: [{ userAId: req.user.id }, { userBId: req.user.id }] },
        },
      }),
    ]);

    const byCategory = {};
    for (const r of records) {
      byCategory[r.category] ||= { total: 0, completed: 0, skipped: 0, minutes: 0 };
      byCategory[r.category].total += 1;
      if (r.status === 'COMPLETED') byCategory[r.category].completed += 1;
      if (r.status === 'SKIPPED') byCategory[r.category].skipped += 1;
      byCategory[r.category].minutes += r.actualDurationMinutes || 0;
    }

    // Simple streak: consecutive days (ending today or yesterday) with >= 1 completed record.
    const completedDates = new Set(
      records.filter((r) => r.status === 'COMPLETED').map((r) => isoDate(r.date))
    );
    let streak = 0;
    let cursor = now;
    if (!completedDates.has(cursor.toFormat('yyyy-MM-dd'))) cursor = cursor.minus({ days: 1 });
    while (completedDates.has(cursor.toFormat('yyyy-MM-dd'))) {
      streak += 1;
      cursor = cursor.minus({ days: 1 });
    }

    const total = records.length;
    const completed = records.filter((r) => r.status === 'COMPLETED').length;
    const inProgress = records.filter((r) => r.status === 'IN_PROGRESS').length;
    const skipped = records.filter((r) => r.status === 'SKIPPED').length;
    const totalMinutes = records.reduce((s, r) => s + (r.actualDurationMinutes || 0), 0);

    // Flutter's ProgressSummary consumes `byCategory` as a flat count map and a
    // `byMonth` tally list, so build both here alongside the detailed breakdown.
    const categoryCounts = {};
    const monthMap = new Map();
    for (const r of records) {
      categoryCounts[r.category] = (categoryCounts[r.category] || 0) + 1;
      const iso = isoDate(r.date);
      const key = iso.slice(0, 7);
      const entry = monthMap.get(key) || {
        month: Number(iso.slice(5, 7)),
        year: Number(iso.slice(0, 4)),
        completed: 0,
        total: 0,
      };
      entry.total += 1;
      if (r.status === 'COMPLETED') entry.completed += 1;
      monthMap.set(key, entry);
    }
    const byMonth = [...monthMap.values()].sort(
      (a, b) => a.year * 12 + a.month - (b.year * 12 + b.month)
    );

    res.json({
      label: 'Self-reported recorded participation — not a measure of spiritual worth.',
      from,
      to,
      activities: {
        total,
        completed,
        skipped,
        inProgress,
        completionRate: total ? Math.round((completed / total) * 100) : 0,
        prayerMinutes: records
          .filter((r) => PRAYER_CATEGORIES.includes(r.category))
          .reduce((s, r) => s + (r.actualDurationMinutes || 0), 0),
        byCategory,
      },
      // Flutter aliases (ProgressSummary.fromJson).
      totalActivities: total,
      completedActivities: completed,
      inProgressActivities: inProgress,
      skippedActivities: skipped,
      totalMinutesRecorded: totalMinutes,
      reportsSubmitted: reportCount,
      sessionsCompleted: sessionCount,
      currentStreakDays: streak,
      byCategory: categoryCounts,
      byMonth,
      goals: { total: goalCount },
      prayerSessionsCompleted: sessionCount,
      streakDays: streak,
      selfReported: true,
    });
  })
);

// ---------------------------------------------------------------------------
// Reading list & material completion
// ---------------------------------------------------------------------------

router.get(
  '/reading-list',
  asyncHandler(async (req, res) => {
    const rows = await prisma.readingListEntry.findMany({
      where: { userId: req.user.id },
      include: { material: { select: { id: true, title: true, category: true, authorSpeaker: true, status: true, externalUrl: true, fileId: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ data: rows.filter((r) => r.material).map((r) => ({ addedAt: r.createdAt, material: r.material })) });
  })
);

router.post(
  '/reading-list',
  validate({ body: z.object({ materialId: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const material = await prisma.material.findUnique({ where: { id: req.valid.body.materialId } });
    if (!material || material.status !== 'PUBLISHED' || material.visibility !== 'ALL_MEMBERS') {
      throw errors.notFound('Material not found', 'NOT_FOUND');
    }
    await prisma.readingListEntry.upsert({
      where: { userId_materialId: { userId: req.user.id, materialId: material.id } },
      create: { userId: req.user.id, materialId: material.id },
      update: {},
    });
    res.status(201).json({ ok: true });
  })
);

router.delete(
  '/reading-list/:materialId',
  validate({ params: z.object({ materialId: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    await prisma.readingListEntry
      .deleteMany({ where: { userId: req.user.id, materialId: req.valid.params.materialId } })
      .catch(() => {});
    res.json({ ok: true });
  })
);

router.post(
  '/material-completions',
  validate({ body: z.object({ materialId: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const material = await prisma.material.findUnique({ where: { id: req.valid.body.materialId } });
    if (!material || material.status !== 'PUBLISHED') throw errors.notFound('Material not found', 'NOT_FOUND');
    const row = await prisma.materialCompletion.upsert({
      where: { userId_materialId: { userId: req.user.id, materialId: material.id } },
      create: { userId: req.user.id, materialId: material.id },
      update: {},
    });
    res.status(201).json({ completion: row });
  })
);

router.delete(
  '/material-completions/:materialId',
  validate({ params: z.object({ materialId: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    await prisma.materialCompletion
      .deleteMany({ where: { userId: req.user.id, materialId: req.valid.params.materialId } })
      .catch(() => {});
    res.json({ ok: true });
  })
);

router.get(
  '/material-completions',
  asyncHandler(async (req, res) => {
    const rows = await prisma.materialCompletion.findMany({
      where: { userId: req.user.id },
      select: { materialId: true, completedAt: true },
      orderBy: { completedAt: 'desc' },
    });
    res.json({ data: rows });
  })
);

export default router;
