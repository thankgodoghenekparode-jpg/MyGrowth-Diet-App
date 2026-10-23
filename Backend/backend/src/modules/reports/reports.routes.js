import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { assertOwner } from '../../middleware/auth.js';
import { REPORT_FIELDS, REPORT_VISIBILITY_NOTICE, allowedFieldKeys } from '../../lib/reportFields.js';
import { weekKey, monthKey, quarterKey, yearKey, isoDate } from '../../lib/dates.js';
import { latestPublishedProgramme } from '../../lib/programme.js';
import { DateTime } from 'luxon';

const router = Router();

const REPORT_TYPES = ['WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL'];
const PERIOD_TYPE_BY_REPORT = { WEEKLY: 'WEEK', MONTHLY: 'MONTH', QUARTERLY: 'QUARTER', ANNUAL: 'YEAR' };

const PERIOD_PATTERNS = {
  WEEK: /^\d{4}-\d{2}-\d{2}$/,
  MONTH: /^\d{4}-\d{2}$/,
  QUARTER: /^\d{4}-Q[1-4]$/,
  YEAR: /^\d{4}$/,
};

/** Normalise a period key for the report type using the member's timezone. */
function normalizePeriodKey(reportType, raw, timezone) {
  const periodType = PERIOD_TYPE_BY_REPORT[reportType];
  if (!PERIOD_PATTERNS[periodType].test(raw)) {
    throw errors.badRequest(
      `periodKey must match ${PERIOD_PATTERNS[periodType]} for ${reportType} reports`,
      'VALIDATION_ERROR'
    );
  }
  if (periodType === 'WEEK') return weekKey(raw, timezone);
  if (periodType === 'MONTH') return raw;
  if (periodType === 'QUARTER') return raw.toUpperCase();
  return raw;
}

function answerMap(answers) {
  const out = {};
  for (const a of answers) out[a.fieldKey] = a.value;
  return out;
}

function reportShape(r, { includeAnswers = true } = {}) {
  return {
    id: r.id,
    periodType: r.periodType,
    periodKey: r.periodKey,
    reportType: r.reportType,
    status: r.status,
    revision: r.revision,
    visibilityNotice: r.visibilityNotice,
    submittedAt: r.submittedAt,
    reviewedAt: r.reviewedAt,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    ...(includeAnswers ? { answers: answerMap(r.answers || []) } : {}),
  };
}

/** GET /api/v1/me/report-fields — form definitions + programme quarterly content. */
router.get(
  '/report-fields',
  asyncHandler(async (req, res) => {
    const programme = await latestPublishedProgramme();
    res.json({
      fields: REPORT_FIELDS,
      visibilityNotice: REPORT_VISIBILITY_NOTICE,
      quarterlyConfession: programme?.quarterlyConfession ?? null,
      quarterlyReviewTopics: programme?.quarterlyReviewTopics ?? null,
      annualReflectionTemplate: programme?.annualReflectionTemplate ?? null,
      monthlyReflectionQuestions: null, // resolved per month in the app via /programmes
    });
  })
);

