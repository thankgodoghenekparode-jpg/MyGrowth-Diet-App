import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { assertOwner } from '../../middleware/auth.js';
import { dateFromISO, isoDate, nowInZone } from '../../lib/dates.js';
import { latestPublishedProgramme } from '../../lib/programme.js';

const router = Router();

/** Today's date (yyyy-MM-dd) in the member's timezone. */
function todayISO(req) {
  return nowInZone(req.user.timezone).toFormat('yyyy-MM-dd');
}

// ---------------------------------------------------------------------------
// Reflections — private journal entries (never exposed to admins/analytics)
// ---------------------------------------------------------------------------

const reflectionShape = (r) => ({
  id: r.id,
  entryDate: isoDate(r.entryDate),
  title: r.title,
  body: r.body,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
});

router.get(
  '/reflections',
  validate({
    query: paginationQuery.extend({
      from: dateSchema.optional(),
      to: dateSchema.optional(),
      search: z.string().trim().max(200).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, from, to, search } = req.valid.query;
    const where = { userId: req.user.id };
    if (from || to) {
      where.entryDate = {};
      if (from) where.entryDate.gte = dateFromISO(from);
      if (to) where.entryDate.lte = dateFromISO(to);
    }
    if (search) where.OR = [{ title: { contains: search, mode: 'insensitive' } }, { body: { contains: search, mode: 'insensitive' } }];

    const result = await paginate(prisma.reflectionEntry, {
      where,
      orderBy: { entryDate: 'desc' },
      page,
      pageSize,
    });
    res.json({ data: result.data.map(reflectionShape), meta: result.meta, private: true });
  })
);

router.post(
  '/reflections',
  validate({
    body: z.object({
      // Flutter omits entryDate when the member doesn't pick a date.
      entryDate: dateSchema.optional(),
      title: z.string().trim().min(1).max(200),
      body: z.string().min(1).max(20000),
    }),
  }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const entry = await prisma.reflectionEntry.create({
      data: {
        userId: req.user.id,
        entryDate: dateFromISO(b.entryDate ?? todayISO(req)),
        title: b.title,
        body: b.body,
      },
    });
    const shape = reflectionShape(entry);
    // `data` is what the Flutter api_client unwraps; `reflection` is kept for
    // clients/tests that read the named wrapper.
    res.status(201).json({ data: shape, reflection: shape, private: true });
  })
);

router.get(
  '/reflections/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const entry = await prisma.reflectionEntry.findUnique({ where: { id: req.valid.params.id } });
    if (!entry) throw errors.notFound('Reflection not found', 'NOT_FOUND');
    assertOwner(req, entry);
    res.json({ reflection: reflectionShape(entry), private: true });
  })
);

router.patch(
  '/reflections/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({
      entryDate: dateSchema.optional(),
      title: z.string().trim().min(1).max(200).optional(),
      body: z.string().min(1).max(20000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const entry = await prisma.reflectionEntry.findUnique({ where: { id: req.valid.params.id } });
    if (!entry) throw errors.notFound('Reflection not found', 'NOT_FOUND');
    assertOwner(req, entry);
    const b = { ...req.valid.body };
    if (b.entryDate) b.entryDate = dateFromISO(b.entryDate);
    const updated = await prisma.reflectionEntry.update({ where: { id: entry.id }, data: b });
    res.json({ reflection: reflectionShape(updated) });
  })
);

router.delete(
  '/reflections/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const entry = await prisma.reflectionEntry.findUnique({ where: { id: req.valid.params.id } });
    if (!entry) throw errors.notFound('Reflection not found', 'NOT_FOUND');
    assertOwner(req, entry);
    await prisma.reflectionEntry.delete({ where: { id: entry.id } });
    res.json({ ok: true });
  })
);

// ---------------------------------------------------------------------------
// Testimonies — visibility + consent enforced server-side
// ---------------------------------------------------------------------------

const testimonyShape = (t, { isOwner = false, isAdmin = false } = {}) => ({
  id: t.id,
  userId: isOwner || isAdmin ? t.userId : undefined,
  title: t.title,
  entryDate: isoDate(t.entryDate),
  story: t.story,
  // Flutter reads `body`; `story` is the storage name.
  body: t.story,
  tags: t.tags,
  visibility: t.visibility,
  consentToShare: t.consentToShare,
  approvalStatus: t.approvalStatus,
  publishedAt: t.publishedAt,
  createdAt: t.createdAt,
  updatedAt: t.updatedAt,
});

// The Flutter editor labels ministry sharing MINISTRY_ADMINS; the schema stores
// ADMINS. Accept both spellings and normalise to the storage enum value.
const TESTIMONY_VISIBILITY = ['PRIVATE', 'ADMINS', 'MINISTRY_ADMINS', 'COMMUNITY'];
function normaliseVisibility(value) {
  if (value === 'MINISTRY_ADMINS') return 'ADMINS';
  return value;
}

