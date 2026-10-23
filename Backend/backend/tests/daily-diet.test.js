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
import { seedDailyDiet } from '../prisma/seed.js';

let memberToken;
let otherToken;
let adminToken;
let programme;

const DATE = '2027-03-17';

before(async () => {
  await resetDb();
  await seedBaseline();
  programme = await prisma.programme.findFirst({ where: { year: 2027 } });
  await seedDailyDiet(programme);

  await createUser({ email: 'diet.member@test.local' });
  await createUser({ email: 'diet.other@test.local' });
  await createUser({
    email: 'diet.admin@test.local',
    role: 'ADMIN',
    adminAccess: 'ACTIVE',
  });

  memberToken = await tokenFor('diet.member@test.local');
  otherToken = await tokenFor('diet.other@test.local');
  adminToken = await tokenFor('diet.admin@test.local');
});

// --------------------------------------------------------------- member view

test('GET /daily-diet returns the published structure for a day', async () => {
  const res = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));

  assert.equal(res.status, 200);
  assert.equal(res.body.date, DATE);
  assert.equal(res.body.dateInProgramme, true);
  assert.equal(res.body.programme.year, 2027);
  assert.equal(res.body.sections.length, 11);
  assert.equal(res.body.progress.completed, 0);
  assert.equal(res.body.progress.total, 11);
  assert.equal(res.body.progress.ratio, 0);
});

test('the daily diet exposes every canonical section with its behaviour', async () => {
  const res = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));

  const byKey = Object.fromEntries(
    res.body.sections.map((s) => [s.key, s])
  );

  assert.deepEqual(
    Object.keys(byKey).sort(),
    [
      'audio_message',
      'bible_study',
      'declarations',
      'fasting_and_prayer',
      'literature_reading',
      'music',
      'prayer',
      'prayer_partner_session',
      'proverbs_reading',
      'report',
      'scripture_reading',
    ]
  );

  assert.equal(byKey.prayer.behaviour, 'TIMER');
  assert.equal(byKey.scripture_reading.behaviour, 'TEXT');
  assert.equal(byKey.bible_study.behaviour, 'TEXT');
  assert.equal(byKey.literature_reading.behaviour, 'MATERIAL');
  assert.equal(byKey.proverbs_reading.behaviour, 'TEXT');
  assert.equal(byKey.fasting_and_prayer.behaviour, 'TICK');
  assert.equal(byKey.report.behaviour, 'REPORT');
  assert.equal(byKey.declarations.behaviour, 'TEXT');
  assert.equal(byKey.audio_message.behaviour, 'MATERIAL');
  assert.equal(byKey.prayer_partner_session.behaviour, 'PARTNER');
  assert.equal(byKey.music.behaviour, 'MATERIAL');
});

test("the day's scripture reading and bible-study content are attached", async () => {
  const res = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));

  const byKey = Object.fromEntries(
    res.body.sections.map((s) => [s.key, s])
  );

  const scripture = byKey.scripture_reading;
  assert.ok(scripture.content, 'scripture reading should carry content');
  assert.equal(scripture.content.scope, 'DAY');
  assert.ok(scripture.content.title.length > 0);
  assert.ok(scripture.content.details.reading, 'a reading should be listed');

  const study = byKey.bible_study;
  assert.ok(study.content, 'bible study should carry content');
  assert.ok(study.content.details.topic, 'a study topic should be listed');
  assert.ok(Array.isArray(study.content.details.teachings));
  assert.ok(study.content.details.teachings.length > 0);
});

test('the daily diet requires authentication', async () => {
  const res = await api().get(`/api/v1/daily-diet?date=${DATE}`);
  assert.equal(res.status, 401);
});

// ------------------------------------------------------------------ tick-offs

test('a member can tick a section off and the progress follows', async () => {
  const before = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));
  const section = before.body.sections.find((s) => s.key === 'scripture_reading');

  const res = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({
      sectionId: section.id,
      date: DATE,
      status: 'COMPLETED',
    });

  assert.equal(res.status, 201);
  assert.equal(res.body.completion.status, 'COMPLETED');
  assert.ok(res.body.completion.id);
  assert.equal(res.body.completion.sectionId, section.id);

  const after = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));
  assert.equal(after.body.progress.completed, 1);
  assert.equal(after.body.progress.ratio, 1 / 11);

  const updated = after.body.sections.find((s) => s.key === 'scripture_reading');
  assert.equal(updated.isCompleted, true);
  assert.equal(updated.status, 'COMPLETED');
  assert.equal(updated.completion.status, 'COMPLETED');
});

