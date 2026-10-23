import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  api,
  prisma,
  resetDb,
  createUser,
  login,
  tokenFor,
  bearer,
  cookiePair,
  auditRows,
  TEST_PASSWORD,
} from './helpers/setup.js';
import { setSetting, clearSettingCache } from '../src/lib/settings.js';

before(async () => {
  await resetDb();
});

const email = 'auth.member@test.local';

test('register creates an ACTIVE MEMBER and returns tokens', async () => {
  const res = await api()
    .post('/api/v1/auth/register')
    .send({ firstName: 'Auth', lastName: 'Member', email, password: TEST_PASSWORD });

  assert.equal(res.status, 201);
  assert.equal(res.body.user.role, 'MEMBER');
  assert.equal(res.body.user.status, 'ACTIVE');
  assert.ok(res.body.accessToken);
  assert.ok(res.body.refreshToken);
  assert.ok(res.headers['set-cookie'].some((c) => c.startsWith('mgdp_refresh=')));

  const dbUser = await prisma.user.findUnique({ where: { email } });
  assert.equal(dbUser.role, 'MEMBER');
  assert.ok(dbUser.passwordHash.startsWith('$2'));
});

test('register ignores/rejects a client-supplied privileged role and audits it', async () => {
  const res = await api()
    .post('/api/v1/auth/register')
    .send({
      firstName: 'Sneaky',
      lastName: 'User',
      email: 'sneaky@test.local',
      password: 'StrongPass1!',
      role: 'MAIN_ADMIN',
    });

  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'ROLE_NOT_ASSIGNABLE');

  // No account was created.
  assert.equal(await prisma.user.findUnique({ where: { email: 'sneaky@test.local' } }), null);

  const rows = await auditRows('privilege_escalation_attempt');
  assert.ok(rows.some((r) => r.details?.via === 'register' && r.outcome === 'DENIED'));
});

test('register rejects duplicate emails and invalid payloads', async () => {
  const dup = await api()
    .post('/api/v1/auth/register')
    .send({ firstName: 'Auth', lastName: 'Member', email, password: 'StrongPass1!' });
  assert.equal(dup.status, 409);
  assert.equal(dup.body.error.code, 'EMAIL_TAKEN');

  const bad = await api()
    .post('/api/v1/auth/register')
    .send({ firstName: '', lastName: 'X', email: 'not-an-email', password: 'short' });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error.code, 'VALIDATION_ERROR');
});

test('login issues an access token and refresh cookie', async () => {
  const { res, accessToken, refreshCookie } = await login(email);
  assert.equal(res.status, 200);
  assert.ok(accessToken);
  assert.ok(refreshCookie?.startsWith('mgdp_refresh='));
});

test('login fails with a wrong password (generic message)', async () => {
  const res = await api()
    .post('/api/v1/auth/login')
    .send({ email, password: 'WrongPassword!' });
  assert.equal(res.status, 401);
  assert.equal(res.body.error.code, 'INVALID_CREDENTIALS');
});

test('protected routes require a valid access token', async () => {
  const anon = await api().get('/api/v1/me');
  assert.equal(anon.status, 401);
  assert.equal(anon.body.error.code, 'UNAUTHORIZED');

  const bad = await api().get('/api/v1/me').set('Authorization', 'Bearer not-a-token');
  assert.equal(bad.status, 401);
  assert.equal(bad.body.error.code, 'INVALID_TOKEN');

  const token = await tokenFor(email);
  const ok = await api().get('/api/v1/me').set(bearer(token));
  assert.equal(ok.status, 200);
  assert.equal(ok.body.email, email);
});

test('refresh rotates tokens and detects reuse (revoking the family)', async () => {
  const first = await login(email);
  const cookie1 = first.refreshCookie;

  const rotated = await api().post('/api/v1/auth/refresh').set('Cookie', cookie1);
  assert.equal(rotated.status, 200);
  const cookie2 = cookiePair(
    rotated.headers['set-cookie'].find((c) => c.startsWith('mgdp_refresh='))
  );
  assert.notEqual(first.refreshCookie, cookie2);

  // Reusing the old token is treated as theft and kills the whole family.
  const reuse = await api().post('/api/v1/auth/refresh').set('Cookie', cookie1);
  assert.equal(reuse.status, 401);
  assert.equal(reuse.body.error.code, 'REFRESH_REUSE_DETECTED');

  const after = await api().post('/api/v1/auth/refresh').set('Cookie', cookie2);
  assert.equal(after.status, 401);
  assert.equal(after.body.error.code, 'REFRESH_REUSE_DETECTED');
});

