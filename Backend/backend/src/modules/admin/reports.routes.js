import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { notify } from '../../services/notifications.js';
import { REPORT_VISIBILITY_NOTICE } from '../../lib/reportFields.js';

export const reportsRouter = Router();
export const safetyRouter = Router();

/**
 * GET /api/v1/admin/reports — submitted accountability reports with filters.
 * Admins see report answers (accountability), never private reflection text.
 */
reportsRouter.get(
  '/reports',
  validate({
    query: paginationQuery.extend({
      status: z.enum(['DRAFT', 'SUBMITTED', 'REQUIRES_FOLLOW_UP', 'REVIEWED']).optional(),
      periodType: z.enum(['WEEK', 'MONTH', 'QUARTER', 'YEAR']).optional(),
      periodKey: z.string().trim().max(20).optional(),
      reportType: z.enum(['WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL']).optional(),
      type: z.enum(['WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL']).optional(),
      userId: z.string().uuid().optional(),
      programmeId: z.string().uuid().optional(),
      programmeYear: z.coerce.number().int().min(2000).max(2100).optional(),
      search: z.string().trim().max(200).optional(),
      from: z.string().max(20).optional(),
      to: z.string().max(20).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status, periodType, periodKey, reportType, type, userId, programmeId, programmeYear, search, from, to } = req.valid.query;
    const where = {};
    // Drafts stay member-private: admins only see submitted-or-later reports.
    where.status = status && status !== 'DRAFT' ? status : { not: 'DRAFT' };
    if (periodType) where.periodType = periodType;
    if (periodKey) where.periodKey = periodKey;
    const typeFilter = reportType ?? type;
    if (typeFilter) where.reportType = typeFilter;
    if (userId) where.userId = userId;
    if (programmeId) where.programmeId = programmeId;
    if (programmeYear) where.programme = { year: programmeYear };
    if (!userId && search) {
      where.user = {
        OR: [
          { firstName: { contains: search, mode: 'insensitive' } },
          { lastName: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
        ],
      };
    }
    if (from || to) {
      where.submittedAt = {};
      if (from) where.submittedAt.gte = new Date(from);
      if (to) where.submittedAt.lte = new Date(to);
    }

    const result = await paginate(prisma.report, {
      where,
      orderBy: { submittedAt: 'desc' },
      include: {
        user: { select: { id: true, firstName: true, lastName: true, email: true } },
        _count: { select: { answers: true, reviews: true } },
      },
      page,
      pageSize,
    });

    res.json({
      data: result.data.map((r) => ({
        id: r.id,
        periodType: r.periodType,
        periodKey: r.periodKey,
        reportType: r.reportType,
        status: r.status,
        revision: r.revision,
        submittedAt: r.submittedAt,
        reviewedAt: r.reviewedAt,
        visibilityNotice: r.visibilityNotice,
        user: r.user,
        answerCount: r._count.answers,
        reviewCount: r._count.reviews,
      })),
      meta: result.meta,
    });
  })
);

reportsRouter.get(
  '/reports/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const report = await prisma.report.findUnique({
      where: { id: req.valid.params.id },
      include: {
        answers: true,
        user: { select: { id: true, firstName: true, lastName: true, email: true, timezone: true } },
        reviews: { orderBy: { createdAt: 'desc' }, include: { reviewer: { select: { id: true, firstName: true, lastName: true, role: true } } } },
        revisions: { orderBy: { revisionNumber: 'desc' } },
      },
    });
    if (!report || report.status === 'DRAFT') {
      throw errors.notFound('Report not found', 'NOT_FOUND');
    }

    const answers = Object.fromEntries(report.answers.map((a) => [a.fieldKey, a.value]));
    const payload = {
      id: report.id,
      periodType: report.periodType,
      periodKey: report.periodKey,
      reportType: report.reportType,
      status: report.status,
      revision: report.revision,
      visibilityNotice: report.visibilityNotice || REPORT_VISIBILITY_NOTICE,
      submittedAt: report.submittedAt,
      reviewedAt: report.reviewedAt,
      answers,
      user: report.user,
      // Member's original responses stay intact; reviews are additive.
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
    // `data` is what the Flutter api_client unwraps; `report` is kept for
    // existing clients/tests that read the named wrapper.
    res.json({ data: payload, report: payload });
  })
);

const REVIEW_ACTIONS = ['COMMENT', 'REQUEST_FOLLOW_UP', 'MARK_REVIEWED', 'FOLLOW_UP', 'REVIEWED'];

