import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  api,
  prisma,
  resetDb,
  seedBaseline,
  createUser,
  tokenFor,
  bearer,
  auditRows,
} from './helpers/setup.js';
import { clearSettingCache } from '../src/lib/settings.js';

let adminToken;
let memberToken;
let admin;
let pendingMember;

before(async () => {
  await resetDb();
  await seedBaseline();
  admin = await createUser({ email: 'ops.admin@test.local', role: 'ADMIN', adminAccess: 'ACTIVE' });
  pendingMember = await createUser({ email: 'awaiting@test.local', status: 'PENDING' });
  const member = await createUser({ email: 'plain.member@test.local' });
  adminToken = await tokenFor(admin.email);
  memberToken = await tokenFor(member.email);
});

test('GET /admin/users paginates and filters members', async () => {
  const res = await api().get('/api/v1/admin/users?page=1&pageSize=10').set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  assert.equal(res.body.meta.page, 1);
  assert.equal(res.body.meta.pageSize, 10);
  assert.ok(res.body.data.every((u) => u.role === 'MEMBER'));

  const pending = await api()
    .get('/api/v1/admin/users?status=PENDING')
    .set(bearer(adminToken));
  assert.ok(pending.body.data.some((u) => u.id === pendingMember.id));

  const search = await api()
    .get('/api/v1/admin/users?search=awaiting')
    .set(bearer(adminToken));
  assert.ok(search.body.data.some((u) => u.email === 'awaiting@test.local'));
});

test('GET /admin/users/:id returns member stats without private data', async () => {
  const res = await api().get(`/api/v1/admin/users/${pendingMember.id}`).set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.equal(res.body.user.email, 'awaiting@test.local');
  assert.ok(res.body.stats);
  assert.equal(res.body.user.passwordHash, undefined);
});

test('admins approve and suspend members (audited)', async () => {
  const approve = await api()
    .post(`/api/v1/admin/users/${pendingMember.id}/approve`)
    .set(bearer(adminToken));
  assert.equal(approve.status, 200);
  assert.equal(approve.body.user.status, 'ACTIVE');
  assert.ok((await auditRows('member_approved')).length >= 1);

  const suspend = await api()
    .post(`/api/v1/admin/users/${pendingMember.id}/suspend`)
    .set(bearer(adminToken));
  assert.equal(suspend.status, 200);
  assert.equal(suspend.body.user.status, 'SUSPENDED');

  // Suspended members are immediately locked out of protected routes.
  const loginRes = await api()
    .post('/api/v1/auth/login')
    .send({ email: 'awaiting@test.local', password: 'TestPass!2027' });
  assert.equal(loginRes.status, 403);
});

test('admins cannot approve/suspend administrators', async () => {
  const res = await api()
    .post(`/api/v1/admin/users/${admin.id}/approve`)
    .set(bearer(adminToken));
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'ROLE_PROTECTED');
});

test('analytics overview returns real aggregate counts', async () => {
  const res = await api().get('/api/v1/admin/analytics/overview').set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.ok(res.body.members.total >= 2);
  assert.ok(typeof res.body.members.active === 'number');
  assert.ok(res.body.reports);
  assert.ok(res.body.activityCompletion);
  assert.ok(Array.isArray(res.body.participationOverTime));
  assert.ok(Array.isArray(res.body.recentSignups));
});

test('analytics export returns a CSV attachment', async () => {
  const res = await api().get('/api/v1/admin/analytics/export').set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.match(res.headers['content-type'], /text\/csv/);
  assert.match(res.text.split('\n')[0], /email,first_name/);
});

test('settings can be read and updated, and changes take effect', async () => {
  const before = await api().get('/api/v1/admin/settings').set(bearer(adminToken));
  assert.equal(before.status, 200);
  assert.ok('goals.maxMonthlySuggested' in before.body.settings);

  const patch = await api()
    .patch('/api/v1/admin/settings')
    .set(bearer(adminToken))
    .send({ 'goals.maxMonthlySuggested': 5, 'registration.approvalRequired': true });
  assert.equal(patch.status, 200);
  assert.equal(patch.body.settings['goals.maxMonthlySuggested'], 5);
  assert.equal(patch.body.settings['registration.approvalRequired'], true);
  clearSettingCache();

  const row = await prisma.setting.findUnique({ where: { key: 'goals.maxMonthlySuggested' } });
  assert.equal(row.value, 5);

  // Restore defaults for other tests/files.
  await api()
    .patch('/api/v1/admin/settings')
    .set(bearer(adminToken))
    .send({ 'goals.maxMonthlySuggested': 3, 'registration.approvalRequired': false });
  clearSettingCache();
});

test('settings reject unknown or invalid values', async () => {
  const unknown = await api()
    .patch('/api/v1/admin/settings')
    .set(bearer(adminToken))
    .send({ 'auth.allowEverything': true });
  // Unknown keys are stripped by validation; the request still succeeds with no changes.
  assert.equal(unknown.status, 200);

  const invalid = await api()
    .patch('/api/v1/admin/settings')
    .set(bearer(adminToken))
    .send({ 'goals.maxMonthlySuggested': 999 });
  assert.equal(invalid.status, 400);
  assert.equal(invalid.body.error.code, 'VALIDATION_ERROR');
});

test('audit logs are queryable and paginated', async () => {
  const res = await api()
    .get('/api/v1/admin/audit-logs?action=member_approved')
    .set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  assert.ok(res.body.meta);
  assert.ok(res.body.data.every((r) => r.action.includes('member_approved')));
});

test('members cannot reach any analytics or settings endpoints', async () => {
  for (const path of [
    '/api/v1/admin/analytics/overview',
    '/api/v1/admin/settings',
    '/api/v1/admin/audit-logs',
    '/api/v1/admin/reports',
  ]) {
    const res = await api().get(path).set(bearer(memberToken));
    assert.equal(res.status, 403, `${path} should be forbidden`);
    assert.equal(res.body.error.code, 'ADMIN_ACCESS_REQUIRED');
  }
});
