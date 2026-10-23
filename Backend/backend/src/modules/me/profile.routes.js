import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate } from '../../lib/validate.js';
import { audit } from '../../lib/audit.js';
import { publicUser } from '../auth/auth.handlers.js';

const router = Router();

// GET /api/v1/me — returns a flat AppUser object (what the Flutter client
// parses), with the notification preference and prayer availability attached.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const [pref, availability] = await Promise.all([
      prisma.notificationPreference.findUnique({ where: { userId: req.user.id } }),
      prisma.prayerAvailability.findUnique({ where: { userId: req.user.id } }),
    ]);
    res.json({
      ...publicUser(req.user),
      notificationPreference: pref,
      prayerAvailability: availability,
    });
  })
);

const tzSchema = z.string().trim().max(60).refine((tz) => {
  try {
    new Intl.DateTimeFormat('en', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}, 'Unknown time zone');

const patchSchema = z.object({
  // Flutter sends a single display name; legacy clients send firstName/lastName.
  name: z.string().trim().min(1).max(160).optional(),
  firstName: z.string().trim().min(1).max(80).optional(),
  lastName: z.string().trim().min(1).max(80).optional(),
  phone: z.string().trim().max(40).nullable().optional(),
  // `timezone` (legacy) and `timeZone` (Flutter) are both accepted.
  timezone: tzSchema.optional(),
  timeZone: tzSchema.optional(),
  bio: z.string().trim().max(2000).nullable().optional(),
  locale: z.string().trim().max(10).optional(),
  avatarFileId: z.string().uuid().nullable().optional(),
});

// PATCH /api/v1/me — whitelisted profile update (no role/status mass-assignment).
router.patch(
  '/',
  validate({ body: patchSchema }),
  asyncHandler(async (req, res) => {
    // Attempting to change privileged fields is a privilege-escalation attempt.
    const attempted = ['role', 'status', 'adminAccess', 'email', 'id'].filter((k) => k in (req.body || {}));
    if (attempted.length) {
      await audit({
        actor: req.user,
        action: 'privilege_escalation_attempt',
        targetType: 'user',
        targetId: req.user.id,
        outcome: 'DENIED',
        details: { via: 'PATCH /me', fields: attempted },
        req,
      });
      throw errors.forbidden('These fields cannot be changed here', 'FIELD_NOT_EDITABLE');
    }

    const body = req.valid.body;
    if (body.avatarFileId) {
      const file = await prisma.file.findUnique({ where: { id: body.avatarFileId } });
      if (!file) throw errors.badRequest('avatarFileId does not exist', 'VALIDATION_ERROR');
    }

    // Build an explicit payload: never spread raw input into Prisma.
    const data = {};
    if (body.firstName !== undefined) data.firstName = body.firstName;
    if (body.lastName !== undefined) data.lastName = body.lastName;
    if (body.name) {
      const parts = body.name.trim().split(/\s+/);
      data.firstName = body.firstName ?? parts[0];
      data.lastName = body.lastName ?? (parts.length > 1 ? parts.slice(1).join(' ') : '');
    }
    if (body.phone !== undefined) data.phone = body.phone;
    const timeZone = body.timezone ?? body.timeZone;
    if (timeZone) data.timezone = timeZone;
    if (body.locale !== undefined) data.locale = body.locale;
    if (body.avatarFileId !== undefined) data.avatarFileId = body.avatarFileId;
    // `bio` has no column yet: accepted for contract compatibility, ignored.
    data.profileCompletedAt = req.user.profileCompletedAt ?? new Date();

    const user = await prisma.user.update({ where: { id: req.user.id }, data });
    res.json({ ...publicUser(user), avatarUrl: null, bio: null });
  })
);

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------

const prefSchema = z.object({
  emailEnabled: z.boolean().optional(),
  inAppEnabled: z.boolean().optional(),
  dailyReminderEnabled: z.boolean().optional(),
  dailyReminderTime: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:mm')
    .optional(),
  weeklyReminderEnabled: z.boolean().optional(),
  monthlyReminderEnabled: z.boolean().optional(),
  quarterlyReminderEnabled: z.boolean().optional(),
  annualReminderEnabled: z.boolean().optional(),
  // Flutter aliases.
  weeklyReportReminder: z.boolean().optional(),
  monthlyReportReminder: z.boolean().optional(),
  sessionReminders: z.boolean().optional(),
  sessionReminderMinutes: z.coerce.number().int().min(5).max(240).optional(),
  summaryPreference: z.enum(['daily', 'weekly', 'off']).optional(),
  summaryFrequency: z.enum(['DAILY', 'WEEKLY', 'OFF', 'daily', 'weekly', 'off']).optional(),
  timeZone: z.string().trim().max(60).optional(),
  quietHoursStart: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .nullable()
    .optional(),
  quietHoursEnd: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .nullable()
    .optional(),
});

function prefShape(pref, user) {
  if (!pref) return null;
  return {
    ...pref,
    weeklyReportReminder: pref.weeklyReminderEnabled,
    monthlyReportReminder: pref.monthlyReminderEnabled,
    sessionReminders: (pref.sessionReminderMinutes ?? 30) > 0,
    summaryFrequency: String(pref.summaryPreference || 'daily').toUpperCase(),
    timeZone: user?.timezone || 'Africa/Lagos',
  };
}

function prefUpdateData(body) {
  const data = {};
  if (body.emailEnabled !== undefined) data.emailEnabled = body.emailEnabled;
  if (body.inAppEnabled !== undefined) data.inAppEnabled = body.inAppEnabled;
  if (body.dailyReminderEnabled !== undefined) data.dailyReminderEnabled = body.dailyReminderEnabled;
  if (body.dailyReminderTime !== undefined) data.dailyReminderTime = body.dailyReminderTime;
  if (body.weeklyReminderEnabled !== undefined) data.weeklyReminderEnabled = body.weeklyReminderEnabled;
  if (body.monthlyReminderEnabled !== undefined) data.monthlyReminderEnabled = body.monthlyReminderEnabled;
  if (body.quarterlyReminderEnabled !== undefined) data.quarterlyReminderEnabled = body.quarterlyReminderEnabled;
  if (body.annualReminderEnabled !== undefined) data.annualReminderEnabled = body.annualReminderEnabled;
  if (body.weeklyReportReminder !== undefined) data.weeklyReminderEnabled = body.weeklyReportReminder;
  if (body.monthlyReportReminder !== undefined) data.monthlyReminderEnabled = body.monthlyReportReminder;
  if (body.sessionReminderMinutes !== undefined) data.sessionReminderMinutes = body.sessionReminderMinutes;
  const summary = body.summaryPreference ?? body.summaryFrequency;
  if (summary !== undefined) data.summaryPreference = String(summary).toLowerCase();
  if (body.quietHoursStart !== undefined) data.quietHoursStart = body.quietHoursStart;
  if (body.quietHoursEnd !== undefined) data.quietHoursEnd = body.quietHoursEnd;
  // `sessionReminders` and `timeZone` have no dedicated columns; accepted and
  // echoed, but not persisted beyond the derived/alias output.
  return data;
}

const getPreferences = asyncHandler(async (req, res) => {
  let pref = await prisma.notificationPreference.findUnique({ where: { userId: req.user.id } });
  if (!pref) pref = await prisma.notificationPreference.create({ data: { userId: req.user.id } });
  res.json(prefShape(pref, req.user));
});

const updatePreferences = asyncHandler(async (req, res) => {
  const data = prefUpdateData(req.valid.body);
  const preference = await prisma.notificationPreference.upsert({
    where: { userId: req.user.id },
    create: { userId: req.user.id, ...data },
    update: data,
  });
  res.json(prefShape(preference, req.user));
});

router.get('/notification-preferences', getPreferences);
// Flutter saves with PUT; PATCH remains for other clients.
router.put('/notification-preferences', validate({ body: prefSchema }), updatePreferences);
router.patch('/notification-preferences', validate({ body: prefSchema }), updatePreferences);

export default router;
