import { z } from 'zod';
import prisma from '../../db/index.js';
import config from '../../config/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, emailSchema, passwordSchema } from '../../lib/validate.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  sha256,
  randomToken,
  ACCESS_TOKEN_TTL_SECONDS,
} from '../../lib/jwt.js';
import { audit } from '../../lib/audit.js';
import { getSetting } from '../../lib/settings.js';
import { sendEmail, verificationEmail, passwordResetEmail } from '../../services/email/index.js';
import { notify } from '../../services/notifications.js';

export function publicUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    // Aliases the Flutter client reads directly (AppUser.fromJson).
    name: [user.firstName, user.lastName].filter(Boolean).join(' ').trim(),
    timeZone: user.timezone,
    adminAccessActive: user.adminAccess === 'ACTIVE',
    phone: user.phone,
    role: user.role,
    status: user.status,
    adminAccess: user.adminAccess,
    emailVerified: Boolean(user.emailVerifiedAt),
    timezone: user.timezone,
    locale: user.locale,
    avatarFileId: user.avatarFileId,
    profileCompleted: Boolean(user.profileCompletedAt),
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt,
  };
}

function refreshCookieOptions() {
  return {
    httpOnly: true,
    secure: config.isProd,
    sameSite: 'lax',
    path: '/api/v1/auth',
    maxAge: config.jwt.refreshTtlDays * 24 * 60 * 60 * 1000,
  };
}

async function issueTokens(res, user, req) {
  const tokenRow = await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: 'pending',
      expiresAt: new Date(Date.now() + config.jwt.refreshTtlDays * 24 * 60 * 60 * 1000),
      userAgent: req?.get('user-agent')?.slice(0, 300) || null,
      ipAddress: req?.ip || null,
    },
  });
  const raw = signRefreshToken(user, tokenRow.id);
  await prisma.refreshToken.update({
    where: { id: tokenRow.id },
    data: { tokenHash: sha256(raw) },
  });
  res.cookie(config.refreshCookieName, raw, refreshCookieOptions());
  return { accessToken: signAccessToken(user), refreshToken: raw, expiresIn: ACCESS_TOKEN_TTL_SECONDS };
}

async function revokeAllRefreshTokens(userId) {
  await prisma.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

// ---------------------------------------------------------------------------
// Register
// ---------------------------------------------------------------------------

// The Flutter client sends a single `name`; legacy/admin clients may still
// send `firstName` + `lastName`. Either is accepted; `name` is split on
// whitespace. Public registration remains MEMBER-only (checked in the handler).
const registerSchema = z
  .object({
    name: z.string().trim().min(1).max(160).optional(),
    firstName: z.string().trim().min(1).max(80).optional(),
    lastName: z.string().trim().min(1).max(80).optional(),
    email: emailSchema,
    password: passwordSchema,
    phone: z.string().trim().max(40).optional(),
    timezone: z.string().trim().max(60).optional(),
    timeZone: z.string().trim().max(60).optional(),
  })
  .refine((v) => Boolean(v.name) || Boolean(v.firstName && v.lastName), {
    message: 'Provide name, or firstName and lastName',
    path: ['name'],
  });

export const register = [
  validate({ body: registerSchema }),
  asyncHandler(async (req, res) => {
    // Public registration NEVER assigns an administrative role. A client that
    // tries to send one is denied and audited as a privilege-escalation attempt.
    const requestedRole = req.body?.role;
    if (requestedRole && requestedRole !== 'MEMBER') {
      await audit({
        action: 'privilege_escalation_attempt',
        targetType: 'user',
        targetId: null,
        outcome: 'DENIED',
        details: { via: 'register', requestedRole: String(requestedRole) },
        req,
      });
      throw errors.forbidden('Public registration always creates a Member account', 'ROLE_NOT_ASSIGNABLE');
    }

    const body = req.valid.body;

    // Accept either a single `name` ("Grace Member") or firstName/lastName.
    let firstName = body.firstName;
    let lastName = body.lastName;
    if ((!firstName || !lastName) && body.name) {
      const parts = body.name.trim().split(/\s+/);
      firstName = firstName || parts[0];
      lastName = lastName || (parts.length > 1 ? parts.slice(1).join(' ') : parts[0]);
    }

    const existing = await prisma.user.findUnique({ where: { email: body.email } });
    if (existing) {
      throw errors.conflict('An account with this email already exists', 'EMAIL_TAKEN');
    }

    const approvalRequired = await getSetting('registration.approvalRequired');
    const passwordHash = await hashPassword(body.password);
    const verificationToken = randomToken();

    const user = await prisma.user.create({
      data: {
        firstName,
        lastName,
        email: body.email,
        passwordHash,
        phone: body.phone ?? null,
        timezone: body.timezone || body.timeZone || 'Africa/Lagos',
        role: 'MEMBER', // always MEMBER — never from client input
        status: approvalRequired ? 'PENDING' : 'ACTIVE',
        adminAccess: 'NONE',
        verificationTokenHash: sha256(verificationToken),
        verificationTokenExpiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
    });

    const verifyLink = `${config.appBaseUrl}/verify-email?token=${verificationToken}`;
    await sendEmail(verificationEmail(user.email, verifyLink));
    await notify({
      userId: user.id,
      eventType: 'welcome_verification',
      eventKey: 'registration',
      title: 'Welcome',
      body: 'Please verify your email address to secure your account.',
    });

    const tokens = await issueTokens(res, user, req);
    res.status(201).json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      user: publicUser(user),
    });
  }),
];

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(72),
});

