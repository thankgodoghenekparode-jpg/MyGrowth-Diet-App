import { Router } from 'express';
import { z } from 'zod';
import { DateTime } from 'luxon';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema } from '../../lib/validate.js';
import { dateFromISO, isoDate } from '../../lib/dates.js';
import {
  resolveProgrammeForDate,
  resolveMonthlyPlan,
  monthOf,
  yearOf,
} from '../../lib/programme.js';
import { weekOfMonth, contentAnchors } from '../../lib/dailyDiet.js';

/**
 * Member-facing Daily Diet.
 *
 * Mounted at `/api/v1/daily-diet`. A member picks a date and receives that
 * day's devotional content: the sections the administrator configured, the
 * content each section carries for that date, the materials attached to it,
 * and the member's own tick-offs.
 */
const router = Router();

const COMPLETION_STATUSES = [
  'NOT_STARTED',
  'IN_PROGRESS',
  'COMPLETED',
  'SKIPPED',
  'NOT_APPLICABLE',
];

function humanizeCategory(key) {
  if (!key) return null;
  return String(key)
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

function contentShape(c) {
  if (!c) return null;
  return {
    id: c.id,
    sectionId: c.sectionId,
    date: isoDate(c.date),
    scope: c.scope,
    title: c.title,
    body: c.body,
    details: c.details ?? null,
    materialIds: Array.isArray(c.materialIds) ? c.materialIds : [],
    externalUrl: c.externalUrl,
    durationTargetMinutes: c.durationTargetMinutes,
    status: c.status,
  };
}

function completionShape(c) {
  if (!c) return null;
  return {
    id: c.id,
    sectionId: c.sectionId,
    date: isoDate(c.date),
    status: c.status,
    note: c.note,
    actualDurationMinutes: c.actualDurationMinutes,
    actualQuantity: c.actualQuantity,
    attachmentFileId: c.attachmentFileId ?? null,
    attachment: c.attachmentFile
      ? {
          id: c.attachmentFile.id,
          originalName: c.attachmentFile.originalName,
          mimeType: c.attachmentFile.mimeType,
          sizeBytes: c.attachmentFile.sizeBytes,
          url: `/api/v1/files/${c.attachmentFile.id}`,
        }
      : null,
    completedAt: c.completedAt,
  };
}

function materialShape(m) {
  if (!m) return null;
  return {
    id: m.id,
    title: m.title,
    description: m.description,
    category: m.category,
    author: m.authorSpeaker,
    externalUrl: m.externalUrl,
    fileId: m.fileId,
    fileType: m.file?.mimeType ?? null,
    fileName: m.file?.originalName ?? null,
    sizeBytes: m.file?.sizeBytes ?? null,
    url: m.fileId ? `/api/v1/files/${m.fileId}` : null,
    month: m.month,
    year: m.programmeYear,
  };
}

/** Find the weekly plan that covers a date (date range first, then week number). */
async function resolveWeeklyPlan(programmeId, monthlyPlan, dateISO) {
  if (!programmeId) return null;
  const date = dateFromISO(dateISO);
  const ranged = await prisma.weeklyPlan.findFirst({
    where: {
      programmeId,
      status: 'PUBLISHED',
      startDate: { lte: date },
      endDate: { gte: date },
    },
    orderBy: { weekNumber: 'asc' },
  });
  if (ranged) return ranged;
  if (!monthlyPlan) return null;
  return prisma.weeklyPlan.findFirst({
    where: {
      programmeId,
      monthlyPlanId: monthlyPlan.id,
      weekNumber: weekOfMonth(dateISO),
      status: 'PUBLISHED',
    },
    orderBy: { weekNumber: 'asc' },
  });
}

/**
 * GET /api/v1/daily-diet?date=YYYY-MM-DD
 *
 * The whole day in one call: the configured sections, each section's content
 * for that date, the materials attached to it and the member's tick-offs.
 */
router.get(
  '/',
  validate({ query: z.object({ date: dateSchema.optional() }) }),
  asyncHandler(async (req, res) => {
    const tzName = req.user.timezone || 'Africa/Lagos';
    const dateISO =
      req.valid.query.date ||
      DateTime.now().setZone(tzName).toFormat('yyyy-MM-dd');
    const date = dateFromISO(dateISO);

    const { programme, dateInProgramme } = await resolveProgrammeForDate(dateISO);
    if (!programme) {
      return res.json({
        date: dateISO,
        dateInProgramme: false,
        programme: null,
        monthlyPlan: null,
        weeklyPlan: null,
        sections: [],
        progress: { completed: 0, total: 0, ratio: 0 },
      });
    }

    const month = monthOf(dateISO);
    const year = yearOf(dateISO);
    const monthlyPlan = await resolveMonthlyPlan(programme.id, month, year);
    const weeklyPlan = await resolveWeeklyPlan(programme.id, monthlyPlan, dateISO);

    const sections = await prisma.dailyDietSection.findMany({
      where: { programmeId: programme.id, enabled: true, status: 'PUBLISHED' },
      orderBy: [{ sortOrder: 'asc' }, { key: 'asc' }],
    });

    const sectionIds = sections.map((s) => s.id);

    // Content can be written for the day, the week or the month. Load every
    // anchor that could apply, then let the closest scope win per section.
    const anchors = contentAnchors(dateISO);
    const anchorDates = anchors.map((a) => dateFromISO(a.date));

    const [contents, completions] = await Promise.all([
      sectionIds.length
        ? prisma.dailyDietContent.findMany({
            where: {
              sectionId: { in: sectionIds },
              date: { in: anchorDates },
              status: 'PUBLISHED',
            },
            orderBy: { sortOrder: 'asc' },
          })
        : Promise.resolve([]),
      sectionIds.length
        ? prisma.dailyDietCompletion.findMany({
            where: {
              userId: req.user.id,
              sectionId: { in: sectionIds },
              date,
            },
            include: { attachmentFile: true },
          })
        : Promise.resolve([]),
    ]);

    // Resolve every material referenced by the day's content in one query.
    const referencedIds = [
      ...new Set(
        contents.flatMap((c) =>
          Array.isArray(c.materialIds) ? c.materialIds : []
        )
      ),
    ];
    const materials = referencedIds.length
      ? await prisma.material.findMany({
          where: {
            id: { in: referencedIds },
            status: 'PUBLISHED',
            visibility: 'ALL_MEMBERS',
          },
          include: { file: true },
        })
      : [];
    const materialById = new Map(materials.map((m) => [m.id, m]));

    const contentBySection = new Map();
    for (const anchor of anchors) {
      for (const c of contents) {
        if (isoDate(c.date) !== anchor.date) continue;
        if (c.scope !== anchor.scope) continue;
        // The anchors are ordered DAY → WEEK → MONTH, so the first match wins.
        if (!contentBySection.has(c.sectionId)) {
          contentBySection.set(c.sectionId, c);
        }
      }
    }
    const completionBySection = new Map(
      completions.map((c) => [c.sectionId, c])
    );

    let completed = 0;
    const shapedSections = sections.map((s) => {
      const content = contentBySection.get(s.id) ?? null;
      const completion = completionBySection.get(s.id) ?? null;
      const isDone = completion?.status === 'COMPLETED';
      if (isDone) completed += 1;

      const ids = Array.isArray(content?.materialIds) ? content.materialIds : [];
      const attached = ids
        .map((id) => materialById.get(id))
        .filter(Boolean)
        .map(materialShape);

      return {
        id: s.id,
        key: s.key,
        label: s.label,
        description: s.description,
        behaviour: s.behaviour,
        sortOrder: s.sortOrder,
        required: s.required,
        allowNote: s.allowNote,
        trackCompletion: s.trackCompletion,
        // Flutter alias: the section behaves like the matching activity category.
        categoryKey: s.key,
        categoryLabel: humanizeCategory(s.key),
        content: contentShape(content),
        materials: attached,
        completion: completionShape(completion),
        status: completion?.status ?? 'NOT_STARTED',
        isCompleted: isDone,
      };
    });

    res.json({
      date: dateISO,
      dateInProgramme,
      programme: {
        id: programme.id,
        title: programme.title,
        year: programme.year,
        ministry: programme.ministry,
        annualPrayerFocus: programme.annualPrayerFocus,
        dailyAffirmation: programme.dailyAffirmation,
        startDate: programme.startDate ? isoDate(programme.startDate) : null,
        endDate: programme.endDate ? isoDate(programme.endDate) : null,
      },
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
            literatureList: monthlyPlan.literatureList ?? null,
            audioMessages: monthlyPlan.audioMessages ?? null,
            reflectionQuestions: monthlyPlan.reflectionQuestions ?? null,
          }
        : null,
      weeklyPlan: weeklyPlan
        ? {
            id: weeklyPlan.id,
            weekNumber: weeklyPlan.weekNumber,
            startDate: weeklyPlan.startDate ? isoDate(weeklyPlan.startDate) : null,
            endDate: weeklyPlan.endDate ? isoDate(weeklyPlan.endDate) : null,
            bibleReading: weeklyPlan.bibleReading,
            prayerDurationTargetMinutes: weeklyPlan.prayerDurationTargetMinutes,
            fastingSchedule: weeklyPlan.fastingSchedule,
            keyLessonPrompt: weeklyPlan.keyLessonPrompt,
            memoryVerse: weeklyPlan.memoryVerse,
          }
        : null,
      sections: shapedSections,
      progress: {
        completed,
        total: shapedSections.length,
        ratio: shapedSections.length ? completed / shapedSections.length : 0,
      },
    });
  })
);

