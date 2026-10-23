import prisma from '../db/index.js';
import { errors, asyncHandler } from '../lib/errors.js';
import { verifyAccessToken } from '../lib/jwt.js';
import { audit } from '../lib/audit.js';
import { getSetting } from '../lib/settings.js';

/**
 * Authenticate the request from the Bearer access token.
 * The user row is re-read from the database on every request so role/status
 * changes (suspension, admin access revocation) take effect immediately.
 */
export const requireAuth = asyncHandler(async (req, res, next) => {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    throw errors.unauthorized('Missing access token', 'UNAUTHORIZED');
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (err) {
    const message = err?.name === 'TokenExpiredError' ? 'Access token expired' : 'Invalid access token';
    throw errors.unauthorized(message, err?.name === 'TokenExpiredError' ? 'TOKEN_EXPIRED' : 'INVALID_TOKEN');
  }
  if (payload.typ !== 'access') {
    throw errors.unauthorized('Invalid token type', 'INVALID_TOKEN');
  }

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) throw errors.unauthorized('Account not found', 'INVALID_TOKEN');
  if (user.status === 'SUSPENDED' || user.status === 'DEACTIVATED') {
    throw errors.forbidden('This account has been suspended. Contact the ministry administrator.', 'ACCOUNT_SUSPENDED');
  }

  req.user = user;
  next();
});

/**
 * Membership gate for member-facing content routes. Users created while
 * approval is required stay PENDING until an admin approves them.
 */
export const requireApprovedMember = asyncHandler(async (req, res, next) => {
  const approvalRequired = await getSetting('registration.approvalRequired');
  if (approvalRequired && req.user.status === 'PENDING') {
    throw errors.forbidden(
      'Your membership is awaiting approval by a ministry administrator.',
      'MEMBERSHIP_PENDING_APPROVAL'
    );
  }
  next();
});

/**
 * Admin gate: MAIN_ADMIN or ADMIN with granted (ACTIVE) administrative access.
 * Failed attempts by authenticated non-admins are recorded as audit entries
 * (privilege-escalation attempts).
 */
export const requireAdmin = asyncHandler(async (req, res, next) => {
  const user = req.user;
  const isAdminRole = user.role === 'ADMIN' || user.role === 'MAIN_ADMIN';
  if (!isAdminRole || user.adminAccess !== 'ACTIVE') {
    await audit({
      actor: user,
      action: 'privilege_escalation_attempt',
      targetType: 'route',
      targetId: req.originalUrl,
      outcome: 'DENIED',
      details: { required: 'admin', role: user.role, adminAccess: user.adminAccess },
      req,
    });
    throw errors.forbidden('Administrator access required', 'ADMIN_ACCESS_REQUIRED');
  }
  next();
});

/** Main-Admin-only gate. Admins attempting this are audited as escalation attempts. */
export const requireMainAdmin = asyncHandler(async (req, res, next) => {
  const user = req.user;
  if (user.role !== 'MAIN_ADMIN' || user.adminAccess !== 'ACTIVE') {
    await audit({
      actor: user,
      action: 'privilege_escalation_attempt',
      targetType: 'route',
      targetId: req.originalUrl,
      outcome: 'DENIED',
      details: { required: 'main_admin', role: user.role, adminAccess: user.adminAccess },
      req,
    });
    throw errors.forbidden('Main Admin access required', 'MAIN_ADMIN_ACCESS_REQUIRED');
  }
  next();
});

/**
 * Ownership guard for a resource loaded into the request.
 * Non-owner members are denied (and audited); admins may access as part of
 * authorised management workflows when `allowAdmin` is set.
 */
export function assertOwner(req, resource, { ownerField = 'userId', allowAdmin = false } = {}) {
  const ownerId = resource?.[ownerField];
  if (ownerId && ownerId === req.user.id) return;
  if (allowAdmin && (req.user.role === 'ADMIN' || req.user.role === 'MAIN_ADMIN') && req.user.adminAccess === 'ACTIVE') {
    return;
  }
  audit({
    actor: req.user,
    action: 'idor_attempt',
    targetType: 'resource',
    targetId: resource?.id ?? null,
    outcome: 'DENIED',
    details: { route: req.originalUrl },
    req,
  });
  throw errors.notFound('Resource not found', 'NOT_FOUND');
}
