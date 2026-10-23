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
} from './helpers/setup.js';
import { REPORT_FIELDS } from '../src/lib/reportFields.js';

let memberToken;
let otherToken;
let adminToken;
let member;
let other;

function requiredAnswers(reportType) {
  const fields = (REPORT_FIELDS[reportType] || []).filter((f) => !f.optional && !f.dynamic);
  return Object.fromEntries(fields.map((f) => [f.key, `Answer for ${f.key}`]));
}

before(async () => {
  await resetDb();
  await seedBaseline();
  member = await createUser({ email: 'reporter@test.local' });
  other = await createUser({ email: 'other.reporter@test.local' });
  const admin = await createUser({ email: 'report.admin@test.local', role: 'ADMIN', adminAccess: 'ACTIVE' });
  memberToken = await tokenFor(member.email);
  otherToken = await tokenFor(other.email);
  adminToken = await tokenFor(admin.email);
});

test('a weekly report starts as a DRAFT with a normalised period key', async () => {
  const res = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'WEEKLY', periodKey: '2027-03-15' });

  assert.equal(res.status, 201);
  assert.equal(res.body.report.status, 'DRAFT');
  assert.equal(res.body.report.reportType, 'WEEKLY');
  // Monday 2027-03-15 normalises to the Sunday that starts its week.
  assert.equal(res.body.report.periodKey, '2027-03-14');
  assert.match(res.body.report.visibilityNotice, /visible to authorised ministry administrators/i);
});

test('duplicate reports for the same period are rejected', async () => {
  const res = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'WEEKLY', periodKey: '2027-03-15' });
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'DUPLICATE_REPORT');
});

test('invalid period keys are rejected', async () => {
  const res = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'MONTHLY', periodKey: '2027-3' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
});

test('unknown answer fields are rejected', async () => {
  const created = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'WEEKLY', periodKey: '2027-04-04' });
  const res = await api()
    .patch(`/api/v1/me/reports/${created.body.report.id}`)
    .set(bearer(memberToken))
    .send({ answers: { totally_made_up: 'x' } });
  assert.equal(res.status, 400);
});

test('submission requires all required answers and explicit confirmation', async () => {
  const created = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'WEEKLY', periodKey: '2027-04-11' });
  const id = created.body.report.id;

  const missing = await api()
    .post(`/api/v1/me/reports/${id}/submit`)
    .set(bearer(memberToken))
    .send({ confirmed: true });
  assert.equal(missing.status, 400);
  assert.equal(missing.body.error.code, 'MISSING_ANSWERS');
  assert.ok(missing.body.error.details.missing.length > 0);

  const filled = await api()
    .patch(`/api/v1/me/reports/${id}`)
    .set(bearer(memberToken))
    .send({ answers: requiredAnswers('WEEKLY') });
  assert.equal(filled.status, 200);

  const noConfirm = await api()
    .post(`/api/v1/me/reports/${id}/submit`)
    .set(bearer(memberToken))
    .send({ confirmed: false });
  assert.equal(noConfirm.status, 400);

  const submitted = await api()
    .post(`/api/v1/me/reports/${id}/submit`)
    .set(bearer(memberToken))
    .send({ confirmed: true });
  assert.equal(submitted.status, 200);
  assert.equal(submitted.body.report.status, 'SUBMITTED');
  assert.ok(submitted.body.report.submittedAt);
});

test('editing a submitted report creates a revision; submitted reports cannot be deleted', async () => {
  const report = await prisma.report.findFirst({
    where: { userId: member.id, reportType: 'WEEKLY', status: 'SUBMITTED' },
  });

  const edited = await api()
    .patch(`/api/v1/me/reports/${report.id}`)
    .set(bearer(memberToken))
    .send({ answers: { learnings: 'Updated learnings' } });
  assert.equal(edited.status, 200);
  assert.equal(edited.body.report.revision, 2);
  assert.equal(edited.body.report.answers.learnings, 'Updated learnings');

  const revisions = await prisma.reportRevision.findMany({ where: { reportId: report.id } });
  assert.equal(revisions.length, 1);

  const del = await api()
    .delete(`/api/v1/me/reports/${report.id}`)
    .set(bearer(memberToken));
  assert.equal(del.status, 409);
  assert.equal(del.body.error.code, 'INVALID_STATE');
});

test('draft reports can be deleted and are IDOR-protected', async () => {
  const created = await api()
    .post('/api/v1/me/reports')
    .set(bearer(memberToken))
    .send({ reportType: 'ANNUAL', periodKey: '2027' });
  const id = created.body.report.id;

  const idor = await api().get(`/api/v1/me/reports/${id}`).set(bearer(otherToken));
  assert.equal(idor.status, 404);

  const del = await api().delete(`/api/v1/me/reports/${id}`).set(bearer(memberToken));
  assert.equal(del.status, 200);
});

test('admins only see submitted reports (never drafts)', async () => {
  await api()
    .post('/api/v1/me/reports')
    .set(bearer(otherToken))
    .send({ reportType: 'WEEKLY', periodKey: '2027-05-02' });

  const res = await api().get('/api/v1/admin/reports').set(bearer(adminToken));
  assert.equal(res.status, 200);
  assert.ok(res.body.data.length >= 1);
  assert.ok(res.body.data.every((r) => r.status !== 'DRAFT'));
});

test('admin review marks a report REVIEWED, which locks member edits', async () => {
  const report = await prisma.report.findFirst({
    where: { userId: member.id, reportType: 'WEEKLY', status: 'SUBMITTED' },
  });

  const detail = await api().get(`/api/v1/admin/reports/${report.id}`).set(bearer(adminToken));
  assert.equal(detail.status, 200);
  assert.ok(detail.body.report.answers.learnings);

  const review = await api()
    .post(`/api/v1/admin/reports/${report.id}/reviews`)
    .set(bearer(adminToken))
    .send({ action: 'MARK_REVIEWED' });
  assert.equal(review.status, 201);
  assert.equal(review.body.report.status, 'REVIEWED');

  const locked = await api()
    .patch(`/api/v1/me/reports/${report.id}`)
    .set(bearer(memberToken))
    .send({ answers: { learnings: 'Should be blocked' } });
  assert.equal(locked.status, 409);
  assert.equal(locked.body.error.code, 'REPORT_LOCKED');

  // Reviewing notifies the member.
  const note = await prisma.notification.findFirst({
    where: { userId: member.id, eventType: 'admin_report_comment' },
  });
  assert.ok(note);
});

test('reports-status/current summarises the four report periods', async () => {
  const res = await api().get('/api/v1/me/reports-status/current').set(bearer(memberToken));
  assert.equal(res.status, 200);
  assert.deepEqual(Object.keys(res.body.reports).sort(), ['ANNUAL', 'MONTHLY', 'QUARTERLY', 'WEEKLY']);
});