router.get(
  '/testimonies',
  validate({ query: paginationQuery }),
  asyncHandler(async (req, res) => {
    const { page, pageSize } = req.valid.query;
    const result = await paginate(prisma.testimony, {
      where: { userId: req.user.id },
      orderBy: { entryDate: 'desc' },
      page,
      pageSize,
    });
    res.json({ data: result.data.map((t) => testimonyShape(t, { isOwner: true })), meta: result.meta });
  })
);

router.post(
  '/testimonies',
  validate({
    body: z
      .object({
        title: z.string().trim().min(1).max(200),
        entryDate: dateSchema.optional(),
        story: z.string().min(1).max(20000).optional(),
        // Flutter names the testimony text `body`.
        body: z.string().min(1).max(20000).optional(),
        tags: z.array(z.string().trim().max(40)).max(10).optional(),
        visibility: z.enum(TESTIMONY_VISIBILITY).default('PRIVATE'),
        consentToShare: z.boolean().default(false),
      })
      .refine((v) => v.story || v.body, {
        message: 'Provide the testimony text (story or body)',
        path: ['body'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const story = b.story ?? b.body;
    const visibility = normaliseVisibility(b.visibility);
    // Never publish without explicit consent — community visibility requires it.
    if (visibility === 'COMMUNITY' && !b.consentToShare) {
      throw errors.badRequest(
        'Consent is required before a testimony can be shared with the community',
        'CONSENT_REQUIRED'
      );
    }
    const testimony = await prisma.testimony.create({
      data: {
        userId: req.user.id,
        title: b.title,
        entryDate: dateFromISO(b.entryDate ?? todayISO(req)),
        story,
        tags: b.tags ?? undefined,
        visibility,
        consentToShare: b.consentToShare,
        approvalStatus: visibility === 'COMMUNITY' ? 'PENDING' : 'NOT_REQUESTED',
      },
    });
    res.status(201).json({ testimony: testimonyShape(testimony, { isOwner: true }) });
  })
);

router.get(
  '/testimonies/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const t = await prisma.testimony.findUnique({ where: { id: req.valid.params.id } });
    if (!t) throw errors.notFound('Testimony not found', 'NOT_FOUND');
    assertOwner(req, t, { allowAdmin: t.visibility === 'ADMINS' || t.visibility === 'COMMUNITY' });
    res.json({ testimony: testimonyShape(t, { isOwner: t.userId === req.user.id, isAdmin: req.user.role !== 'MEMBER' }) });
  })
);

router.patch(
  '/testimonies/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({
      title: z.string().trim().min(1).max(200).optional(),
      entryDate: dateSchema.optional(),
      story: z.string().min(1).max(20000).optional(),
      body: z.string().min(1).max(20000).optional(),
      tags: z.array(z.string().trim().max(40)).max(10).optional(),
      visibility: z.enum(TESTIMONY_VISIBILITY).optional(),
      consentToShare: z.boolean().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const t = await prisma.testimony.findUnique({ where: { id: req.valid.params.id } });
    if (!t) throw errors.notFound('Testimony not found', 'NOT_FOUND');
    assertOwner(req, t);

    const b = { ...req.valid.body };
    // Flutter calls the text `body`; map it onto the storage column `story`.
    if (b.body !== undefined && b.story === undefined) b.story = b.body;
    delete b.body;
    if (b.entryDate) b.entryDate = dateFromISO(b.entryDate);
    if (b.visibility) b.visibility = normaliseVisibility(b.visibility);
    const visibility = b.visibility ?? t.visibility;
    const consent = b.consentToShare ?? t.consentToShare;
    if (visibility === 'COMMUNITY' && !consent) {
      throw errors.badRequest('Consent is required before community sharing', 'CONSENT_REQUIRED');
    }
    // Moving to community sharing requests approval again.
    if (visibility === 'COMMUNITY' && (t.visibility !== 'COMMUNITY' || t.approvalStatus === 'REJECTED')) {
      b.approvalStatus = 'PENDING';
    }
    if (visibility !== 'COMMUNITY' && t.visibility === 'COMMUNITY') {
      b.approvalStatus = 'NOT_REQUESTED';
      b.publishedAt = null;
    }

    const updated = await prisma.testimony.update({ where: { id: t.id }, data: b });
    res.json({ testimony: testimonyShape(updated, { isOwner: true }) });
  })
);

router.delete(
  '/testimonies/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const t = await prisma.testimony.findUnique({ where: { id: req.valid.params.id } });
    if (!t) throw errors.notFound('Testimony not found', 'NOT_FOUND');
    assertOwner(req, t);
    await prisma.testimony.delete({ where: { id: t.id } });
    res.json({ ok: true });
  })
);