test('a member can record how long they prayed', async () => {
  const res = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({
      sectionKey: 'prayer',
      date: DATE,
      status: 'COMPLETED',
      actualDurationMinutes: 45,
    });

  assert.equal(res.status, 201);
  assert.equal(res.body.completion.actualDurationMinutes, 45);
});

test('a member can attach a note to their tick-off', async () => {
  const res = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({
      sectionKey: 'fasting_and_prayer',
      date: DATE,
      status: 'COMPLETED',
      note: 'Fasted from 6am to 3pm.',
    });

  assert.equal(res.status, 201);
  assert.equal(res.body.completion.note, 'Fasted from 6am to 3pm.');
});

test('an invalid status is rejected', async () => {
  const res = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({
      sectionKey: 'prayer',
      date: DATE,
      status: 'ALMOST_DONE',
    });

  assert.equal(res.status, 400);
});

test('a member cannot clear somebody else\'s tick-off', async () => {
  const mine = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({ sectionKey: 'music', date: DATE, status: 'COMPLETED' });

  const res = await api()
    .delete(`/api/v1/daily-diet/completions/${mine.body.completion.id}`)
    .set(bearer(otherToken));

  assert.equal(res.status, 403);
});

test('a member can clear their own tick-off', async () => {
  const mine = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({ sectionKey: 'music', date: DATE, status: 'COMPLETED' });

  const res = await api()
    .delete(`/api/v1/daily-diet/completions/${mine.body.completion.id}`)
    .set(bearer(memberToken));

  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);

  const row = await prisma.dailyDietCompletion.findUnique({
    where: { id: mine.body.completion.id },
  });
  assert.equal(row, null);
});

test('GET /daily-diet/progress reports the days the member completed', async () => {
  const res = await api()
    .get('/api/v1/daily-diet/progress?from=2027-03-01&to=2027-03-31')
    .set(bearer(memberToken));

  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body.data));
  const day = res.body.data.find((d) => d.date === DATE);
  assert.ok(day, 'the day should appear in the progress list');
  assert.equal(day.completed, 3);
  assert.equal(res.body.meta.totalSections, 11);
});

test('progress is private to the member', async () => {
  const res = await api()
    .get('/api/v1/daily-diet/progress?from=2027-03-01&to=2027-03-31')
    .set(bearer(otherToken));

  assert.equal(res.status, 200);
  const day = res.body.data.find((d) => d.date === DATE);
  assert.equal(day, undefined);
});

// ------------------------------------------------------------------- admin

test('a member cannot reach the admin daily diet routes', async () => {
  const res = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(memberToken));

  assert.equal(res.status, 403);
});

test('an admin can list, add and publish sections', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));

  assert.equal(list.status, 200);
  assert.equal(list.body.data.length, 11);

  const created = await api()
    .post('/api/v1/admin/daily-diet/sections')
    .set(bearer(adminToken))
    .send({
      year: 2027,
      key: 'family_altar',
      label: 'Family altar',
      behaviour: 'TICK',
      status: 'DRAFT',
    });

  assert.equal(created.status, 201);
  assert.equal(created.body.section.key, 'family_altar');
  assert.equal(created.body.section.status, 'DRAFT');

  const published = await api()
    .post(`/api/v1/admin/daily-diet/sections/${created.body.section.id}/publish`)
    .set(bearer(adminToken));

  assert.equal(published.status, 200);
  assert.equal(published.body.section.status, 'PUBLISHED');

  // A published, enabled section shows up for members.
  const member = await api()
    .get(`/api/v1/daily-diet?date=${DATE}`)
    .set(bearer(memberToken));
  assert.equal(member.body.sections.length, 12);
  assert.ok(member.body.sections.some((s) => s.key === 'family_altar'));

  // ...and can be archived again.
  const archived = await api()
    .post(`/api/v1/admin/daily-diet/sections/${created.body.section.id}/archive`)
    .set(bearer(adminToken));

  assert.equal(archived.status, 200);
  assert.equal(archived.body.section.status, 'ARCHIVED');
});

