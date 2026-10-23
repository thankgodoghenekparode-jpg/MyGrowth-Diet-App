import prisma from '../db/index.js';
import { notify } from '../services/notifications.js';
import { DateTime } from 'luxon';
import {
  weekKey,
  monthKey,
  previousQuarterKey,
  isValidTimeRange,
} from '../lib/dates.js';
import { logger } from '../lib/logger.js';

const DEFAULT_TZ = 'Africa/Lagos';

function hhmmToMinutes(hhmm) {
  const [h, m] = String(hhmm).split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
}

function inQuietHours(pref, minutesNow) {
  if (!pref?.quietHoursStart || !pref?.quietHoursEnd) return false;
  const start = hhmmToMinutes(pref.quietHoursStart);
  const end = hhmmToMinutes(pref.quietHoursEnd);
  if (start === end) return false;
  return start < end ? minutesNow >= start && minutesNow < end : minutesNow >= start || minutesNow < end;
}

async function prefFor(userId, cache) {
  if (cache.has(userId)) return cache.get(userId);
  let pref = await prisma.notificationPreference.findUnique({ where: { userId } });
  if (!pref) pref = await prisma.notificationPreference.create({ data: { userId } });
  cache.set(userId, pref);
  return pref;
}

/**
 * Daily activity reminders — one per user per local calendar day, at/after the
 * user's configured reminder time. Deduplicated by the unique
 * (userId, eventType, eventKey) constraint, so repeated ticks are safe.
 */
export async function dailyActivityReminders(now = DateTime.now()) {
  const users = await prisma.user.findMany({
    where: { status: 'ACTIVE', role: { in: ['MEMBER', 'ADMIN', 'MAIN_ADMIN'] } },
    select: { id: true, timezone: true },
  });
  const cache = new Map();
  let created = 0;

  for (const user of users) {
    const local = now.setZone(user.timezone || DEFAULT_TZ);
    const minutesNow = local.hour * 60 + local.minute;
    const pref = await prefFor(user.id, cache);
    if (!pref.dailyReminderEnabled || !pref.inAppEnabled) continue;
    if (minutesNow < hhmmToMinutes(pref.dailyReminderTime)) continue;
    if (inQuietHours(pref, minutesNow)) continue;

    const eventKey = local.toFormat('yyyy-MM-dd');
    const n = await notify({
      userId: user.id,
      eventType: 'daily_activity_reminder',
      eventKey,
      title: "Today's growth diet",
      body: 'Open your daily checklist and record your prayer, Word and study activities for today.',
      data: { date: eventKey },
    });
    if (n) created += 1;
  }
  return created;
}

/** Weekly report reminder — Sundays at/after 17:00 local, if no report yet. */
export async function weeklyReportReminders(now = DateTime.now()) {
  const users = await prisma.user.findMany({
    where: { status: 'ACTIVE', role: 'MEMBER' },
    select: { id: true, timezone: true },
  });
  const cache = new Map();
  let created = 0;

  for (const user of users) {
    const local = now.setZone(user.timezone || DEFAULT_TZ);
    if (local.weekday !== 7) continue; // Sunday
    const minutesNow = local.hour * 60 + local.minute;
    if (minutesNow < 17 * 60) continue;
    const pref = await prefFor(user.id, cache);
    if (!pref.weeklyReminderEnabled || !pref.inAppEnabled) continue;
    if (inQuietHours(pref, minutesNow)) continue;

    const key = weekKey(local.toFormat('yyyy-MM-dd'), user.timezone || DEFAULT_TZ);
    const existing = await prisma.report.findFirst({
      where: { userId: user.id, periodType: 'WEEK', periodKey: key, reportType: 'WEEKLY' },
      select: { status: true },
    });
    if (existing && existing.status !== 'DRAFT') continue;

    const n = await notify({
      userId: user.id,
      eventType: 'weekly_report_reminder',
      eventKey: key,
      title: 'Weekly accountability report',
      body: 'Your weekly report is due. Draft it now and submit before the week closes.',
      data: { periodKey: key },
    });
    if (n) created += 1;
  }
  return created;
}

/** Monthly report reminder — last day of month at/after 17:00 local. */
export async function monthlyReportReminders(now = DateTime.now()) {
  const users = await prisma.user.findMany({
    where: { status: 'ACTIVE', role: 'MEMBER' },
    select: { id: true, timezone: true },
  });
  const cache = new Map();
  let created = 0;

  for (const user of users) {
    const local = now.setZone(user.timezone || DEFAULT_TZ);
    if (local.day !== local.daysInMonth) continue;
    const minutesNow = local.hour * 60 + local.minute;
    if (minutesNow < 17 * 60) continue;
    const pref = await prefFor(user.id, cache);
    if (!pref.monthlyReminderEnabled || !pref.inAppEnabled) continue;
    if (inQuietHours(pref, minutesNow)) continue;

    const key = monthKey(local.toFormat('yyyy-MM-dd'), user.timezone || DEFAULT_TZ);
    const existing = await prisma.report.findFirst({
      where: { userId: user.id, periodType: 'MONTH', periodKey: key, reportType: 'MONTHLY' },
      select: { status: true },
    });
    if (existing && existing.status !== 'DRAFT') continue;

    const n = await notify({
      userId: user.id,
      eventType: 'monthly_report_reminder',
      eventKey: key,
      title: 'Monthly accountability report',
      body: 'The month is closing. Complete and submit your monthly report.',
      data: { periodKey: key },
    });
    if (n) created += 1;
  }
  return created;
}

