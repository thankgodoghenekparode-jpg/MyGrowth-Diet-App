import prisma from '../db/index.js';
import { logger } from './logger.js';

/**
 * Append an audit log entry. Never throws — auditing must not break requests.
 * Never pass passwords, tokens or private reflection/report text in `details`.
 */
export async function audit({
  actor = null,
  actorId = null,
  actorRole = null,
  actorEmail = null,
  action,
  targetType,
  targetId = null,
  outcome = 'SUCCESS',
  details = null,
  req = null,
} = {}) {
  try {
    const a = actor || null;
    await prisma.auditLog.create({
      data: {
        actorId: actorId ?? a?.id ?? null,
        actorRole: actorRole ?? a?.role ?? null,
        actorEmail: actorEmail ?? a?.email ?? null,
        targetType,
        targetId: targetId ? String(targetId) : null,
        action,
        outcome,
        details: details && Object.keys(details).length ? details : undefined,
        ipAddress: req ? clientIp(req) : null,
        userAgent: req ? (req.get('user-agent') || null)?.slice(0, 300) : null,
      },
    });
  } catch (err) {
    logger.error('audit log write failed', err?.message);
  }
}

export function clientIp(req) {
  const fwd = req.get('x-forwarded-for');
  if (fwd) return fwd.split(',')[0].trim();
  return req.ip || req.socket?.remoteAddress || null;
}