// ---------------------------------------------------------------------------
// Tick-offs
// ---------------------------------------------------------------------------

const completionBody = z
  .object({
    sectionId: uuidSchema.optional(),
    sectionKey: z.string().trim().min(1).max(60).optional(),
    date: dateSchema,
    status: z.enum(COMPLETION_STATUSES).default('COMPLETED'),
    note: z.string().max(4000).nullable().optional(),
    actualDurationMinutes: z.coerce
      .number()
      .int()
      .min(0)
      .max(24 * 60)
      .nullable()
      .optional(),
    actualQuantity: z.coerce.number().int().min(0).max(100000).nullable().optional(),
    attachmentFileId: uuidSchema.nullable().optional(),
  })
  .refine((v) => v.sectionId || v.sectionKey, {
    message: 'Provide either sectionId or sectionKey',
  });

/**
 * POST /api/v1/daily-diet/completions — record (or update) a member's
 * tick-off for one section on one day.
 */
router.post(
  '/completions',
  validate({ body: completionBody }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const date = dateFromISO(b.date);

    let section = null;
    if (b.sectionId) {
      section = await prisma.dailyDietSection.findUnique({
        where: { id: b.sectionId },
      });
    } else {
      section = await prisma.dailyDietSection.findFirst({
        where: { key: b.sectionKey, enabled: true, status: 'PUBLISHED' },
        orderBy: { createdAt: 'desc' },
      });
    }
    if (!section) throw errors.notFound('Daily Diet section not found', 'NOT_FOUND');

    if (b.attachmentFileId) {
      const file = await prisma.file.findUnique({ where: { id: b.attachmentFileId } });
      if (!file) throw errors.badRequest('attachmentFileId does not exist', 'VALIDATION_ERROR');
      if (file.uploadedById !== req.user.id) {
        throw errors.forbidden('You can only attach files you uploaded', 'FILE_ACCESS_DENIED');
      }
    }

    const data = {
      status: b.status,
      note: b.note ?? null,
      actualDurationMinutes: b.actualDurationMinutes ?? null,
      actualQuantity: b.actualQuantity ?? null,
      attachmentFileId: b.attachmentFileId ?? null,
      completedAt: b.status === 'COMPLETED' ? new Date() : null,
    };

    const completion = await prisma.dailyDietCompletion.upsert({
      where: {
        userId_sectionId_date: {
          userId: req.user.id,
          sectionId: section.id,
          date,
        },
      },
      create: {
        userId: req.user.id,
        sectionId: section.id,
        date,
        ...data,
      },
      update: data,
      include: { attachmentFile: true },
    });

    res.status(201).json({ completion: completionShape(completion) });
  })
);