export const login = [
  validate({ body: loginSchema }),
  asyncHandler(async (req, res) => {
    const { email, password } = req.valid.body;
    const user = await prisma.user.findUnique({ where: { email } });

    const genericFailure = () =>
      errors.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');

    if (!user) {
      await audit({ action: 'login_failed', targetType: 'user', targetId: null, outcome: 'DENIED', details: { email: '(unknown)' }, req });
      throw genericFailure();
    }

    const ok = await verifyPassword(password, user.passwordHash);
    if (!ok) {
      await audit({ actor: user, action: 'login_failed', targetType: 'user', targetId: user.id, outcome: 'DENIED', req });
      throw genericFailure();
    }

    if (user.status === 'SUSPENDED' || user.status === 'DEACTIVATED') {
      await audit({ actor: user, action: 'login_blocked_suspended', targetType: 'user', targetId: user.id, outcome: 'DENIED', req });
      throw errors.forbidden('This account has been suspended. Contact the ministry administrator.', 'ACCOUNT_SUSPENDED');
    }

    // Admin accounts have no access until the Main Admin grants it.
    if (user.role !== 'MEMBER' && user.adminAccess !== 'ACTIVE') {
      await audit({ actor: user, action: 'login_blocked_admin_access', targetType: 'user', targetId: user.id, outcome: 'DENIED', details: { adminAccess: user.adminAccess }, req });
      throw errors.forbidden(
        user.adminAccess === 'PENDING'
          ? 'Administrator access has not been granted yet. Ask the Main Admin to grant access.'
          : 'Your administrator access is not active. Contact the Main Admin.',
        'ADMIN_ACCESS_NOT_GRANTED'
      );
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    const tokens = await issueTokens(res, user, req);
    await audit({ actor: user, action: 'login', targetType: 'user', targetId: user.id, outcome: 'SUCCESS', req });

    res.json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      user: publicUser({ ...user, lastLoginAt: new Date() }),
    });
  }),
];

// ---------------------------------------------------------------------------
// Refresh (rotation, httpOnly cookie; body token accepted for native clients)
// ---------------------------------------------------------------------------

export const refresh = asyncHandler(async (req, res) => {
  const raw = req.cookies?.[config.refreshCookieName] || req.body?.refreshToken;
  if (!raw) throw errors.unauthorized('No refresh token provided', 'NO_REFRESH_TOKEN');

  let payload;
  try {
    payload = verifyRefreshToken(raw);
  } catch {
    throw errors.unauthorized('Invalid or expired refresh token', 'INVALID_REFRESH_TOKEN');
  }
  if (payload.typ !== 'refresh') throw errors.unauthorized('Invalid token type', 'INVALID_REFRESH_TOKEN');

  const hash = sha256(raw);
  const stored = await prisma.refreshToken.findUnique({ where: { tokenHash: hash } });

  if (!stored || stored.userId !== payload.sub) {
    // Valid signature but unknown token: possible token theft/reuse — kill the session family.
    if (payload.sub) await revokeAllRefreshTokens(payload.sub);
    clearCookie(res);
    throw errors.unauthorized('Refresh token is no longer valid; please sign in again', 'REFRESH_REUSE_DETECTED');
  }
  if (stored.revokedAt) {
    await revokeAllRefreshTokens(stored.userId);
    clearCookie(res);
    throw errors.unauthorized('Refresh token has already been used; please sign in again', 'REFRESH_REUSE_DETECTED');
  }
  if (stored.expiresAt < new Date()) {
    clearCookie(res);
    throw errors.unauthorized('Refresh token expired', 'REFRESH_TOKEN_EXPIRED');
  }

  const user = await prisma.user.findUnique({ where: { id: stored.userId } });
  if (!user) {
    clearCookie(res);
    throw errors.unauthorized('Account not found', 'INVALID_REFRESH_TOKEN');
  }
  if (user.status === 'SUSPENDED' || user.status === 'DEACTIVATED') {
    await revokeAllRefreshTokens(user.id);
    clearCookie(res);
    throw errors.forbidden('This account has been suspended.', 'ACCOUNT_SUSPENDED');
  }
  if (user.role !== 'MEMBER' && user.adminAccess !== 'ACTIVE') {
    await revokeAllRefreshTokens(user.id);
    clearCookie(res);
    throw errors.forbidden('Administrator access is not active.', 'ADMIN_ACCESS_NOT_GRANTED');
  }

  // Rotation: revoke the used token, issue a fresh pair.
  const tokens = await issueTokens(res, user, req);
  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revokedAt: new Date() },
  });

  res.json({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresIn: tokens.expiresIn,
    user: publicUser(user),
  });
});

