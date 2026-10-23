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
  auditRows,
  TEST_PASSWORD,
} from './helpers/setup.js';

let mainAdmin;
let admin;
let member;

before(async () => {
  await resetDb();
  mainAdmin = await createUser({
    email: 'main@test.local',
    role: 'MAIN_ADMIN',
    adminAccess: 'ACTIVE',
    firstName: 'Main',
  });
  admin = await createUser({ email: 'admin@test.local', role: 'ADMIN', adminAccess: 'ACTIVE' });
  member = await createUser({ email: 'member@test.local', role: 'MEMBER' });
});

test('exactly one MAIN_ADMIN can exist (database trigger)', async () => {
  assert.equal(await prisma.user.count({ where: { role: 'MAIN_ADMIN' } }), 1);
  await assert.rejects(() =>
    createUser({ email: 'main2@test.local', role: 'MAIN_ADMIN', adminAccess: 'ACTIVE' })
  );
});

test('a normal ADMIN cannot create admins (Main Admin only) and is audited', async () => {
  const token = await tokenFor(admin.email);
  const res = await api()
    .post('/api/v1/admin/admins')
    .set(bearer(token))
    .send({ email: 'new.admin@test.local', firstName: 'New', lastName: 'Admin', password: 'AdminPass1!' });

  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'MAIN_ADMIN_ACCESS_REQUIRED');

  const rows = await auditRows('privilege_escalation_attempt');
  assert.ok(rows.some((r) => r.details?.required === 'main_admin'));
});

test('Main Admin creates an ADMIN that starts with PENDING (no) access', async () => {
  const token = await tokenFor(mainAdmin.email);
  const res = await api()
    .post('/api/v1/admin/admins')
    .set(bearer(token))
    .send({ email: 'granted.admin@test.local', firstName: 'Granted', lastName: 'Admin', password: 'AdminPass1!' });

  assert.equal(res.status, 201);
  assert.equal(res.body.user.role, 'ADMIN');
  assert.equal(res.body.user.adminAccess, 'PENDING');

  // The account exists but cannot sign in until access is granted.
  const attempted = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'granted.admin@test.local', password: 'AdminPass1!' });
  assert.equal(attempted.status, 403);
  assert.equal(attempted.body.error.code, 'ADMIN_ACCESS_NOT_GRANTED');
});

test('Main Admin grants administrative access, after which the admin can sign in', async () => {
  const created = await prisma.user.findUnique({ where: { email: 'granted.admin@test.local' } });
  const token = await tokenFor(mainAdmin.email);

  const grant = await api()
    .patch(`/api/v1/admin/admins/${created.id}/access`)
    .set(bearer(token))
    .send({ action: 'grant' });
  assert.equal(grant.status, 200);
  assert.equal(grant.body.user.adminAccess, 'ACTIVE');

  const loginRes = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'granted.admin@test.local', password: 'AdminPass1!' });
  assert.equal(loginRes.status, 200);
});

test('the Main Admin account cannot be modified through access management', async () => {
  const token = await tokenFor(mainAdmin.email);
  const res = await api()
    .patch(`/api/v1/admin/admins/${mainAdmin.id}/access`)
    .set(bearer(token))
    .send({ action: 'revoke' });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'MAIN_ADMIN_PROTECTED');
  assert.ok((await auditRows('main_admin_access_change_blocked')).length >= 1);
});

test('members are denied admin routes and the attempt is audited', async () => {
  const token = await tokenFor(member.email);
  const res = await api().get('/api/v1/admin/users').set(bearer(token));
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'ADMIN_ACCESS_REQUIRED');

  const rows = await auditRows('privilege_escalation_attempt');
  assert.ok(rows.some((r) => r.details?.required === 'admin'));
});

test('members cannot mass-assign privileged fields via PATCH /me', async () => {
  const token = await tokenFor(member.email);
  const res = await api()
    .patch('/api/v1/me')
    .set(bearer(token))
    .send({ role: 'MAIN_ADMIN' });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'FIELD_NOT_EDITABLE');

  const rows = await auditRows('privilege_escalation_attempt');
  assert.ok(rows.some((r) => r.details?.via === 'PATCH /me'));

  const stillMember = await prisma.user.findUnique({ where: { id: member.id } });
  assert.equal(stillMember.role, 'MEMBER');
});

test('admins cannot change a member role/status through the profile PATCH', async () => {
  const token = await tokenFor(mainAdmin.email);
  const res = await api()
    .patch(`/api/v1/admin/users/${member.id}`)
    .set(bearer(token))
    .send({ status: 'SUSPENDED' });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'FIELD_NOT_EDITABLE');
});

test('admins cannot edit administrator accounts through /admin/users', async () => {
  const token = await tokenFor(mainAdmin.email);
  const res = await api()
    .patch(`/api/v1/admin/users/${admin.id}`)
    .set(bearer(token))
    .send({ firstName: 'Hacked' });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'ROLE_PROTECTED');
});

test('a granted admin can access admin routes', async () => {
  const token = await tokenFor(admin.email);
  const res = await api().get('/api/v1/admin/users').set(bearer(token));
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  assert.ok(res.body.meta);
});

test('admin listing never leaks password hashes', async () => {
  const token = await tokenFor(mainAdmin.email);
  const res = await api().get('/api/v1/admin/admins').set(bearer(token));
  assert.equal(res.status, 200);
  for (const a of res.body.data) {
    assert.equal(a.passwordHash, undefined);
    assert.equal(a.verificationTokenHash, undefined);
  }
});
