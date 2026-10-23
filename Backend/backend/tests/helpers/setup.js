/**
 * Shared test harness.
 *
 * Provides the application under test (via supertest), a shared Prisma client
 * bound to the test database, database reset/seed helpers, user factories and
 * login helpers.
 *
 * Every test file imports this module first; the first import line is `./env.js`
 * so the test database is selected before any `src/**` module is evaluated.
 */
import './env.js';

import { after } from 'node:test';
import supertest from 'supertest';
import config from '../../src/config/index.js';
import prisma from '../../src/db/index.js';
import { createApp } from '../../src/app.js';
import { hashPassword } from '../../src/lib/password.js';
import { clearSettingCache } from '../../src/lib/settings.js';
import { seedProgramme, seedDefinitions } from '../../prisma/seed.js';

export { prisma, config };

/** Default password used by the user factory (meets the 8-char policy). */
export const TEST_PASSWORD = 'TestPass!2027';

let app = null;

/** Lazily build and memoise the Express app. */
export function getApp() {
  if (!app) app = createApp();
  return app;
}

/** supertest bound to the app under test. */
export function api() {
  return supertest(getApp());
}

/** Truncate every application table (keeps Prisma migration history). */
export async function resetDb() {
  const rows = await prisma.$queryRawUnsafe(
    `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`
  );
  const tables = rows.map((r) => `"public"."${r.tablename}"`);
  if (tables.length) {
    await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${tables.join(', ')} RESTART IDENTITY CASCADE`);
  }
  clearSettingCache();
}

/** Seed the published 2027 programme + monthly plans and definition/setting rows. */
export async function seedBaseline() {
  await seedProgramme();
  await seedDefinitions();
}

let emailCounter = 0;

/** Deterministic-but-unique test email. */
export function uniqueEmail(prefix = 'user') {
  emailCounter += 1;
  return `${prefix}.${emailCounter}.${Date.now()}@test.local`;
}

/**
 * Create a user directly in the database.
 * Public registration always makes a MEMBER; this factory is for setting up
 * admins / suspended / pending accounts in tests.
 */
export async function createUser(options = {}) {
  const {
    email = uniqueEmail(),
    password = TEST_PASSWORD,
    firstName = 'Test',
    lastName = 'User',
    role = 'MEMBER',
    status = 'ACTIVE',
    adminAccess = role === 'MEMBER' ? 'NONE' : 'ACTIVE',
    timezone = 'Africa/Lagos',
    emailVerified = true,
    phone = null,
    createdByAdminId = null,
  } = options;

  return prisma.user.create({
    data: {
      email,
      firstName,
      lastName,
      phone,
      passwordHash: await hashPassword(password),
      role,
      status,
      adminAccess,
      timezone,
      emailVerifiedAt: emailVerified ? new Date() : null,
      createdByAdminId,
    },
  });
}

/** Log in through the API; returns the token plus the refresh cookie. */
export async function login(email, password = TEST_PASSWORD) {
  const res = await api().post('/api/v1/auth/login').send({ email, password });
  const setCookies = res.headers['set-cookie'] || [];
  const raw = setCookies.find((c) => c.startsWith(`${config.refreshCookieName}=`)) || null;
  return {
    res,
    accessToken: res.body?.accessToken,
    refreshCookie: cookiePair(raw),
    rawSetCookie: raw,
    user: res.body?.user,
  };
}

/** Log in and return just the access token (throws on failure). */
export async function tokenFor(email, password = TEST_PASSWORD) {
  const { accessToken, res } = await login(email, password);
  if (!accessToken) {
    throw new Error(`login failed for ${email}: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return accessToken;
}

/** Extract the "name=value" pair from a Set-Cookie header. */
export function cookiePair(setCookie) {
  return setCookie ? setCookie.split(';')[0] : null;
}

/** Authorization header object for Bearer tokens. */
export function bearer(token) {
  return { Authorization: `Bearer ${token}` };
}

/** Read all audit log rows for a given action. */
export function auditRows(action) {
  return prisma.auditLog.findMany({ where: { action }, orderBy: { createdAt: 'desc' } });
}

// Ensure Prisma disconnects when the test file finishes.
after(async () => {
  await prisma.$disconnect();
});
