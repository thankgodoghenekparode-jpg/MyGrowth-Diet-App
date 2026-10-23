import { Router } from 'express';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { getSetting, getAllSettings, setSetting, SETTING_KEYS } from '../../lib/settings.js';
import { DateTime } from 'luxon';

export const analyticsRouter = Router();
export const auditRouter = Router();
export const settingsRouter = Router();

function monthRange(year, month) {
  const start = DateTime.fromObject({ year, month, day: 1 }, { zone: 'utc' });
  const end = start.plus({ months: 1 });
  return { gte: start.toJSDate(), lt: end.toJSDate() };
}

/**
 * GET /api/v1/admin/analytics/overview?year&month&status — real aggregate queries.
 * Contains no private reflection/journal/prayer text.
 */
analyticsRouter.get(
  '/analytics/overview',
  validate({
    query: z.object({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: z.coerce.number().int().min(1).max(12).optional(),
      status: z.enum(['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { year, month, status } = req.valid.query;
    const dateFilter = month
      ? monthRange(year || DateTime.now().year, month)
      : year
        ? { gte: new Date(Date.UTC(year, 0, 1)), lt: new Date(Date.UTC(year + 1, 0, 1)) }
        : undefined;

    const userWhere = { role: 'MEMBER', ...(status ? { status } : {}) };
    const recordWhere = dateFilter ? { date: dateFilter } : {};
    const reportWhere = dateFilter ? { submittedAt: dateFilter } : {};

    const [
      totalMembers,
      activeMembers,
      pendingMembers,
      recentSignups,
      reportStatusGroups,
      recordsGroup,
      activityTypes,
      prayerSessionStats,
      announcementCount,
      safetyOpen,
    ] = await Promise.all([
      prisma.user.count({ where: userWhere }),
      prisma.user.count({ where: { ...userWhere, status: 'ACTIVE' } }),
      prisma.user.count({ where: { ...userWhere, status: 'PENDING' } }),
      prisma.user.findMany({
        where: { role: 'MEMBER' },
        orderBy: { createdAt: 'desc' },
        take: 8,
        select: { id: true, firstName: true, lastName: true, email: true, status: true, createdAt: true },
      }),
      prisma.report.groupBy({
        by: ['status'],
        where: { ...reportWhere, status: { not: 'DRAFT' } },
        _count: { _all: true },
      }),
      prisma.userActivityRecord.groupBy({
        by: ['status'],
        where: recordWhere,
        _count: { _all: true },
      }),
      prisma.userActivityRecord.groupBy({
        by: ['category'],
        where: { ...recordWhere, status: 'COMPLETED' },
        _count: { _all: true },
        orderBy: { _count: { category: 'desc' } },
      }),
      prisma.prayerSession.groupBy({
        by: ['status'],
        where: dateFilter ? { date: dateFilter } : {},
        _count: { _all: true },
      }),
      prisma.announcement.count({ where: { status: 'PUBLISHED' } }),
      prisma.safetyReport.count({ where: { status: 'OPEN' } }),
    ]);

    // Participation over time: records + submitted reports grouped by month.
    const noLowerBound = new Date(Date.UTC(2000, 0, 1));
    const participation = await prisma.$queryRaw(
      Prisma.sql`
        SELECT to_char(date_trunc('month', "date"), 'YYYY-MM') AS month,
               COUNT(*)::int AS activity_records,
               COUNT(*) FILTER (WHERE status = 'COMPLETED')::int AS completed
        FROM "UserActivityRecord"
        WHERE "date" >= ${dateFilter?.gte ?? noLowerBound}
        ${dateFilter?.lt ? Prisma.sql`AND "date" < ${dateFilter.lt}` : Prisma.empty}
        GROUP BY 1
        ORDER BY 1
        LIMIT 24`
    );

    const reportsByMonth = await prisma.$queryRaw(
      Prisma.sql`
        SELECT to_char(date_trunc('month', "submittedAt"), 'YYYY-MM') AS month,
               COUNT(*)::int AS submitted,
               COUNT(*) FILTER (WHERE status = 'REVIEWED')::int AS reviewed
        FROM "Report"
        WHERE "submittedAt" IS NOT NULL
        ${dateFilter ? Prisma.sql`AND "submittedAt" >= ${dateFilter.gte}` : Prisma.empty}
        ${dateFilter?.lt ? Prisma.sql`AND "submittedAt" < ${dateFilter.lt}` : Prisma.empty}
        GROUP BY 1
        ORDER BY 1
        LIMIT 24`
    );

    const reports = Object.fromEntries(reportStatusGroups.map((r) => [r.status, r._count._all]));
    const awaitingReview = (reports.SUBMITTED || 0) + (reports.REQUIRES_FOLLOW_UP || 0);
    const records = Object.fromEntries(recordsGroup.map((r) => [r.status, r._count._all]));

    // Active during period: members with any record/report in the period.
    const activeDuringPeriod = await prisma.user.count({
      where: {
        ...userWhere,
        ...(dateFilter
          ? {
              OR: [
                { activityRecords: { some: { date: dateFilter } } },
                { reports: { some: { submittedAt: dateFilter } } },
              ],
            }
          : {}),
      },
    });

    res.json({
      filters: { year: year || null, month: month || null, status: status || null },
      members: {
        total: totalMembers,
        active: activeMembers,
        pending: pendingMembers,
        activeDuringPeriod,
      },
      reports: {
        ...reports,
        awaitingReview,
        totalNonDraft: Object.values(reports).reduce((a, b) => a + b, 0),
      },
      activityCompletion: {
        byStatus: records,
        completedByCategory: activityTypes.map((t) => ({ category: t.category, completed: t._count._all })),
        totalRecords: Object.values(records).reduce((a, b) => a + b, 0),
      },
      prayerSessions: Object.fromEntries(prayerSessionStats.map((s) => [s.status, s._count._all])),
      participationOverTime: participation.map((p) => ({
        month: p.month,
        activityRecords: p.activity_records,
        completed: p.completed,
      })),
      reportsOverTime: reportsByMonth.map((r) => ({ month: r.month, submitted: r.submitted, reviewed: r.reviewed })),
      recentSignups,
      announcementsPublished: announcementCount,
      openSafetyReports: safetyOpen,
    });
  })
);

/** GET /api/v1/admin/analytics/export — CSV summary of member participation. */
analyticsRouter.get(
  '/analytics/export',
  asyncHandler(async (req, res) => {
    const members = await prisma.user.findMany({
      where: { role: 'MEMBER' },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        status: true,
        createdAt: true,
        _count: { select: { activityRecords: true, reports: true, goals: true } },
      },
    });

    const header = 'email,first_name,last_name,status,joined_at,activity_records,reports,goals';
    const lines = members.map((m) =>
      [m.email, m.firstName, m.lastName, m.status, m.createdAt.toISOString(), m._count.activityRecords, m._count.reports, m._count.goals]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',')
    );
    await audit({ actor: req.user, action: 'analytics_exported', targetType: 'analytics', targetId: 'member_summary', details: { rows: members.length }, req });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="mygrowth-member-summary-${Date.now()}.csv"`);
    res.send([header, ...lines].join('\n'));
  })
);

// ---------------------------------------------------------------------------
// Audit logs
// ---------------------------------------------------------------------------

auditRouter.get(
  '/audit-logs',
  validate({
    query: paginationQuery.extend({
      actorId: z.string().uuid().optional(),
      targetType: z.string().trim().max(60).optional(),
      action: z.string().trim().max(80).optional(),
      outcome: z.enum(['SUCCESS', 'DENIED']).optional(),
      from: z.string().max(40).optional(),
      to: z.string().max(40).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, actorId, targetType, action, outcome, from, to } = req.valid.query;
    const where = {};
    if (actorId) where.actorId = actorId;
    if (targetType) where.targetType = targetType;
    if (action) where.action = { contains: action };
    if (outcome) where.outcome = outcome;
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = new Date(from);
      if (to) where.createdAt.lte = new Date(to);
    }

    const result = await paginate(prisma.auditLog, {
      where,
      orderBy: { createdAt: 'desc' },
      include: { actor: { select: { id: true, firstName: true, lastName: true, email: true } } },
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

// ---------------------------------------------------------------------------
// Settings (allowed keys only — never role or auth related)
// ---------------------------------------------------------------------------

const settingsSchema = z.object({
  'registration.approvalRequired': z.boolean().optional(),
  'goals.maxMonthlySuggested': z.coerce.number().int().min(1).max(10).optional(),
  'goals.allowExtra': z.boolean().optional(),
  'announcements.notifyOnPublish': z.boolean().optional(),
});

settingsRouter.get(
  '/settings',
  asyncHandler(async (req, res) => {
    res.json({ settings: await getAllSettings(), keys: SETTING_KEYS });
  })
);

settingsRouter.patch(
  '/settings',
  validate({ body: settingsSchema }),
  asyncHandler(async (req, res) => {
    const updates = req.valid.body;
    const changed = {};
    for (const [key, value] of Object.entries(updates)) {
      if (value === undefined) continue;
      changed[key] = await setSetting(key, value, req.user.id);
    }
    await audit({
      actor: req.user,
      action: 'settings_updated',
      targetType: 'setting',
      targetId: null,
      details: { keys: Object.keys(changed) },
      req,
    });
    res.json({ settings: await getAllSettings(), changed });
  })
);

export { getSetting, errors };