function clearCookie(res) {
  res.clearCookie(config.refreshCookieName, { path: '/api/v1/auth' });
}

// ---------------------------------------------------------------------------
// Logout
// ---------------------------------------------------------------------------

export const logout = asyncHandler(async (req, res) => {
  const raw = req.cookies?.[config.refreshCookieName] || req.body?.refreshToken;
  if (raw) {
    const stored = await prisma.refreshToken.findUnique({ where: { tokenHash: sha256(raw) } }).catch(() => null);
    if (stored && !stored.revokedAt) {
      await prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    }
  }
  if (req.user) await revokeAllRefreshTokens(req.user.id);
  clearCookie(res);
  res.json({ ok: true });
});

// ---------------------------------------------------------------------------
// Email verification
// ---------------------------------------------------------------------------

export const verifyEmail = [
  validate({ body: z.object({ token: z.string().min(10).max(200) }) }),
  asyncHandler(async (req, res) => {
    const { token } = req.valid.body;
    const hash = sha256(token);
    const user = await prisma.user.findFirst({
      where: { verificationTokenHash: hash, verificationTokenExpiresAt: { gte: new Date() } },
    });
    if (!user) throw errors.badRequest('Verification link is invalid or has expired', 'INVALID_VERIFICATION_TOKEN');
    await prisma.user.update({
      where: { id: user.id },
      data: { emailVerifiedAt: new Date(), verificationTokenHash: null, verificationTokenExpiresAt: null },
    });
    res.json({ ok: true, user: publicUser({ ...user, emailVerifiedAt: new Date() }) });
  }),
];

export const resendVerification = [
  validate({ body: z.object({ email: emailSchema }) }),
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({ where: { email: req.valid.body.email } });
    // Respond generically to avoid account enumeration.
    if (user && !user.emailVerifiedAt) {
      const token = randomToken();
      await prisma.user.update({
        where: { id: user.id },
        data: { verificationTokenHash: sha256(token), verificationTokenExpiresAt: new Date(Date.now() + 24 * 3600 * 1000) },
      });
      await sendEmail(verificationEmail(user.email, `${config.appBaseUrl}/verify-email?token=${token}`));
    }
    res.json({ ok: true, message: 'If that account needs verification, a new link has been issued.' });
  }),
];

// ---------------------------------------------------------------------------
// Password reset
// ---------------------------------------------------------------------------

export const forgotPassword = [
  validate({ body: z.object({ email: emailSchema }) }),
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({ where: { email: req.valid.body.email } });
    if (user) {
      const token = randomToken();
      await prisma.user.update({
        where: { id: user.id },
        data: {
          passwordResetTokenHash: sha256(token),
          passwordResetExpiresAt: new Date(Date.now() + 60 * 60 * 1000),
        },
      });
      await sendEmail(passwordResetEmail(user.email, `${config.appBaseUrl}/reset-password?token=${token}`));
    }
    res.json({ ok: true, message: 'If that account exists, a password reset link has been issued.' });
  }),
];

export const resetPassword = [
  validate({
    body: z
      .object({
        token: z.string().min(10).max(200),
        newPassword: passwordSchema.optional(),
        // Flutter sends `password`; `newPassword` is the legacy name.
        password: passwordSchema.optional(),
      })
      .refine((v) => v.newPassword || v.password, {
        message: 'password is required',
        path: ['password'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const { token } = req.valid.body;
    const newPassword = req.valid.body.newPassword ?? req.valid.body.password;
    const hash = sha256(token);
    const user = await prisma.user.findFirst({
      where: { passwordResetTokenHash: hash, passwordResetExpiresAt: { gte: new Date() } },
    });
    if (!user) throw errors.badRequest('Reset link is invalid or has expired', 'INVALID_RESET_TOKEN');

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: await hashPassword(newPassword),
        passwordResetTokenHash: null,
        passwordResetExpiresAt: null,
      },
    });
    await revokeAllRefreshTokens(user.id);
    await audit({ actor: user, action: 'password_reset', targetType: 'user', targetId: user.id, req });
    clearCookie(res);
    res.json({ ok: true });
  }),
];

// ---------------------------------------------------------------------------
// Change password (authenticated)
// ---------------------------------------------------------------------------

export const changePassword = [
  validate({
    body: z
      .object({
        currentPassword: z.string().min(1).max(72),
        newPassword: passwordSchema.optional(),
        password: passwordSchema.optional(),
      })
      .refine((v) => v.newPassword || v.password, {
        message: 'password is required',
        path: ['password'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const ok = await verifyPassword(req.valid.body.currentPassword, req.user.passwordHash);
    if (!ok) throw errors.badRequest('Current password is incorrect', 'INVALID_CREDENTIALS');
    const newPassword = req.valid.body.newPassword ?? req.valid.body.password;
    await prisma.user.update({
      where: { id: req.user.id },
      data: { passwordHash: await hashPassword(newPassword) },
    });
    await revokeAllRefreshTokens(req.user.id);
    res.json({ ok: true });
  }),
];

export { revokeAllRefreshTokens, issueTokens };
