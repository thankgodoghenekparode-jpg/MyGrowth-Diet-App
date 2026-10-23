import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema, monthSchema } from '../../lib/validate.js';
import { audit } from '../../lib/audit.js';
import { isoDate, dateFromISO } from '../../lib/dates.js';
import {
  DAILY_DIET_BEHAVIOURS,
  DAILY_DIET_SECTION_KEYS,
  DAILY_DIET_SCOPES,
  defaultContentTitle,
  anchorDateForScope,
  contentAnchors,
} from '../../lib/dailyDiet.js';

/**
 * Admin management of the Daily Diet.
 *
 * - `/daily-diet/sections` — the structure members follow (which sections
 *   exist, their labels, order and behaviour).
 * - `/daily-diet/content` — the content each section carries on a given day.
 *
 * Mounted under `/api/v1/admin`.
 */
export const dailyDietRouter = Router();

const sectionShape = (s) => ({
  id: s.id,
  programmeId: s.programmeId,
  key: s.key,
  label: s.label,
  description: s.description,
  behaviour: s.behaviour,
  sortOrder: s.sortOrder,
  enabled: s.enabled,
  required: s.required,
  allowNote: s.allowNote,
  trackCompletion: s.trackCompletion,
  status: s.status,
  createdAt: s.createdAt,
  updatedAt: s.updatedAt,
  _count: s._count ?? undefined,
});

const contentShape = (c) => ({
  id: c.id,
  sectionId: c.sectionId,
  sectionKey: c.section?.key ?? null,
  sectionLabel: c.section?.label ?? null,
  date: isoDate(c.date),
  scope: c.scope,
  title: c.title,
  body: c.body,
  details: c.details ?? null,
  materialIds: Array.isArray(c.materialIds) ? c.materialIds : [],
  externalUrl: c.externalUrl,
  durationTargetMinutes: c.durationTargetMinutes,
  sortOrder: c.sortOrder,
  status: c.status,
  publishedAt: c.publishedAt,
  createdAt: c.createdAt,
  updatedAt: c.updatedAt,
});

// ---------------------------------------------------------------------------
// Sections — the structure
// ---------------------------------------------------------------------------

const sectionBody = z.object({
  programmeId: uuidSchema.optional(),
  year: z.coerce.number().int().min(2000).max(2100).optional(),
  key: z
    .string()
    .trim()
    .min(1)
    .max(60)
    .regex(/^[a-z0-9_]+$/, 'Key must be lowercase letters, numbers and underscores'),
  label: z.string().trim().min(1).max(120),
  description: z.string().max(2000).nullable().optional(),
  behaviour: z.enum(DAILY_DIET_BEHAVIOURS).default('TEXT'),
  sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
  enabled: z.boolean().optional(),
  required: z.boolean().optional(),
  allowNote: z.boolean().optional(),
  trackCompletion: z.boolean().optional(),
  status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
});

/** Resolve the programme a section belongs to. */
async function programmeFor(body) {
  if (body.programmeId) {
    const programme = await prisma.programme.findUnique({
      where: { id: body.programmeId },
    });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    return programme;
  }
  const year = body.year;
  if (!year) {
    throw errors.badRequest('Provide either programmeId or year', 'VALIDATION_ERROR');
  }
  const programme = await prisma.programme.findFirst({
    where: { year },
    orderBy: { createdAt: 'desc' },
  });
  if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
  return programme;
}

/**
 * GET /api/v1/admin/daily-diet/sections?year=2027 — the structure.
 */
