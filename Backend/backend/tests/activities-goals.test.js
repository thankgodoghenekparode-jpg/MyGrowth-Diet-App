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
import { setSetting, clearSettingCache } from '../src/lib/settings.js';

let token;
let otherToken;
let member;
let other;
let programme;
let activity;

before(async () => {
  await resetDb();
  await seedBaseline();
  member = await createUser({ email: 'tracker@test.local' });
  other = await createUser({ email: 'other@test.local' });
  token = await tokenFor(member.email);
  otherToken = await tokenFor(other.email);
  programme = await prisma.programme.findFirst({ where: { year: 2027 } });
  activity = await prisma.dailyActivity.create({
    data: {
      programmeId: programme.id,
      date: new Date(Date.UTC(2027, 4, 10)),
      title: 'Morning prayer',
      category: 'prayer',
      status: 'PUBLISHED',
      description: 'Spend time in prayer.',
    },
  });
});

test('day view generates the checklist from the published plan', async () => {
  const res = await api().get('/api/v1/me/activities?date=2027-05-10').set(bearer(token));
  assert.equal(res.status, 200);
  assert.equal(res.body.singleDay, true);
  assert.equal(res.body.dateInProgramme, true);
  assert.equal(res.body.activities.length, 1);
  assert.equal(res.body.activities[0].title, 'Morning prayer');
  assert.equal(res.body.activities[0].record, null);
  assert.equal(res.body.monthlyPlan.month, 5);
});

test('range view requires from+to and validates ordering', async () => {
  const missing = await api().get('/api/v1/me/activities').set(bearer(token));
  assert.equal(missing.status, 400);

  const bad = await api()
    .get('/api/v1/me/activities?from=2027-05-11&to=2027-05-10')
    .set(bearer(token));
  assert.equal(bad.status, 400);
});

test('activity records can be created, updated and completed', async () => {
  const created = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ activityId: activity.id, date: '2027-05-10' });
  assert.equal(created.status, 201);
  assert.equal(created.body.record.source, 'PLAN');
  assert.equal(created.body.record.status, 'NOT_STARTED');
  const id = created.body.record.id;

  const dup = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ activityId: activity.id, date: '2027-05-10' });
  assert.equal(dup.status, 409);
  assert.equal(dup.body.error.code, 'DUPLICATE_RECORD');

  const updated = await api()
    .patch(`/api/v1/me/activity-records/${id}`)
    .set(bearer(token))
    .send({ status: 'COMPLETED', actualDurationMinutes: 30 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.record.status, 'COMPLETED');
  assert.ok(updated.body.record.completedAt);

  // The day view now merges the member record with the plan activity.
  const day = await api().get('/api/v1/me/activities?date=2027-05-10').set(bearer(token));
  assert.equal(day.body.activities[0].record.status, 'COMPLETED');

  const list = await api().get('/api/v1/me/activity-records').set(bearer(token));
  assert.equal(list.status, 200);
  assert.ok(Array.isArray(list.body.data));
  assert.deepEqual(Object.keys(list.body.meta).sort(), ['page', 'pageSize', 'total', 'totalPages']);
});

test('custom activity records require title+category and are deduplicated per day', async () => {
  const created = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ title: 'Evening walk prayer', category: 'custom', date: '2027-05-11' });
  assert.equal(created.status, 201);
  assert.equal(created.body.record.source, 'CUSTOM');

  const dup = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ title: 'Evening walk prayer', category: 'custom', date: '2027-05-11' });
  assert.equal(dup.status, 409);

  const incomplete = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ date: '2027-05-12' });
  assert.equal(incomplete.status, 400);
});

test('activity records accept the Flutter actualDuration alias (create + update)', async () => {
  // Flutter posts `actualDuration` (a string) — it must be persisted as minutes.
  const created = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ title: 'Duration alias', category: 'custom', date: '2027-05-15', actualDuration: '45', status: 'IN_PROGRESS' });
  assert.equal(created.status, 201);
  assert.equal(created.body.record.actualDurationMinutes, 45);
  assert.equal(created.body.record.actualDuration, 45);

  const updated = await api()
    .patch(`/api/v1/me/activity-records/${created.body.record.id}`)
    .set(bearer(token))
    .send({ actualDuration: 20, status: 'COMPLETED' });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.record.actualDurationMinutes, 20);
  assert.equal(updated.body.record.status, 'COMPLETED');
});

