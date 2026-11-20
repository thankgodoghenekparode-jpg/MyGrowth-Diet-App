import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';

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
import {
  sendEmail,
  verificationEmail,
  verificationOtpEmail,
  passwordResetEmail,
} from '../../services/email/index.js';
import { logger } from '../../lib/logger.js';
import { notify } from '../../services/notifications.js';

/** Codes issued in tests are kept in memory so tests can complete the flow. */
export const testEmailOtps = new Map();

const OTP_TTL_MS = () => config.emailVerification.otpTtlMinutes * 60 * 1000;
const OTP_RESEND_MS = () => config.emailVerification.resendSeconds * 1000;

function generateOtp() {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function hashOtp(userId, code) {
  return createHmac('sha256', config.jwt.accessSecret)
    .update(`${userId}:${code}`)
    .digest('hex');
}

function otpMatches(user, code) {
  if (!user.emailOtpHash) return false;
  const expected = Buffer.from(user.emailOtpHash, 'hex');
  const actual = Buffer.from(hashOtp(user.id, code), 'hex');
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

async function issueEmailOtp(user) {
  const code = generateOtp();
  const sentAt = new Date();
  await prisma.user.update({
    where: { id: user.id },
    data: {
      emailOtpHash: hashOtp(user.id, code),
      emailOtpExpiresAt: new Date(sentAt.getTime() + OTP_TTL_MS()),
      emailOtpAttempts: 0,
      emailOtpSentAt: sentAt,
    },
  });
  if (!config.isProd) testEmailOtps.set(user.email, code);
  const sent = await sendEmail(
    verificationOtpEmail(user.email, code, config.emailVerification.otpTtlMinutes)
  );
  if (!sent.ok) {
    logger.warn(`[email-otp] send failed for ${user.email}: ${sent.error}`);
  }
  await audit({
    actor: user,
    action: 'email_verification_code_sent',
    targetType: 'user',
    targetId: user.id,
    outcome: sent.ok ? 'SUCCESS' : 'FAILED',
    req: null,
  });
  return { code, sent: sent.ok };
}

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
    avatarUrl: user.avatarFileId
      ? `/api/v1/avatars/${user.id}?v=${user.avatarFileId}`
      : null,
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
      },
    });

    const { code, sent } = await issueEmailOtp(user);
    await notify({
      userId: user.id,
      eventType: 'welcome_verification',
      eventKey: 'registration',
      title: 'Welcome',
      body: 'Verify your email with the code we sent to finish creating your account.',
    });

    // No session is issued until the code is verified. The dev-only code keeps
    // the local smoke script usable with the console email adapter.
    const devCode =
      config.env === 'development' && config.email.provider === 'console'
        ? { devCode: code }
        : {};
    res.status(201).json({
      user: publicUser(user),
      verification: {
        required: true,
        emailSent: sent,
        expiresInSeconds: config.emailVerification.otpTtlMinutes * 60,
        resendAfterSeconds: config.emailVerification.resendSeconds,
        ...devCode,
      },
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

    if (!user.emailVerifiedAt) {
      await audit({ actor: user, action: 'login_blocked_unverified', targetType: 'user', targetId: user.id, outcome: 'DENIED', req });
      throw errors.forbidden(
        'Verify your email with the code we sent before signing in.',
        'EMAIL_NOT_VERIFIED'
      );
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
  if (!user.emailVerifiedAt) {
    await revokeAllRefreshTokens(user.id);
    clearCookie(res);
    throw errors.forbidden('Verify your email before continuing.', 'EMAIL_NOT_VERIFIED');
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
      data: {
        emailVerifiedAt: new Date(),
        verificationTokenHash: null,
        verificationTokenExpiresAt: null,
        emailOtpHash: null,
        emailOtpExpiresAt: null,
        emailOtpAttempts: 0,
        emailOtpSentAt: null,
      },
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

/**
 * OTP verification. Issuing no session until this succeeds is what makes email
 * verification mandatory rather than cosmetic.
 */
export const verifyEmailOtp = [
  validate({
    body: z.object({
      email: emailSchema,
      code: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code'),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { email, code } = req.valid.body;
    const user = await prisma.user.findUnique({ where: { email } });
    const invalid = () =>
      errors.badRequest('That code is invalid or has expired.', 'INVALID_VERIFICATION_CODE');

    if (!user || user.emailVerifiedAt) throw invalid();
    if (user.emailOtpAttempts >= config.emailVerification.maxAttempts) {
      throw errors.badRequest(
        'Too many incorrect codes. Request a new verification code.',
        'VERIFICATION_ATTEMPTS_EXCEEDED'
      );
    }
    const expired = !user.emailOtpExpiresAt || user.emailOtpExpiresAt <= new Date();
    if (expired || !otpMatches(user, code)) {
      const attempts = user.emailOtpAttempts + 1;
      await prisma.user.update({
        where: { id: user.id },
        data: { emailOtpAttempts: attempts },
      });
      if (attempts >= config.emailVerification.maxAttempts) {
        throw errors.badRequest(
          'Too many incorrect codes. Request a new verification code.',
          'VERIFICATION_ATTEMPTS_EXCEEDED'
        );
      }
      throw invalid();
    }

    const verifiedAt = new Date();
    const verified = await prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerifiedAt: verifiedAt,
        verificationTokenHash: null,
        verificationTokenExpiresAt: null,
        emailOtpHash: null,
        emailOtpExpiresAt: null,
        emailOtpAttempts: 0,
        emailOtpSentAt: null,
      },
    });
    testEmailOtps.delete(email);
    await audit({
      actor: verified,
      action: 'email_verified',
      targetType: 'user',
      targetId: verified.id,
      outcome: 'SUCCESS',
      req,
    });

    const tokens = await issueTokens(res, verified, req);
    res.json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      profileCompleted: Boolean(verified.profileCompletedAt),
      user: publicUser(verified),
    });
  }),
];

export const resendEmailOtp = [
  validate({ body: z.object({ email: emailSchema }) }),
  asyncHandler(async (req, res) => {
    const { email } = req.valid.body;
    const user = await prisma.user.findUnique({ where: { email } });
    const message =
      'If that account needs verification, a new code has been issued.';
    let retryAfterSeconds = config.emailVerification.resendSeconds;

    if (user && !user.emailVerifiedAt) {
      const elapsed = user.emailOtpSentAt
        ? Date.now() - user.emailOtpSentAt.getTime()
        : Number.POSITIVE_INFINITY;
      if (elapsed < OTP_RESEND_MS()) {
        retryAfterSeconds = Math.max(
          1,
          Math.ceil((OTP_RESEND_MS() - elapsed) / 1000)
        );
      } else {
        const { code } = await issueEmailOtp(user);
        const devCode =
          config.env === 'development' && config.email.provider === 'console'
            ? { devCode: code }
            : {};
        return res.json({ ok: true, message, retryAfterSeconds, ...devCode });
      }
    }

    res.json({ ok: true, message, retryAfterSeconds });
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