/** Community testimonials: approved + consented only. */
router.get(
  '/testimonies-shared/community',
  asyncHandler(async (req, res) => {
    const rows = await prisma.testimony.findMany({
      where: { visibility: 'COMMUNITY', approvalStatus: 'APPROVED', consentToShare: true },
      orderBy: { publishedAt: 'desc' },
      take: 50,
      select: {
        id: true,
        title: true,
        entryDate: true,
        story: true,
        tags: true,
        publishedAt: true,
        user: { select: { id: true, firstName: true } },
      },
    });
    res.json({
      data: rows.map((r) => ({
        id: r.id,
        title: r.title,
        entryDate: isoDate(r.entryDate),
        story: r.story,
        tags: r.tags,
        publishedAt: r.publishedAt,
        authorFirstName: r.user.firstName,
      })),
    });
  })
);

// ---------------------------------------------------------------------------
// Annual letter (private by default)
// ---------------------------------------------------------------------------
//
// Two addressing styles are supported:
//   * `/annual-letter`              — the current programme (Flutter client)
//   * `/annual-letters/:programmeId` — an explicit programme year

/** The programme a convenience `/annual-letter` call should resolve to. */
async function currentLetterProgramme() {
  const programme = await latestPublishedProgramme();
  if (!programme) {
    throw errors.badRequest('No published programme is available yet', 'NO_PROGRAMME');
  }
  return programme;
}

const letterShape = (l) =>
  l
    ? {
        id: l.id,
        programmeId: l.programmeId,
        // Flutter reads `content` first, then `body`; `body` is the storage name.
        content: l.body,
        body: l.body,
        isDraft: l.isDraft,
        updatedAt: l.updatedAt,
        createdAt: l.createdAt,
      }
    : null;

/** GET /me/annual-letter — the member's letter for the current programme. */
router.get(
  '/annual-letter',
  asyncHandler(async (req, res) => {
    const programme = await currentLetterProgramme();
    const letter = await prisma.annualLetter.findUnique({
      where: { userId_programmeId: { userId: req.user.id, programmeId: programme.id } },
    });
    // Return an empty (unsaved) letter rather than 404 so the editor still opens.
    res.json(
      letterShape(letter) ?? {
        id: null,
        programmeId: programme.id,
        content: '',
        body: '',
        isDraft: true,
        updatedAt: null,
      }
    );
  })
);

/** PUT /me/annual-letter — upsert the current programme's letter. */
router.put(
  '/annual-letter',
  validate({
    body: z
      .object({
        // Flutter sends `content`; `body` is the storage-name alias.
        content: z.string().max(50000).optional(),
        body: z.string().max(50000).optional(),
        isDraft: z.boolean().optional(),
      })
      .refine((v) => v.content !== undefined || v.body !== undefined, {
        message: 'content is required',
        path: ['content'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const programme = await currentLetterProgramme();
    const value = req.valid.body.content ?? req.valid.body.body;
    const letter = await prisma.annualLetter.upsert({
      where: { userId_programmeId: { userId: req.user.id, programmeId: programme.id } },
      create: {
        userId: req.user.id,
        programmeId: programme.id,
        body: value,
        isDraft: req.valid.body.isDraft ?? true,
      },
      update: {
        body: value,
        ...(req.valid.body.isDraft !== undefined ? { isDraft: req.valid.body.isDraft } : {}),
      },
    });
    res.json(letterShape(letter));
  })
);

router.get(
  '/annual-letters/:programmeId',
  validate({ params: z.object({ programmeId: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const letter = await prisma.annualLetter.findUnique({
      where: {
        userId_programmeId: { userId: req.user.id, programmeId: req.valid.params.programmeId },
      },
    });
    res.json({ letter: letter ?? null, private: true });
  })
);

router.put(
  '/annual-letters/:programmeId',
  validate({
    params: z.object({ programmeId: uuidSchema }),
    body: z.object({
      body: z.string().max(50000),
      isDraft: z.boolean().default(true),
    }),
  }),
  asyncHandler(async (req, res) => {
    const programme = await prisma.programme.findUnique({ where: { id: req.valid.params.programmeId } });
    if (!programme) throw errors.notFound('Programme not found', 'NOT_FOUND');
    const letter = await prisma.annualLetter.upsert({
      where: {
        userId_programmeId: { userId: req.user.id, programmeId: programme.id },
      },
      create: {
        userId: req.user.id,
        programmeId: programme.id,
        body: req.valid.body.body,
        isDraft: req.valid.body.isDraft,
      },
      update: { body: req.valid.body.body, isDraft: req.valid.body.isDraft },
    });
    res.json({ letter, private: true });
  })
);

export default router;