dailyDietRouter.get(
  '/daily-diet/sections',
  validate({
    query: z.object({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      programmeId: uuidSchema.optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { year, programmeId } = req.valid.query;
    let programme = null;
    if (programmeId) {
      programme = await prisma.programme.findUnique({ where: { id: programmeId } });
    } else if (year) {
      programme = await prisma.programme.findFirst({
        where: { year },
        orderBy: { createdAt: 'desc' },
      });
    } else {
      programme = await prisma.programme.findFirst({
        orderBy: { year: 'desc' },
      });
    }
    if (!programme) return res.json({ data: [], programme: null });

    const sections = await prisma.dailyDietSection.findMany({
      where: { programmeId: programme.id },
      orderBy: [{ sortOrder: 'asc' }, { key: 'asc' }],
      include: { _count: { select: { contents: true, completions: true } } },
    });
    res.json({
      programme: {
        id: programme.id,
        title: programme.title,
        year: programme.year,
        status: programme.status,
      },
      data: sections.map(sectionShape),
    });
  })
);

/**
 * POST /api/v1/admin/daily-diet/sections — add a section to the structure.
 */
dailyDietRouter.post(
  '/daily-diet/sections',
  validate({ body: sectionBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const programme = await programmeFor(b);

    const existing = await prisma.dailyDietSection.findUnique({
      where: { programmeId_key: { programmeId: programme.id, key: b.key } },
    });
    if (existing) {
      throw errors.conflict('A section with this key already exists', 'DUPLICATE_SECTION');
    }

    const maxOrder = await prisma.dailyDietSection.aggregate({
      where: { programmeId: programme.id },
      _max: { sortOrder: true },
    });

    const section = await prisma.dailyDietSection.create({
      data: {
        programmeId: programme.id,
        key: b.key,
        label: b.label,
        description: b.description ?? null,
        behaviour: b.behaviour,
        sortOrder: b.sortOrder ?? (maxOrder._max.sortOrder ?? 0) + 1,
        enabled: b.enabled ?? true,
        required: b.required ?? true,
        allowNote: b.allowNote ?? true,
        trackCompletion: b.trackCompletion ?? true,
        status: b.status ?? 'DRAFT',
      },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_section_created',
      targetType: 'daily_diet_section',
      targetId: section.id,
      details: { key: section.key, label: section.label },
      req,
    });
    res.status(201).json({ section: sectionShape(section) });
  })
);

/**
 * PATCH /api/v1/admin/daily-diet/sections/:id — rename, reorder, re-behaviour.
 */
dailyDietRouter.patch(
  '/daily-diet/sections/:id',
  validate({ params: z.object({ id: uuidSchema }), body: sectionBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietSection.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Section not found', 'NOT_FOUND');

    const b = { ...req.valid.body };
    delete b.programmeId;
    delete b.year;
    if (b.key && b.key !== existing.key) {
      const clash = await prisma.dailyDietSection.findUnique({
        where: { programmeId_key: { programmeId: existing.programmeId, key: b.key } },
      });
      if (clash) throw errors.conflict('A section with this key already exists', 'DUPLICATE_SECTION');
    }
    if (b.status === 'PUBLISHED' && existing.status !== 'PUBLISHED') {
      b.status = 'PUBLISHED';
    }

    const section = await prisma.dailyDietSection.update({
      where: { id: existing.id },
      data: b,
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_section_updated',
      targetType: 'daily_diet_section',
      targetId: section.id,
      details: { fields: Object.keys(b) },
      req,
    });
    res.json({ section: sectionShape(section) });
  })
);

dailyDietRouter.post(
  '/daily-diet/sections/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietSection.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Section not found', 'NOT_FOUND');
    const section = await prisma.dailyDietSection.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED' },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_section_published',
      targetType: 'daily_diet_section',
      targetId: section.id,
      details: { key: section.key },
      req,
    });
    res.json({ section: sectionShape(section) });
  })
);

dailyDietRouter.post(
  '/daily-diet/sections/:id/archive',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietSection.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Section not found', 'NOT_FOUND');
    const section = await prisma.dailyDietSection.update({
      where: { id: existing.id },
      data: { status: 'ARCHIVED', enabled: false },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_section_archived',
      targetType: 'daily_diet_section',
      targetId: section.id,
      details: { key: section.key },
      req,
    });
    res.json({ section: sectionShape(section) });
  })
);

dailyDietRouter.delete(
  '/daily-diet/sections/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietSection.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Section not found', 'NOT_FOUND');
    await prisma.dailyDietSection.delete({ where: { id: existing.id } });
    await audit({
      actor: req.user,
      action: 'daily_diet_section_deleted',
      targetType: 'daily_diet_section',
      targetId: existing.id,
      details: { key: existing.key },
      req,
    });
    res.json({ ok: true });
  })
);

/**
 * POST /api/v1/admin/daily-diet/sections/reorder — set the order in one call.
 * Body: { programmeId, order: [sectionId, …] }
 */
