import prisma from '../db/index.js';
import { logger } from '../lib/logger.js';
import { DateTime } from 'luxon';
import { sendEmail, notificationEmail } from './email/index.js';

/**
 * Create an in-app notification, deduplicated per (userId, eventType, eventKey)
 * via the database unique constraint. Optionally mirrors to email according to
 * the user's notification preferences and the event's default.
 */
export async function notify({
  userId,
  eventType,
  eventKey,
  title,
  body = null,
  data = null,
  forceEmail = false,
}) {
  if (!userId || !eventType || !eventKey) return null;

  let notification = null;
  try {
    notification = await prisma.notification.create({
      data: {
        userId,
        eventType,
        eventKey: String(eventKey),
        title,
        body,
        data: data ?? undefined,
      },
    });
  } catch (err) {
    if (err?.code === 'P2002') return null; // already delivered — deduplicated
    logger.error('notification create failed', err?.message);
    return null;
  }

  const wantsEmail = forceEmail || (await emailAllowed(userId, eventType));
  if (wantsEmail) {
    await deliverEmail(notification);
  }
  return notification;
}

async function emailAllowed(userId, eventType) {
  try {
    const [pref, def] = await Promise.all([
      prisma.notificationPreference.findUnique({ where: { userId } }),
      prisma.notificationEventDef.findUnique({ where: { key: eventType } }),
    ]);
    if (pref && !pref.emailEnabled) return false;
    if (def && !def.defaultEnabled) return false;
    if (pref && inQuietHours(pref)) return false;
    return Boolean(pref ? pref.emailEnabled : true);
  } catch {
    return false;
  }
}

function inQuietHours(pref) {
  if (!pref.quietHoursStart || !pref.quietHoursEnd) return false;
  const now = DateTime.now().setZone('Africa/Lagos').toFormat('HH:mm');
  return now >= pref.quietHoursStart && now < pref.quietHoursEnd;
}

async function deliverEmail(notification) {
  try {
    const user = await prisma.user.findUnique({ where: { id: notification.userId } });
    if (!user?.email) return;
    const result = await sendEmail(notificationEmail(user.email, notification.title, notification.body));
    await prisma.notification.update({
      where: { id: notification.id },
      data: result.ok
        ? { deliveryStatus: 'SENT', emailSentAt: new Date() }
        : { deliveryStatus: 'FAILED', deliveryError: (result.error || 'unknown').slice(0, 500) },
    });
  } catch (err) {
    logger.error('notification email failed', err?.message);
    await prisma.notification
      .update({
        where: { id: notification.id },
        data: { deliveryStatus: 'FAILED', deliveryError: String(err?.message || err).slice(0, 500) },
      })
      .catch(() => {});
  }
}

/** Notify every active member (used for published programmes/announcements). */
export async function notifyAllMembers({ eventType, eventKey, title, body, data, filter = {} }) {
  const users = await prisma.user.findMany({
    where: { role: 'MEMBER', status: 'ACTIVE', ...filter },
    select: { id: true },
  });
  let created = 0;
  for (const u of users) {
    const n = await notify({ userId: u.id, eventType, eventKey, title, body, data });
    if (n) created += 1;
  }
  return created;
}

export default { notify, notifyAllMembers };
