import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';

export const devotionsRouter = Router();
export const adminDevotionsRouter = Router();

function getDayOfYear(date = new Date()) {
  const start = new Date(date.getFullYear(), 0, 0);
  const diff = (date - start) + ((start.getTimezoneOffset() - date.getTimezoneOffset()) * 60 * 1000);
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

const completeSchema = z.object({
  isBookmarked: z.boolean().optional(),
  reflectionNotes: z.string().trim().max(3000).optional(),
});

/**
 * GET /api/v1/devotions/today
 * Returns today's daily devotion.
 */
devotionsRouter.get('/today', asyncHandler(async (req, res) => {
  const now = new Date();
  const dayOfYear = getDayOfYear(now);
  const month = now.getMonth() + 1;
  const day = now.getDate();

  let devotion = await prisma.dailyDevotion.findFirst({
    where: {
      OR: [
        { dayOfYear },
        { month, day },
      ],
    },
    include: {
      completions: {
        where: { userId: req.user.id },
      },
    },
  });

  if (!devotion) {
    // If exact day not populated, return the first available devotion or null
    devotion = await prisma.dailyDevotion.findFirst({
      orderBy: { dayOfYear: 'asc' },
      include: {
        completions: {
          where: { userId: req.user.id },
        },
      },
    });
  }

  if (!devotion) {
    return res.json({ devotion: null });
  }

  const completion = devotion.completions[0] || null;

  res.json({
    devotion: {
      id: devotion.id,
      dayOfYear: devotion.dayOfYear,
      month: devotion.month,
      day: devotion.day,
      date: devotion.date,
      title: devotion.title,
      anchorScripture: devotion.anchorScripture,
      scriptureReading: devotion.scriptureReading,
      scriptureText: devotion.scriptureText,
      content: devotion.content,
      confession: devotion.confession,
      prayer: devotion.prayer,
      oneYearBibleReading: devotion.oneYearBibleReading,
      thoughtForTheDay: devotion.thoughtForTheDay,
      author: devotion.author,
      isCompleted: Boolean(completion),
      isBookmarked: Boolean(completion?.isBookmarked),
      reflectionNotes: completion?.reflectionNotes || null,
    },
  });
}));

/**
 * GET /api/v1/devotions
 * Fetch devotion by dayOfYear or date.
 */
devotionsRouter.get('/', asyncHandler(async (req, res) => {
  let { dayOfYear, date, month, day } = req.query;

  let where = {};
  if (dayOfYear) {
    where.dayOfYear = parseInt(dayOfYear, 10);
  } else if (date) {
    const parsedDate = new Date(date);
    if (!isNaN(parsedDate.getTime())) {
      const calcDay = getDayOfYear(parsedDate);
      where.dayOfYear = calcDay;
    }
  } else if (month && day) {
    where.month = parseInt(month, 10);
    where.day = parseInt(day, 10);
  } else {
    where.dayOfYear = getDayOfYear(new Date());
  }

  let devotion = await prisma.dailyDevotion.findFirst({
    where,
    include: {
      completions: {
        where: { userId: req.user.id },
      },
    },
  });

  if (!devotion) {
    return res.json({ devotion: null });
  }

  const completion = devotion.completions[0] || null;

  res.json({
    devotion: {
      id: devotion.id,
      dayOfYear: devotion.dayOfYear,
      month: devotion.month,
      day: devotion.day,
      date: devotion.date,
      title: devotion.title,
      anchorScripture: devotion.anchorScripture,
      scriptureReading: devotion.scriptureReading,
      scriptureText: devotion.scriptureText,
      content: devotion.content,
      confession: devotion.confession,
      prayer: devotion.prayer,
      oneYearBibleReading: devotion.oneYearBibleReading,
      thoughtForTheDay: devotion.thoughtForTheDay,
      author: devotion.author,
      isCompleted: Boolean(completion),
      isBookmarked: Boolean(completion?.isBookmarked),
      reflectionNotes: completion?.reflectionNotes || null,
    },
  });
}));

/**
 * POST /api/v1/devotions/:id/complete
 * Record completion, reflection note, and bookmark status.
 */
devotionsRouter.post('/:id/complete', validate({
  params: z.object({ id: uuidSchema }),
  body: completeSchema,
}), asyncHandler(async (req, res) => {
  const devotion = await prisma.dailyDevotion.findUnique({
    where: { id: req.valid.params.id },
  });

  if (!devotion) {
    throw errors.notFound('Daily devotion not found');
  }

  const { isBookmarked, reflectionNotes } = req.valid.body;

  const completion = await prisma.dailyDevotionCompletion.upsert({
    where: {
      devotionId_userId: {
        devotionId: devotion.id,
        userId: req.user.id,
      },
    },
    create: {
      devotionId: devotion.id,
      userId: req.user.id,
      isBookmarked: isBookmarked ?? false,
      reflectionNotes: reflectionNotes ?? null,
    },
    update: {
      ...(isBookmarked !== undefined ? { isBookmarked } : {}),
      ...(reflectionNotes !== undefined ? { reflectionNotes } : {}),
    },
  });

  res.json({
    completion: {
      id: completion.id,
      isCompleted: true,
      isBookmarked: completion.isBookmarked,
      reflectionNotes: completion.reflectionNotes,
      completedAt: completion.completedAt,
    },
  });
}));

/**
 * GET /api/v1/devotions/bookmarks
 * List all bookmarks for the member.
 */
devotionsRouter.get('/user/bookmarks', asyncHandler(async (req, res) => {
  const completions = await prisma.dailyDevotionCompletion.findMany({
    where: { userId: req.user.id, isBookmarked: true },
    include: { devotion: true },
    orderBy: { completedAt: 'desc' },
  });

  res.json({
    bookmarks: completions.map((c) => ({
      ...c.devotion,
      isBookmarked: true,
      reflectionNotes: c.reflectionNotes,
      completedAt: c.completedAt,
    })),
  });
}));

// ===========================================================================
// Admin Routes: Bulk Import & Management
// ===========================================================================

const devotionItemSchema = z.object({
  dayOfYear: z.number().int().min(1).max(366),
  month: z.number().int().min(1).max(12),
  day: z.number().int().min(1).max(31),
  date: z.string().optional(),
  title: z.string().trim().min(1).max(255),
  anchorScripture: z.string().trim().min(1).max(255),
  scriptureReading: z.string().trim().max(255).optional(),
  scriptureText: z.string().trim().optional(),
  content: z.string().trim().min(1),
  confession: z.string().trim().optional(),
  prayer: z.string().trim().optional(),
  oneYearBibleReading: z.string().trim().max(255).optional(),
  thoughtForTheDay: z.string().trim().optional(),
  author: z.string().trim().max(255).optional(),
});

const bulkImportSchema = z.object({
  devotions: z.array(devotionItemSchema).min(1).max(366),
});

/**
 * POST /api/v1/admin/devotions/bulk-import
 * Ingests multiple days of devotion (up to full 365/366 days).
 */
adminDevotionsRouter.post('/bulk-import', validate({ body: bulkImportSchema }), asyncHandler(async (req, res) => {
  const { devotions } = req.valid.body;

  let upsertedCount = 0;
  for (const item of devotions) {
    await prisma.dailyDevotion.upsert({
      where: { dayOfYear: item.dayOfYear },
      create: {
        dayOfYear: item.dayOfYear,
        month: item.month,
        day: item.day,
        date: item.date ? new Date(item.date) : null,
        title: item.title,
        anchorScripture: item.anchorScripture,
        scriptureReading: item.scriptureReading || null,
        scriptureText: item.scriptureText || null,
        content: item.content,
        confession: item.confession || null,
        prayer: item.prayer || null,
        oneYearBibleReading: item.oneYearBibleReading || null,
        thoughtForTheDay: item.thoughtForTheDay || null,
        author: item.author || 'Pastor Healings E. Azuike',
      },
      update: {
        month: item.month,
        day: item.day,
        date: item.date ? new Date(item.date) : null,
        title: item.title,
        anchorScripture: item.anchorScripture,
        scriptureReading: item.scriptureReading || null,
        scriptureText: item.scriptureText || null,
        content: item.content,
        confession: item.confession || null,
        prayer: item.prayer || null,
        oneYearBibleReading: item.oneYearBibleReading || null,
        thoughtForTheDay: item.thoughtForTheDay || null,
        author: item.author || 'Pastor Healings E. Azuike',
      },
    });
    upsertedCount++;
  }

  res.json({
    message: `Successfully imported ${upsertedCount} daily devotions`,
    count: upsertedCount,
  });
}));

/**
 * GET /api/v1/admin/devotions
 * List all devotions for admin view.
 */
adminDevotionsRouter.get('/', asyncHandler(async (req, res) => {
  const devotions = await prisma.dailyDevotion.findMany({
    orderBy: { dayOfYear: 'asc' },
    select: {
      id: true,
      dayOfYear: true,
      month: true,
      day: true,
      title: true,
      anchorScripture: true,
      author: true,
      createdAt: true,
    },
  });

  res.json({ devotions, count: devotions.length });
}));