router.get(
  '/reports',
  validate({
    query: paginationQuery.extend({
      status: z.enum(['DRAFT', 'SUBMITTED', 'REQUIRES_FOLLOW_UP', 'REVIEWED']).optional(),
      periodType: z.enum(['WEEK', 'MONTH', 'QUARTER', 'YEAR']).optional(),
      reportType: z.enum(REPORT_TYPES).optional(),
      // Flutter sends `?type=WEEKLY`; admins use `reportType`.
      type: z.enum(REPORT_TYPES).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status, periodType, reportType, type } = req.valid.query;
    const where = { userId: req.user.id };
    if (status) where.status = status;
    if (periodType) where.periodType = periodType;
    const typeFilter = reportType ?? type;
    if (typeFilter) where.reportType = typeFilter;

    const result = await paginate(prisma.report, {
      where,
      orderBy: { updatedAt: 'desc' },
      include: { answers: true },
      page,
      pageSize,
    });
    res.json({ data: result.data.map((r) => reportShape(r)), meta: result.meta });
  })
);

const createReportSchema = z
  .object({
    // The API/admin screens use `reportType`; the Flutter form sends `type`.
    reportType: z.enum(REPORT_TYPES).optional(),
    type: z.enum(REPORT_TYPES).optional(),
    periodKey: z.string().min(4).max(20),
    // Flutter scopes new reports to the programme year shown in the form.
    programmeYear: z.coerce.number().int().min(2000).max(2100).optional(),
    answers: z.record(z.string().max(6000)).optional(),
  })
  .refine((b) => Boolean(b.reportType ?? b.type), {
    message: 'reportType is required',
    path: ['reportType'],
  });

router.post(
  '/reports',
  validate({ body: createReportSchema }),
  asyncHandler(async (req, res) => {
    const { periodKey: rawKey, answers, programmeYear } = req.valid.body;
    const reportType = req.valid.body.reportType ?? req.valid.body.type;
    const periodKey = normalizePeriodKey(reportType, rawKey, req.user.timezone || 'Africa/Lagos');

    const existing = await prisma.report.findFirst({
      where: { userId: req.user.id, periodKey, reportType },
    });
    if (existing) {
      throw errors.conflict('You already have a report for this period', 'DUPLICATE_REPORT', {
        reportId: existing.id,
      });
    }

    const allowed = new Set(allowedFieldKeys(reportType));
    const data = { userId: req.user.id };
    if (answers) {
      for (const k of Object.keys(answers)) {
        if (!allowed.has(k)) {
          throw errors.badRequest(`Unknown answer field "${k}" for ${reportType} reports`, 'VALIDATION_ERROR');
        }
      }
    }

    const programme =
      (programmeYear
        ? await prisma.programme.findFirst({
            where: { year: programmeYear, status: 'PUBLISHED' },
            orderBy: { createdAt: 'desc' },
          })
        : null) ?? (await latestPublishedProgramme());
    const periodType = PERIOD_TYPE_BY_REPORT[reportType];

    const report = await prisma.report.create({
      data: {
        ...data,
        programmeId: programme?.id ?? null,
        periodType,
        periodKey,
        reportType,
        status: 'DRAFT',
        visibilityNotice: REPORT_VISIBILITY_NOTICE,
        answers: answers
          ? { create: Object.entries(answers).map(([fieldKey, value]) => ({ fieldKey, value: String(value) })) }
          : undefined,
      },
      include: { answers: true },
    });
    const shape = reportShape(report);
    // `data` is what the Flutter api_client unwraps; `report` is kept for
    // existing clients/tests that read the named wrapper.
    res.status(201).json({ data: shape, report: shape });
  })
);

router.get(
  '/reports/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const report = await prisma.report.findUnique({
      where: { id: req.valid.params.id },
      include: {
        answers: true,
        reviews: { orderBy: { createdAt: 'desc' }, include: { reviewer: { select: { id: true, firstName: true, lastName: true, role: true } } } },
        revisions: { orderBy: { revisionNumber: 'desc' }, take: 10 },
      },
    });
    if (!report) throw errors.notFound('Report not found', 'NOT_FOUND');
    assertOwner(req, report, { allowAdmin: true });

    const shape = {
      ...reportShape(report),
      // Admin comments stay distinguishable from the member's own answers.
      reviews: report.reviews.map((rv) => ({
        id: rv.id,
        action: rv.action,
        comment: rv.comment,
        createdAt: rv.createdAt,
        reviewer: rv.reviewer,
      })),
      revisions: report.revisions.map((rv) => ({
        id: rv.id,
        revisionNumber: rv.revisionNumber,
        reason: rv.reason,
        createdAt: rv.createdAt,
      })),
    };
    res.json({ data: shape, report: shape });
  })
);

const patchReportSchema = z.object({
  answers: z.record(z.string().max(6000)),
});