/**
 * GET /api/v1/daily-diet/progress?from=&to= — per-date completion counts for
 * the member (used for streaks and the calendar view).
 */
router.get(
  '/progress',
  validate({
    query: z
      .object({
        from: dateSchema.optional(),
        to: dateSchema.optional(),
      })
      .refine((q) => !q.from || !q.to || q.from <= q.to, {
        message: 'from must be on or before to',
      }),
  }),
  asyncHandler(async (req, res) => {
    const { from, to } = req.valid.query;
    const where = { userId: req.user.id };
    if (from && to) {
      where.date = { gte: dateFromISO(from), lte: dateFromISO(to) };
    }

    const [rows, sectionCount] = await Promise.all([
      prisma.dailyDietCompletion.findMany({
        where,
        select: { date: true, status: true },
      }),
      prisma.dailyDietSection.count({ where: { enabled: true, status: 'PUBLISHED' } }),
    ]);

    const byDate = new Map();
    for (const r of rows) {
      const key = isoDate(r.date);
      const entry = byDate.get(key) ?? { date: key, completed: 0, recorded: 0 };
      entry.recorded += 1;
      if (r.status === 'COMPLETED') entry.completed += 1;
      byDate.set(key, entry);
    }

    res.json({
      data: [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date)),
      meta: { totalSections: sectionCount },
    });
  })
);

/**
 * DELETE /api/v1/daily-diet/completions/:id — clear a tick-off.
 */
router.delete(
  '/completions/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const completion = await prisma.dailyDietCompletion.findUnique({
      where: { id: req.valid.params.id },
    });
    if (!completion) throw errors.notFound('Completion not found', 'NOT_FOUND');
    if (completion.userId !== req.user.id) {
      throw errors.forbidden('You can only change your own tick-offs', 'FORBIDDEN');
    }
    await prisma.dailyDietCompletion.delete({ where: { id: completion.id } });
    res.json({ ok: true });
  })
);

export default router;