test('an admin can rename a section', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'prayer');

  const res = await api()
    .patch(`/api/v1/admin/daily-diet/sections/${section.id}`)
    .set(bearer(adminToken))
    .send({ label: 'Prayer & Meditation' });

  assert.equal(res.status, 200);
  assert.equal(res.body.section.label, 'Prayer & Meditation');
});

test('an admin can reorder the sections', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const ids = list.body.data.map((s) => s.id);
  const reversed = [...ids].reverse();

  const res = await api()
    .post('/api/v1/admin/daily-diet/sections/reorder')
    .set(bearer(adminToken))
    .send({ programmeId: programme.id, order: reversed });

  assert.equal(res.status, 200);

  const after = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  assert.deepEqual(after.body.data.map((s) => s.id), reversed);

  // Put the original order back so later assertions stay predictable.
  await api()
    .post('/api/v1/admin/daily-diet/sections/reorder')
    .set(bearer(adminToken))
    .send({ programmeId: programme.id, order: ids });
});

test('an admin can write the content a section carries on a day', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'declarations');

  const res = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-06-01',
      scope: 'DAY',
      title: 'Declarations for 1 June',
      body: 'Speak these out loud.',
      details: { declarations: ['I am fearfully and wonderfully made.', 'I am free.'] },
      status: 'PUBLISHED',
    });

  assert.equal(res.status, 200);
  assert.equal(res.body.content.scope, 'DAY');
  assert.equal(res.body.content.status, 'PUBLISHED');
  assert.equal(res.body.content.details.declarations.length, 2);

  const member = await api()
    .get('/api/v1/daily-diet?date=2027-06-01')
    .set(bearer(memberToken));
  const published = member.body.sections.find((s) => s.key === 'declarations');
  assert.equal(published.content.title, 'Declarations for 1 June');
  assert.equal(published.content.details.declarations.length, 2);
});

test('a week-scoped content row applies to every day of that week', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'music');

  // 2027-06-09 is a Wednesday; the week anchor starts on Sunday 2027-06-06.
  const res = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionKey: 'music',
      date: '2027-06-09',
      scope: 'WEEK',
      title: 'Songs for the week',
      details: { songs: ['Great is Thy Faithfulness', 'Amazing Grace'] },
      status: 'PUBLISHED',
    });
  assert.equal(res.status, 200);
  assert.equal(res.body.content.scope, 'WEEK');
  // The row is filed against the Sunday that starts the week.
  assert.equal(res.body.content.date, '2027-06-06');

  for (const day of ['2027-06-06', '2027-06-09', '2027-06-12']) {
    const member = await api()
      .get(`/api/v1/daily-diet?date=${day}`)
      .set(bearer(memberToken));
    const music = member.body.sections.find((s) => s.key === 'music');
    assert.equal(
      music.content.title,
      'Songs for the week',
      `the week content should apply on ${day}`
    );
  }

  // The admin's day listing shows the week row that covers the day.
  const listForDay = await api()
    .get('/api/v1/admin/daily-diet/content?date=2027-06-09')
    .set(bearer(adminToken));
  const row = listForDay.body.data.find(
    (c) => c.title === 'Songs for the week'
  );
  assert.ok(row, 'the week row should be listed for the day');
  assert.equal(row.scope, 'WEEK');
  assert.equal(row.date, '2027-06-06');
});

test('a month-scoped content row is filed against the first of the month', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'music');

  const res = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-08-19',
      scope: 'MONTH',
      title: 'August songs',
      status: 'PUBLISHED',
    });

  assert.equal(res.status, 200);
  assert.equal(res.body.content.scope, 'MONTH');
  assert.equal(res.body.content.date, '2027-08-01');

  for (const day of ['2027-08-01', '2027-08-19', '2027-08-31']) {
    const member = await api()
      .get(`/api/v1/daily-diet?date=${day}`)
      .set(bearer(memberToken));
    const music = member.body.sections.find((s) => s.key === 'music');
    assert.equal(
      music.content.title,
      'August songs',
      `the month content should apply on ${day}`
    );
  }
});