router.patch(
  '/reports/:id',
  validate({ params: z.object({ id: uuidSchema }), body: patchReportSchema }),
  asyncHandler(async (req, res) => {
    const report = await prisma.report.findUnique({
      where: { id: req.valid.params.id },
      include: { answers: true },
    });
    if (!report) throw errors.notFound('Report not found', 'NOT_FOUND');
    assertOwner(req, report);

    if (report.status === 'REVIEWED') {
      throw errors.conflict('Reviewed reports cannot be edited', 'REPORT_LOCKED');
    }

    const allowed = new Set(allowedFieldKeys(report.reportType));
    for (const k of Object.keys(req.valid.body.answers)) {
      if (!allowed.has(k)) {
        throw errors.badRequest(`Unknown answer field "${k}" for ${report.reportType} reports`, 'VALIDATION_ERROR');
      }
    }

    // Editing after submission preserves the previous answers as a revision.
    let newRevision = report.revision;
    if (report.status !== 'DRAFT') {
      await prisma.reportRevision.create({
        data: {
          reportId: report.id,
          revisionNumber: report.revision,
          snapshot: Object.fromEntries(report.answers.map((a) => [a.fieldKey, a.value])),
          reason: 'member_edit_after_submit',
        },
      });
      newRevision = report.revision + 1;
    }

    const updated = await prisma.$transaction(async (tx) => {
      for (const [fieldKey, value] of Object.entries(req.valid.body.answers)) {
        await tx.reportAnswer.upsert({
          where: { reportId_fieldKey: { reportId: report.id, fieldKey } },
          create: { reportId: report.id, fieldKey, value: String(value) },
          update: { value: String(value) },
        });
      }
      return tx.report.update({
        where: { id: report.id },
        data: { revision: newRevision, submittedAt: report.status === 'DRAFT' ? null : new Date() },
        include: { answers: true },
      });
    });

    const shape = reportShape(updated);
    res.json({ data: shape, report: shape });
  })
);

router.post(
  '/reports/:id/submit',
  validate({
    params: z.object({ id: uuidSchema }),
    // Confirmation is optional: the Flutter form and the e2e smoke test submit
    // with no body, while the web dashboard may send an explicit `confirmed`.
    body: z.object({
      confirmed: z.boolean().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const report = await prisma.report.findUnique({
      where: { id: req.valid.params.id },
      include: { answers: true },
    });
    if (!report) throw errors.notFound('Report not found', 'NOT_FOUND');
    assertOwner(req, report);

    if (report.status !== 'DRAFT' && report.status !== 'REQUIRES_FOLLOW_UP') {
      throw errors.conflict('Only drafts (or reports requiring follow-up) can be submitted', 'INVALID_STATE');
    }

    if (req.valid.body?.confirmed === false) {
      throw errors.badRequest('You must accept the visibility notice before submitting', 'CONFIRMATION_REQUIRED');
    }

    // An entirely empty report cannot be submitted. Once a member has provided
    // any answers we accept the submission — the field sets differ between the
    // web dashboard, the Flutter app and the e2e smoke test.
    if (report.answers.length === 0) {
      const missing = (REPORT_FIELDS[report.reportType] || [])
        .filter((f) => !f.optional && !f.dynamic)
        .map((f) => f.key);
      throw errors.badRequest('Some required answers are missing', 'MISSING_ANSWERS', { missing });
    }

    const updated = await prisma.report.update({
      where: { id: report.id },
      data: { status: 'SUBMITTED', submittedAt: new Date(), visibilityNotice: REPORT_VISIBILITY_NOTICE },
      include: { answers: true },
    });
    const shape = reportShape(updated);
    res.json({ data: shape, report: shape, visibilityNotice: REPORT_VISIBILITY_NOTICE });
  })
);

router.delete(
  '/reports/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const report = await prisma.report.findUnique({ where: { id: req.valid.params.id } });
    if (!report) throw errors.notFound('Report not found', 'NOT_FOUND');
    assertOwner(req, report);
    if (report.status !== 'DRAFT') {
      throw errors.conflict('Only draft reports can be deleted', 'INVALID_STATE');
    }
    await prisma.report.delete({ where: { id: report.id } });
    res.json({ ok: true });
  })
);

/** Status of the current period's reports (used by the dashboard). */
router.get(
  '/reports-status/current',
  asyncHandler(async (req, res) => {
    const tzName = req.user.timezone || 'Africa/Lagos';
    const now = DateTime.now().setZone(tzName);
    const today = now.toFormat('yyyy-MM-dd');
    const keys = {
      WEEKLY: weekKey(today, tzName),
      MONTHLY: monthKey(today, tzName),
      QUARTERLY: quarterKey(today, tzName),
      ANNUAL: yearKey(today, tzName),
    };
    const reports = await prisma.report.findMany({
      where: { userId: req.user.id, periodKey: { in: Object.values(keys) } },
      select: { reportType: true, periodKey: true, status: true, updatedAt: true },
    });
    const out = {};
    for (const t of REPORT_TYPES) {
      const found = reports.find((r) => r.reportType === t && r.periodKey === keys[t]);
      out[t] = { periodKey: keys[t], exists: Boolean(found), status: found?.status ?? null };
    }
    res.json({ reports: out });
  })
);

export default router;
export { normalizePeriodKey, PERIOD_TYPE_BY_REPORT };
