import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, prisma, resetDb, seedBaseline, createUser, tokenFor, bearer } from './helpers/setup.js';

let token;
let programme;

before(async () => {
  await resetDb();
  await seedBaseline();
  await createUser({ email: 'content.member@test.local' });
  token = await tokenFor('content.member@test.local');
  programme = await prisma.programme.findFirst({ where: { year: 2027 } });
});

test('the seeded 2027 programme is listed for members', async () => {
  const res = await api().get('/api/v1/programmes').set(bearer(token));
  assert.equal(res.status, 200);
  const p = res.body.data.find((x) => x.year === 2027);
  assert.ok(p, '2027 programme should be listed');
  assert.equal(p.title, 'Growth Diet Plan 2027');
  assert.equal(p.ministry, 'Healings Erhuvwuigho Azuike Ministry');
  assert.equal(p.monthlyPlanCount, 12);
});

test('programme detail includes the quarterly + annual content', async () => {
  const res = await api().get(`/api/v1/programmes/${programme.id}`).set(bearer(token));
  assert.equal(res.status, 200);
  assert.ok(res.body.quarterlyConfession.includes('growing in grace'));
  assert.deepEqual(res.body.quarterlyReviewTopics, [
    'Bible reading',
    'Prayer life',
    'Stewardship',
    'Service',
    'Relationships',
    'Character growth',
  ]);
  assert.equal(res.body.annualReflectionTemplate.sections.length, 7);
  assert.equal(res.body.monthlyPlans.length, 12);
});

test('monthly plan content is faithful to the spec', async () => {
  const jan = await api().get(`/api/v1/programmes/${programme.id}/monthly-plans/1`).set(bearer(token));
  assert.equal(jan.status, 200);
  assert.equal(jan.body.monthlyPlan.theme, 'The Fatherhood of God');
  assert.equal(jan.body.monthlyPlan.audioMessages[0], 'God as Father 1–5 by Pastor Healings E. Azuike');
  assert.equal(
    jan.body.monthlyPlan.monthlyConfession,
    'My path is a shining light, and it shines brighter and brighter unto a perfect day. Pro 4vs1'
  );

  const feb = await api().get(`/api/v1/programmes/${programme.id}/monthly-plans/2`).set(bearer(token));
  assert.equal(feb.body.monthlyPlan.theme, "God's Purpose for Man");
  assert.equal(feb.body.monthlyPlan.reflectionQuestions.length, 6);
  assert.match(feb.body.monthlyPlan.reflectionQuestions[0], /driving my consistent desire/);

  const jun = await api().get(`/api/v1/programmes/${programme.id}/monthly-plans/6`).set(bearer(token));
  assert.equal(jun.body.monthlyPlan.theme, 'Understanding Relationships');

  const dec = await api().get(`/api/v1/programmes/${programme.id}/monthly-plans/12`).set(bearer(token));
  assert.equal(dec.body.monthlyPlan.theme, 'The Blessing of God');
});

test('programmes-today resolves the month for a date inside 2027', async () => {
  const res = await api()
    .get('/api/v1/programmes/today?date=2027-10-19')
    .set(bearer(token));
  assert.equal(res.status, 200);
  assert.equal(res.body.dateInProgramme, true);
  assert.equal(res.body.programme.year, 2027);
  assert.equal(res.body.monthlyPlan.month, 10);
  assert.equal(res.body.monthlyPlan.theme, 'Mentor & Discipleship');
});

test('programmes-today falls back (dateInProgramme=false) outside the programme window', async () => {
  const res = await api()
    .get('/api/v1/programmes/today?date=2026-01-15')
    .set(bearer(token));
  assert.equal(res.status, 200);
  assert.equal(res.body.dateInProgramme, false);
  assert.equal(res.body.programme.year, 2027);
});

test('GET /me/report-fields exposes the structured report definitions', async () => {
  const res = await api().get('/api/v1/me/report-fields').set(bearer(token));
  assert.equal(res.status, 200);
  assert.ok(res.body.fields.WEEKLY.length > 0);
  assert.ok(res.body.fields.MONTHLY.some((f) => f.key === 'reflection_q1'));
  assert.ok(res.body.fields.QUARTERLY.length > 0);
  assert.ok(res.body.fields.ANNUAL.length > 0);
  assert.match(res.body.visibilityNotice, /visible to authorised ministry administrators/i);
  assert.ok(res.body.quarterlyConfession);
});

test('draft programmes/monthly plans are never returned to members', async () => {
  const draft = await prisma.programme.create({
    data: {
      title: 'Hidden 2028',
      year: 2028,
      ministry: 'Test Ministry',
      status: 'DRAFT',
    },
  });

  const list = await api().get('/api/v1/programmes').set(bearer(token));
  assert.equal(list.body.data.some((p) => p.id === draft.id), false);

  const detail = await api().get(`/api/v1/programmes/${draft.id}`).set(bearer(token));
  assert.equal(detail.status, 404);

  // A draft monthly plan inside the published programme is hidden too.
  await prisma.monthlyPlan.update({
    where: { programmeId_month: { programmeId: programme.id, month: 12 } },
    data: { status: 'DRAFT' },
  });
  const months = await api()
    .get(`/api/v1/programmes/${programme.id}/monthly-plans`)
    .set(bearer(token));
  assert.equal(months.body.data.length, 11);
  const hidden = await api()
    .get(`/api/v1/programmes/${programme.id}/monthly-plans/12`)
    .set(bearer(token));
  assert.equal(hidden.status, 404);
});