test('an access token cannot be used as a refresh token', async () => {
  const token = await tokenFor(email);
  const res = await api().post('/api/v1/auth/refresh').send({ refreshToken: token });
  assert.equal(res.status, 401);
  assert.equal(res.body.error.code, 'INVALID_REFRESH_TOKEN');
});

test('logout revokes the presented refresh token', async () => {
  const { refreshCookie } = await login(email);
  const out = await api().post('/api/v1/auth/logout').set('Cookie', refreshCookie);
  assert.equal(out.status, 200);
  assert.equal(out.body.ok, true);

  const res = await api().post('/api/v1/auth/refresh').set('Cookie', refreshCookie);
  assert.equal(res.status, 401);
});

test('suspended members cannot log in; suspended admins have no access', async () => {
  await createUser({ email: 'susp.member@test.local', status: 'SUSPENDED' });
  const suspended = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'susp.member@test.local', password: TEST_PASSWORD });
  assert.equal(suspended.status, 403);
  assert.equal(suspended.body.error.code, 'ACCOUNT_SUSPENDED');

  await createUser({
    email: 'susp.admin@test.local',
    role: 'ADMIN',
    status: 'ACTIVE',
    adminAccess: 'SUSPENDED',
  });
  const admin = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'susp.admin@test.local', password: TEST_PASSWORD });
  assert.equal(admin.status, 403);
  assert.equal(admin.body.error.code, 'ADMIN_ACCESS_NOT_GRANTED');

  // A freshly created (PENDING access) admin also cannot log in.
  await createUser({
    email: 'pending.admin@test.local',
    role: 'ADMIN',
    status: 'ACTIVE',
    adminAccess: 'PENDING',
  });
  const pending = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'pending.admin@test.local', password: TEST_PASSWORD });
  assert.equal(pending.status, 403);
  assert.equal(pending.body.error.code, 'ADMIN_ACCESS_NOT_GRANTED');
});

test('registration approval setting gates member content', async () => {
  await setSetting('registration.approvalRequired', true);
  clearSettingCache();

  try {
    const res = await api()
      .post('/api/v1/auth/register')
      .send({
        firstName: 'Waiting',
        lastName: 'Member',
        email: 'waiting@test.local',
        password: 'StrongPass1!',
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.user.status, 'PENDING');

    // A pending member may sign in but cannot reach programme content.
    const { accessToken } = await login('waiting@test.local', 'StrongPass1!');
    const blocked = await api().get('/api/v1/programmes').set(bearer(accessToken));
    assert.equal(blocked.status, 403);
    assert.equal(blocked.body.error.code, 'MEMBERSHIP_PENDING_APPROVAL');
  } finally {
    await setSetting('registration.approvalRequired', false);
    clearSettingCache();
  }
});

test('change-password verifies the current password and rotates it', async () => {
  await createUser({ email: 'changer@test.local', password: 'OldPass123!' });
  const token = await tokenFor('changer@test.local', 'OldPass123!');

  const wrong = await api()
    .post('/api/v1/auth/change-password')
    .set(bearer(token))
    .send({ currentPassword: 'Nope12345!', newPassword: 'NewPass123!' });
  assert.equal(wrong.status, 400);
  assert.equal(wrong.body.error.code, 'INVALID_CREDENTIALS');

  const ok = await api()
    .post('/api/v1/auth/change-password')
    .set(bearer(token))
    .send({ currentPassword: 'OldPass123!', newPassword: 'NewPass123!' });
  assert.equal(ok.status, 200);

  const oldLogin = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'changer@test.local', password: 'OldPass123!' });
  assert.equal(oldLogin.status, 401);

  const newLogin = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'changer@test.local', password: 'NewPass123!' });
  assert.equal(newLogin.status, 200);
});

test('forgot/reset password flow responds generically and rejects bad tokens', async () => {
  const forgot = await api()
    .post('/api/v1/auth/forgot-password')
    .send({ email: 'nobody@test.local' });
  assert.equal(forgot.status, 200);
  assert.match(forgot.body.message, /if that account exists/i);

  const bad = await api()
    .post('/api/v1/auth/reset-password')
    .send({ token: 'x'.repeat(40), newPassword: 'NewPass123!' });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error.code, 'INVALID_RESET_TOKEN');
});

test('verify-email rejects an invalid token', async () => {
  const res = await api()
    .post('/api/v1/auth/verify-email')
    .send({ token: 'definitely-not-valid-token-value' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'INVALID_VERIFICATION_TOKEN');
});

test('GET /auth/session returns the current user', async () => {
  const token = await tokenFor(email);
  const res = await api().get('/api/v1/auth/session').set(bearer(token));
  assert.equal(res.status, 200);
  assert.equal(res.body.user.email, email);
  assert.equal(res.body.user.passwordHash, undefined);
});