/** Quarterly review reminder — first day of Jan/Apr/Jul/Oct at 09:00 local. */
export async function quarterlyReviewReminders(now = DateTime.now()) {
  const users = await prisma.user.findMany({
    where: { status: 'ACTIVE', role: 'MEMBER' },
    select: { id: true, timezone: true },
  });
  const cache = new Map();
  let created = 0;

  for (const user of users) {
    const local = now.setZone(user.timezone || DEFAULT_TZ);
    if (![1, 4, 7, 10].includes(local.month) || local.day !== 1) continue;
    if (local.hour < 9) continue;
    const pref = await prefFor(user.id, cache);
    if (!pref.quarterlyReminderEnabled || !pref.inAppEnabled) continue;

    const prevKey = previousQuarterKey(local.toFormat('yyyy-MM-dd'), user.timezone || DEFAULT_TZ);
    const existing = await prisma.report.findFirst({
      where: { userId: user.id, periodType: 'QUARTER', periodKey: prevKey, reportType: 'QUARTERLY' },
      select: { status: true },
    });
    if (existing && existing.status !== 'DRAFT') continue;

    const n = await notify({
      userId: user.id,
      eventType: 'quarterly_review_reminder',
      eventKey: prevKey,
      title: 'Quarterly review',
      body: 'A new quarter has begun — complete your quarterly review of Bible reading, prayer life, stewardship, service, relationships and character growth.',
      data: { periodKey: prevKey },
    });
    if (n) created += 1;
  }
  return created;
}

/** Annual reflection reminder — 26 December at 09:00 local. */
export async function annualReflectionReminders(now = DateTime.now()) {
  const users = await prisma.user.findMany({
    where: { status: 'ACTIVE', role: 'MEMBER' },
    select: { id: true, timezone: true },
  });
  const cache = new Map();
  let created = 0;

  for (const user of users) {
    const local = now.setZone(user.timezone || DEFAULT_TZ);
    if (local.month !== 12 || local.day !== 26 || local.hour < 9) continue;
    const pref = await prefFor(user.id, cache);
    if (!pref.annualReminderEnabled || !pref.inAppEnabled) continue;

    const year = String(local.year);
    const existing = await prisma.report.findFirst({
      where: { userId: user.id, periodType: 'YEAR', periodKey: year, reportType: 'ANNUAL' },
      select: { status: true },
    });
    if (existing && existing.status !== 'DRAFT') continue;

    const n = await notify({
      userId: user.id,
      eventType: 'annual_reflection_reminder',
      eventKey: year,
      title: 'Annual reflection',
      body: 'Write your annual reflection and letter to yourself for the coming year.',
      data: { periodKey: year },
    });
    if (n) created += 1;
  }
  return created;
}

/**
 * Upcoming prayer session reminders — accepted sessions starting within the
 * next 60 minutes (in the session's timezone), one reminder per session.
 */
export async function prayerSessionReminders(now = DateTime.now()) {
  const inOneHour = now.plus({ hours: 1 });
  const candidates = await prisma.prayerSession.findMany({
    where: { status: { in: ['ACCEPTED'] }, date: { gte: now.minus({ days: 1 }).toJSDate() } },
    select: {
      id: true,
      date: true,
      startTime: true,
      durationMinutes: true,
      timezone: true,
      partnership: { select: { userAId: true, userBId: true } },
    },
  });

  let created = 0;
  for (const s of candidates) {
    const zone = s.timezone || DEFAULT_TZ;
    const dateStr = DateTime.fromJSDate(s.date, { zone: 'utc' }).toFormat('yyyy-MM-dd');
    const start = DateTime.fromISO(`${dateStr}T${s.startTime}`, { zone });
    if (!start.isValid) continue;
    const end = start.plus({ minutes: s.durationMinutes });
    if (now >= end || start > inOneHour) continue;

    const cache = new Map();
    for (const userId of [s.partnership.userAId, s.partnership.userBId]) {
      const pref = await prefFor(userId, cache);
      if (!pref.inAppEnabled) continue;
      const n = await notify({
        userId,
        eventType: 'session_upcoming',
        eventKey: `session:${s.id}`,
        title: 'Upcoming prayer session',
        body: `Your prayer session starts ${dateStr} at ${s.startTime} (${zone}).`,
        data: { sessionId: s.id },
      });
      if (n) created += 1;
    }
  }
  return created;
}

/** Housekeeping: remove expired/revoked refresh tokens older than 7 days. */
export async function cleanupExpiredTokens() {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const result = await prisma.refreshToken.deleteMany({
    where: { OR: [{ expiresAt: { lt: new Date() } }, { revokedAt: { lt: cutoff } }] },
  });
  return result.count;
}

/** Run every reminder task. Safe to run concurrently thanks to dedup keys. */
export async function runAllReminderTasks(now = DateTime.now()) {
  const results = {};
  const tasks = {
    dailyActivityReminders,
    weeklyReportReminders,
    monthlyReportReminders,
    quarterlyReviewReminders,
    annualReflectionReminders,
    prayerSessionReminders,
  };
  for (const [name, fn] of Object.entries(tasks)) {
    try {
      results[name] = await fn(now);
    } catch (err) {
      logger.error(`task ${name} failed`, err?.message);
      results[name] = `error: ${err?.message}`;
    }
  }
  try {
    results.cleanupExpiredTokens = await cleanupExpiredTokens();
  } catch (err) {
    logger.error('task cleanupExpiredTokens failed', err?.message);
    results.cleanupExpiredTokens = `error: ${err?.message}`;
  }
  return results;
}

export { isValidTimeRange };