test('activity records are protected from IDOR access', async () => {
  const created = await api()
    .post('/api/v1/me/activity-records')
    .set(bearer(token))
    .send({ title: 'Private record', category: 'custom', date: '2027-05-13' });

  const res = await api()
    .patch(`/api/v1/me/activity-records/${created.body.record.id}`)
    .set(bearer(otherToken))
    .send({ status: 'COMPLETED' });
  assert.equal(res.status, 404);

  const del = await api()
    .delete(`/api/v1/me/activity-records/${created.body.record.id}`)
    .set(bearer(otherToken));
  assert.equal(del.status, 404);
});

test('goals: create, list, progress and IDOR protection', async () => {
  const weekly = await api()
    .post('/api/v1/me/goals')
    .set(bearer(token))
    .send({
      title: 'Pray 7 days this week',
      periodType: 'WEEKLY',
      startDate: '2027-07-04',
      targetDate: '2027-07-10',
      targetQuantity: 7,
      unit: 'days',
    });
  assert.equal(weekly.status, 201);
  assert.equal(weekly.body.goal.periodType, 'WEEKLY');

  const bad = await api()
    .post('/api/v1/me/goals')
    .set(bearer(token))
    .send({ title: 'Bad dates', periodType: 'WEEKLY', startDate: '2027-07-10', targetDate: '2027-07-04' });
  assert.equal(bad.status, 400);

  const progress = await api()
    .post(`/api/v1/me/goals/${weekly.body.goal.id}/progress`)
    .set(bearer(token))
    .send({ value: 7, note: 'Completed' });
  assert.equal(progress.status, 201);
  assert.equal(progress.body.goal.status, 'COMPLETED');
  assert.equal(progress.body.goal.progressPercent, 100);

  const list = await api().get('/api/v1/me/goals').set(bearer(token));
  assert.equal(list.status, 200);
  assert.ok(list.body.meta);

  const idor = await api().get(`/api/v1/me/goals/${weekly.body.goal.id}`).set(bearer(otherToken));
  assert.equal(idor.status, 404);
});

test('monthly goal slots are capped unless the admin allows extras', async () => {
  for (let i = 1; i <= 3; i += 1) {
    const res = await api()
      .post('/api/v1/me/goals')
      .set(bearer(token))
      .send({
        title: `Monthly goal ${i}`,
        periodType: 'MONTHLY',
        startDate: '2027-08-01',
        targetDate: '2027-08-31',
      });
    assert.equal(res.status, 201, `monthly goal ${i} should be created`);
  }

  const blocked = await api()
    .post('/api/v1/me/goals')
    .set(bearer(token))
    .send({ title: 'Monthly goal 4', periodType: 'MONTHLY', startDate: '2027-08-01', targetDate: '2027-08-31' });
  assert.equal(blocked.status, 400);
  assert.equal(blocked.body.error.code, 'GOAL_LIMIT_REACHED');
  assert.equal(blocked.body.error.details.maxSlots, 3);

  await setSetting('goals.allowExtra', true);
  clearSettingCache();
  try {
    const allowed = await api()
      .post('/api/v1/me/goals')
      .set(bearer(token))
      .send({ title: 'Monthly goal 4', periodType: 'MONTHLY', startDate: '2027-08-01', targetDate: '2027-08-31' });
    assert.equal(allowed.status, 201);
  } finally {
    await setSetting('goals.allowExtra', false);
    clearSettingCache();
  }
});