const reviewSchema = z
  .object({
    // The Flutter admin UI sends `action`; the e2e smoke test sends `kind`.
    action: z.enum(REVIEW_ACTIONS).optional(),
    kind: z.enum(REVIEW_ACTIONS).optional(),
    comment: z.string().trim().max(4000).optional(),
  })
  .refine((b) => Boolean(b.action ?? b.kind), {
    message: 'action is required',
    path: ['action'],
  });

/** Map the client-facing review verbs onto the stored ReportReviewAction enum. */
function normalizeReviewAction(value) {
  if (value === 'FOLLOW_UP') return 'REQUEST_FOLLOW_UP';
  if (value === 'REVIEWED') return 'MARK_REVIEWED';
  return value;
}

/**
 * POST /api/v1/admin/reports/:id/reviews — comment, request follow-up or mark
 * reviewed. Admins can never rewrite the member's answers (there is no
 * endpoint for that); everything is additive and audit-logged.
 */
reportsRouter.post(
  '/reports/:id/reviews',
  validate({ params: z.object({ id: uuidSchema }), body: reviewSchema }),
  asyncHandler(async (req, res) => {
    const { comment } = req.valid.body;
    const action = normalizeReviewAction(req.valid.body.action ?? req.valid.body.kind);
    const report = await prisma.report.findUnique({ where: { id: req.valid.params.id } });
    if (!report || report.status === 'DRAFT') throw errors.notFound('Report not found', 'NOT_FOUND');
    if ((action === 'COMMENT' || action === 'REQUEST_FOLLOW_UP') && !comment) {
      throw errors.badRequest('A comment is required for this action', 'VALIDATION_ERROR');
    }

    const [review] = await prisma.$transaction([
      prisma.reportReview.create({
        data: { reportId: report.id, reviewerId: req.user.id, action, comment: comment ?? null },
      }),
      prisma.report.update({
        where: { id: report.id },
        data:
          action === 'MARK_REVIEWED'
            ? { status: 'REVIEWED', reviewedAt: new Date() }
            : action === 'REQUEST_FOLLOW_UP'
              ? { status: 'REQUIRES_FOLLOW_UP' }
              : {},
      }),
    ]);

    await audit({
      actor: req.user,
      action: 'report_reviewed',
      targetType: 'report',
      targetId: report.id,
      details: { reviewAction: action, reportType: report.reportType, periodKey: report.periodKey },
      req,
    });

    const eventType = action === 'REQUEST_FOLLOW_UP' ? 'admin_report_follow_up' : 'admin_report_comment';
    await notify({
      userId: report.userId,
      eventType,
      eventKey: `${report.id}:${review.id}`,
      title: action === 'REQUEST_FOLLOW_UP' ? 'Follow-up requested on your report' : 'Administrator comment on your report',
      body: comment || null,
      data: { reportId: report.id, action },
    });

    const fresh = await prisma.report.findUnique({ where: { id: report.id } });
    res.status(201).json({ review, report: { id: fresh.id, status: fresh.status, reviewedAt: fresh.reviewedAt } });
  })
);

// ---------------------------------------------------------------------------
// Safety reports (prayer-partner abuse reports) — restricted admin view
// ---------------------------------------------------------------------------

safetyRouter.get(
  '/safety-reports',
  validate({ query: paginationQuery.extend({ status: z.enum(['OPEN', 'REVIEWED', 'RESOLVED']).optional() }) }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status } = req.valid.query;
    const where = status ? { status } : {};
    const result = await paginate(prisma.safetyReport, {
      where,
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      include: {
        reporter: { select: { id: true, firstName: true, lastName: true } },
        reported: { select: { id: true, firstName: true, lastName: true } },
      },
      page,
      pageSize,
    });
    res.json({ data: result.data, meta: result.meta });
  })
);

safetyRouter.patch(
  '/safety-reports/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({
      action: z.enum(['review', 'resolve']),
      resolutionNote: z.string().trim().max(2000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const report = await prisma.safetyReport.findUnique({ where: { id: req.valid.params.id } });
    if (!report) throw errors.notFound('Safety report not found', 'NOT_FOUND');
    const { action, resolutionNote } = req.valid.body;
    const updated = await prisma.safetyReport.update({
      where: { id: report.id },
      data:
        action === 'review'
          ? { status: 'REVIEWED' }
          : { status: 'RESOLVED', resolvedById: req.user.id, resolutionNote: resolutionNote ?? null, resolvedAt: new Date() },
    });
    await audit({
      actor: req.user,
      action: `safety_report_${action}ed`,
      targetType: 'safety_report',
      targetId: report.id,
      details: { status: updated.status },
      req,
    });
    res.json({ safetyReport: updated });
  })
);