test('changing a row\'s scope moves it to the new period anchor', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'music');

  const created = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-12-15',
      scope: 'DAY',
      title: 'A daily message',
      status: 'DRAFT',
    });
  assert.equal(created.body.content.date, '2027-12-15');

  const res = await api()
    .patch(`/api/v1/admin/daily-diet/content/${created.body.content.id}`)
    .set(bearer(adminToken))
    .send({ scope: 'MONTH', status: 'PUBLISHED' });

  assert.equal(res.status, 200);
  assert.equal(res.body.content.scope, 'MONTH');
  assert.equal(res.body.content.date, '2027-12-01');
  assert.equal(res.body.content.status, 'PUBLISHED');

  const member = await api()
    .get('/api/v1/daily-diet?date=2027-12-20')
    .set(bearer(memberToken));
  const music = member.body.sections.find((s) => s.key === 'music');
  assert.equal(music.content.title, 'A daily message');
});

test('moving a row onto a period that is already filled is refused', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'music');

  const first = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-11-10',
      scope: 'DAY',
      title: 'First song of the week',
      status: 'DRAFT',
    });
  assert.equal(first.status, 200);

  const promoted = await api()
    .patch(`/api/v1/admin/daily-diet/content/${first.body.content.id}`)
    .set(bearer(adminToken))
    .send({ scope: 'WEEK' });
  assert.equal(promoted.status, 200);

  const second = await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-11-12',
      scope: 'DAY',
      title: 'A second song that week',
      status: 'DRAFT',
    });
  assert.equal(second.status, 200);

  const res = await api()
    .patch(`/api/v1/admin/daily-diet/content/${second.body.content.id}`)
    .set(bearer(adminToken))
    .send({ scope: 'WEEK' });

  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'DUPLICATE_CONTENT');
});

test('the closest scope wins when a day overrides its week', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'music');

  await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-06-09',
      scope: 'DAY',
      title: 'A special song for today',
      status: 'PUBLISHED',
    });

  const member = await api()
    .get('/api/v1/daily-diet?date=2027-06-09')
    .set(bearer(memberToken));
  const music = member.body.sections.find((s) => s.key === 'music');
  assert.equal(music.content.title, 'A special song for today');
  assert.equal(music.content.scope, 'DAY');
});

test('an admin can publish a whole day at once', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/sections?year=2027')
    .set(bearer(adminToken));
  const section = list.body.data.find((s) => s.key === 'prayer');

  await api()
    .put('/api/v1/admin/daily-diet/content')
    .set(bearer(adminToken))
    .send({
      sectionId: section.id,
      date: '2027-07-04',
      scope: 'DAY',
      title: 'Prayer direction',
      status: 'DRAFT',
    });

  const res = await api()
    .post('/api/v1/admin/daily-diet/content/publish-day')
    .set(bearer(adminToken))
    .send({ date: '2027-07-04' });

  assert.equal(res.status, 200);
  assert.ok(res.body.published >= 1);
  assert.equal(res.body.date, '2027-07-04');

  const member = await api()
    .get('/api/v1/daily-diet?date=2027-07-04')
    .set(bearer(memberToken));
  const prayer = member.body.sections.find((s) => s.key === 'prayer');
  assert.equal(prayer.content.title, 'Prayer direction');
});

test('an admin can delete a content row', async () => {
  const list = await api()
    .get('/api/v1/admin/daily-diet/content?date=2027-06-01')
    .set(bearer(adminToken));
  const row = list.body.data.find((c) => c.title === 'Declarations for 1 June');

  const res = await api()
    .delete(`/api/v1/admin/daily-diet/content/${row.id}`)
    .set(bearer(adminToken));

  assert.equal(res.status, 200);
  const after = await api()
    .get('/api/v1/admin/daily-diet/content?date=2027-06-01')
    .set(bearer(adminToken));
  assert.equal(
    after.body.data.find((c) => c.id === row.id),
    undefined
  );
});