test('dashboard and progress summaries are computed from real records', async () => {
  const dash = await api().get('/api/v1/me/dashboard').set(bearer(token));
  assert.equal(dash.status, 200);
  assert.ok(dash.body.now);
  assert.equal(dash.body.programme.year, 2027);
  assert.ok(Array.isArray(dash.body.goals));
  assert.ok(dash.body.progressSummary.monthCompletedActivities >= 0);

  const progress = await api().get('/api/v1/me/progress?period=all').set(bearer(token));
  assert.equal(progress.status, 200);
  assert.equal(progress.body.selfReported, true);
  assert.ok(progress.body.activities.total >= 1);
  // Flutter ProgressSummary consumes these flat keys directly.
  assert.equal(typeof progress.body.totalActivities, 'number');
  assert.equal(typeof progress.body.completedActivities, 'number');
  assert.equal(typeof progress.body.currentStreakDays, 'number');
  assert.equal(typeof progress.body.sessionsCompleted, 'number');
  assert.ok(Array.isArray(progress.body.byMonth));
  assert.equal(typeof progress.body.byCategory, 'object');
  assert.equal(Array.isArray(progress.body.byCategory), false);
});

test('reflections are private and IDOR-protected', async () => {
  const created = await api()
    .post('/api/v1/me/reflections')
    .set(bearer(token))
    .send({ entryDate: '2027-05-10', title: 'A word', body: 'God is faithful.' });
  assert.equal(created.status, 201);
  assert.equal(created.body.private, true);

  const idor = await api()
    .get(`/api/v1/me/reflections/${created.body.reflection.id}`)
    .set(bearer(otherToken));
  assert.equal(idor.status, 404);

  const list = await api().get('/api/v1/me/reflections').set(bearer(token));
  assert.equal(list.body.private, true);
  assert.ok(list.body.data.length >= 1);
});

test('the annual letter is private, per-programme and upserted', async () => {
  // An empty letter is returned (not a 404) so the editor opens.
  const empty = await api().get('/api/v1/me/annual-letter').set(bearer(token));
  assert.equal(empty.status, 200);
  assert.equal(empty.body.content, '');
  assert.equal(empty.body.id, null);

  // Flutter PUTs `{content}`.
  const saved = await api()
    .put('/api/v1/me/annual-letter')
    .set(bearer(token))
    .send({ content: 'Dear future me, God has been faithful.' });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.content, 'Dear future me, God has been faithful.');

  // The same call upserts rather than duplicating.
  const again = await api()
    .put('/api/v1/me/annual-letter')
    .set(bearer(token))
    .send({ content: 'Updated letter.' });
  assert.equal(again.status, 200);
  assert.equal(again.body.id, saved.body.id);
  assert.equal(again.body.content, 'Updated letter.');

  // Another member never sees this letter.
  const other = await api().get('/api/v1/me/annual-letter').set(bearer(otherToken));
  assert.equal(other.status, 200);
  assert.equal(other.body.content, '');
});

test('testimonies accept the Flutter body/visibility contract', async () => {
  // Flutter posts `body` (not `story`), an optional entryDate and the
  // MINISTRY_ADMINS visibility label.
  const created = await api()
    .post('/api/v1/me/testimonies')
    .set(bearer(token))
    .send({
      title: 'He answered',
      body: 'God is faithful.',
      tags: ['faith'],
      visibility: 'MINISTRY_ADMINS',
      consentToShare: true,
    });
  assert.equal(created.status, 201);
  assert.equal(created.body.testimony.body, 'God is faithful.');
  assert.equal(created.body.testimony.visibility, 'ADMINS');
  assert.ok(created.body.testimony.entryDate);

  // The same text is accepted via the storage column name too.
  const viaStory = await api()
    .post('/api/v1/me/testimonies')
    .set(bearer(token))
    .send({ title: 'Story form', story: 'Stored as story.', entryDate: '2027-06-01' });
  assert.equal(viaStory.status, 201);
  assert.equal(viaStory.body.testimony.body, 'Stored as story.');

  // Community sharing still requires explicit consent.
  const noConsent = await api()
    .post('/api/v1/me/testimonies')
    .set(bearer(token))
    .send({ title: 'Share me', body: 'Open.', visibility: 'COMMUNITY', consentToShare: false });
  assert.equal(noConsent.status, 400);
  assert.equal(noConsent.body.error.code, 'CONSENT_REQUIRED');

  const list = await api().get('/api/v1/me/testimonies').set(bearer(token));
  assert.equal(list.status, 200);
  assert.ok(list.body.data.every((t) => typeof t.body === 'string'));
});