dailyDietRouter.post(
  '/daily-diet/sections/reorder',
  validate({
    body: z.object({
      programmeId: uuidSchema,
      order: z.array(uuidSchema).max(100),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { programmeId, order } = req.valid.body;
    await prisma.$transaction(
      order.map((id, index) =>
        prisma.dailyDietSection.updateMany({
          where: { id, programmeId },
          data: { sortOrder: index + 1 },
        })
      )
    );
    const sections = await prisma.dailyDietSection.findMany({
      where: { programmeId },
      orderBy: [{ sortOrder: 'asc' }, { key: 'asc' }],
    });
    res.json({ data: sections.map(sectionShape) });
  })
);

// ---------------------------------------------------------------------------
// Content — what each section carries on a given day
// ---------------------------------------------------------------------------

const contentBody = z.object({
  sectionId: uuidSchema.optional(),
  sectionKey: z.string().trim().min(1).max(60).optional(),
  date: dateSchema,
  scope: z.enum(DAILY_DIET_SCOPES).default('DAY'),
  title: z.string().trim().min(1).max(300).optional(),
  body: z.string().max(20000).nullable().optional(),
  details: z.record(z.any()).nullable().optional(),
  materialIds: z.array(uuidSchema).max(50).nullable().optional(),
  externalUrl: z.string().trim().max(1000).nullable().optional(),
  durationTargetMinutes: z.coerce.number().int().min(1).max(600).nullable().optional(),
  sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
  status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
});

/** Find the section a content row belongs to (by id or key). */
async function sectionFor(body, programmeId) {
  let section = null;
  if (body.sectionId) {
    section = await prisma.dailyDietSection.findUnique({
      where: { id: body.sectionId },
    });
  } else if (body.sectionKey) {
    section = await prisma.dailyDietSection.findFirst({
      where: { key: body.sectionKey, ...(programmeId ? { programmeId } : {}) },
      orderBy: { createdAt: 'desc' },
    });
  }
  if (!section) throw errors.notFound('Daily Diet section not found', 'NOT_FOUND');
  return section;
}

/**
 * GET /api/v1/admin/daily-diet/content?year=&month=&date=&sectionId=
 *
 * Lists the content rows. With `date` it returns the whole day; with a month
 * it returns the month (useful for filling a month in one pass).
 */
dailyDietRouter.get(
  '/daily-diet/content',
  validate({
    query: z.object({
      year: z.coerce.number().int().min(2000).max(2100).optional(),
      month: monthSchema.optional(),
      date: dateSchema.optional(),
      sectionId: uuidSchema.optional(),
      programmeId: uuidSchema.optional(),
      status: z.enum(['DRAFT', 'PUBLISHED', 'ARCHIVED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { year, month, date, sectionId, programmeId, status } = req.valid.query;

    let programme = null;
    if (programmeId) {
      programme = await prisma.programme.findUnique({ where: { id: programmeId } });
    } else if (year) {
      programme = await prisma.programme.findFirst({
        where: { year },
        orderBy: { createdAt: 'desc' },
      });
    } else {
      programme = await prisma.programme.findFirst({ orderBy: { year: 'desc' } });
    }
    if (!programme) return res.json({ data: [], programme: null });

    const where = { section: { programmeId: programme.id } };
    if (sectionId) where.sectionId = sectionId;
    if (status) where.status = status;
    if (date) {
      // Everything that applies to the day: the day itself, its week and its
      // month. The scope on each row says which period it belongs to.
      where.date = {
        in: contentAnchors(date).map((a) => dateFromISO(a.date)),
      };
    } else if (month) {
      const start = new Date(Date.UTC(year ?? programme.year, month - 1, 1));
      const end = new Date(Date.UTC(year ?? programme.year, month, 1));
      where.date = { gte: start, lt: end };
    }

    const rows = await prisma.dailyDietContent.findMany({
      where,
      orderBy: [{ date: 'asc' }, { sortOrder: 'asc' }],
      include: { section: { select: { id: true, key: true, label: true, behaviour: true } } },
    });
    res.json({
      programme: { id: programme.id, title: programme.title, year: programme.year },
      data: rows.map(contentShape),
    });
  })
);

/**
 * PUT /api/v1/admin/daily-diet/content — create or replace the content a
 * section carries on a date (upsert on section + date).
 */
dailyDietRouter.put(
  '/daily-diet/content',
  validate({ body: contentBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const section = await sectionFor(b, null);
    const scope = b.scope ?? 'DAY';
    // A week- or month-scoped row is always filed against its anchor (the
    // Sunday that starts the week, the first of the month) so members find it
    // on every day the period covers.
    const date = dateFromISO(anchorDateForScope(b.date, scope));

    if (b.materialIds?.length) {
      const found = await prisma.material.count({ where: { id: { in: b.materialIds } } });
      if (found !== b.materialIds.length) {
        throw errors.badRequest('One or more materialIds do not exist', 'VALIDATION_ERROR');
      }
    }

    const title = b.title?.trim() || defaultContentTitle(section.key);
    const data = {
      title,
      body: b.body ?? null,
      details: b.details ?? null,
      materialIds: b.materialIds ?? [],
      externalUrl: b.externalUrl ?? null,
      durationTargetMinutes: b.durationTargetMinutes ?? null,
      sortOrder: b.sortOrder ?? 0,
      status: b.status ?? 'DRAFT',
      publishedAt: (b.status ?? 'DRAFT') === 'PUBLISHED' ? new Date() : null,
    };

    const content = await prisma.dailyDietContent.upsert({
      where: { sectionId_date: { sectionId: section.id, date } },
      create: { sectionId: section.id, date, scope, ...data },
      update: { scope, ...data },
      include: { section: { select: { id: true, key: true, label: true, behaviour: true } } },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_content_saved',
      targetType: 'daily_diet_content',
      targetId: content.id,
      details: { section: section.key, date: isoDate(date) },
      req,
    });
    res.json({ content: contentShape(content) });
  })
);

dailyDietRouter.patch(
  '/daily-diet/content/:id',
  validate({ params: z.object({ id: uuidSchema }), body: contentBody.partial() }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietContent.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Content not found', 'NOT_FOUND');

    const b = { ...req.valid.body };
    delete b.sectionId;
    delete b.sectionKey;
    delete b.date;
    if (b.status === 'PUBLISHED') b.publishedAt = new Date();

    // Changing the scope moves the row to its period's anchor, so it keeps
    // showing on every day the new period covers.
    if (b.scope && b.scope !== existing.scope) {
      const anchored = anchorDateForScope(isoDate(existing.date), b.scope);
      if (anchored !== isoDate(existing.date)) {
        const clash = await prisma.dailyDietContent.findUnique({
          where: {
            sectionId_date: { sectionId: existing.sectionId, date: dateFromISO(anchored) },
          },
        });
        if (clash && clash.id !== existing.id) {
          throw errors.conflict(
            'Another content row already covers that period',
            'DUPLICATE_CONTENT'
          );
        }
        b.date = dateFromISO(anchored);
      }
    }

    const content = await prisma.dailyDietContent.update({
      where: { id: existing.id },
      data: b,
      include: { section: { select: { id: true, key: true, label: true, behaviour: true } } },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_content_updated',
      targetType: 'daily_diet_content',
      targetId: content.id,
      details: { fields: Object.keys(b) },
      req,
    });
    res.json({ content: contentShape(content) });
  })
);

dailyDietRouter.post(
  '/daily-diet/content/:id/publish',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietContent.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Content not found', 'NOT_FOUND');
    const content = await prisma.dailyDietContent.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED', publishedAt: new Date() },
      include: { section: { select: { id: true, key: true, label: true, behaviour: true } } },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_content_published',
      targetType: 'daily_diet_content',
      targetId: content.id,
      details: { date: isoDate(content.date) },
      req,
    });
    res.json({ content: contentShape(content) });
  })
);

dailyDietRouter.delete(
  '/daily-diet/content/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const existing = await prisma.dailyDietContent.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!existing) throw errors.notFound('Content not found', 'NOT_FOUND');
    await prisma.dailyDietContent.delete({ where: { id: existing.id } });
    await audit({
      actor: req.user,
      action: 'daily_diet_content_deleted',
      targetType: 'daily_diet_content',
      targetId: existing.id,
      req,
    });
    res.json({ ok: true });
  })
);

/**
 * POST /api/v1/admin/daily-diet/content/publish-day — publish every content
 * row for one date in a single call (the admin fills a day, then publishes).
 */
dailyDietRouter.post(
  '/daily-diet/content/publish-day',
  validate({
    body: z.object({
      programmeId: uuidSchema.optional(),
      date: dateSchema,
      sectionId: uuidSchema.optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { date, sectionId } = req.valid.body;
    // Publish the day plus the week and month rows that cover it.
    const anchors = contentAnchors(date).map((a) => dateFromISO(a.date));
    const where = { date: { in: anchors }, status: { not: 'PUBLISHED' } };
    if (sectionId) where.sectionId = sectionId;

    const result = await prisma.dailyDietContent.updateMany({
      where,
      data: { status: 'PUBLISHED', publishedAt: new Date() },
    });
    await audit({
      actor: req.user,
      action: 'daily_diet_content_day_published',
      targetType: 'daily_diet_content',
      targetId: date,
      details: { date, count: result.count },
      req,
    });
    res.json({ published: result.count, date });
  })
);

export { DAILY_DIET_SECTION_KEYS, DAILY_DIET_BEHAVIOURS };
export default dailyDietRouter;
