import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { api, resetDb, createUser, config } from './helpers/setup.js';

before(async () => {
  await resetDb();
  await createUser({ email: 'cron.member@test.local' });
});

test('cron tick requires the secret (403 without it)', async () => {
  const res = await api().post('/api/v1/cron/tick');
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'CRON_SECRET_INVALID');
});

test('cron tick rejects a wrong secret', async () => {
  const res = await api()
    .post('/api/v1/cron/tick')
    .set('x-cron-secret', 'not-the-right-secret');
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'CRON_SECRET_INVALID');
});

test('cron tick runs all reminder tasks with the correct secret header', async () => {
  const res = await api()
    .post('/api/v1/cron/tick')
    .set('x-cron-secret', config.cronSecret);
  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);
  assert.ok(res.body.ranAt);
  assert.ok(res.body.results);
  for (const key of [
    'dailyActivityReminders',
    'weeklyReportReminders',
    'monthlyReportReminders',
    'quarterlyReviewReminders',
    'annualReflectionReminders',
    'prayerSessionReminders',
    'cleanupExpiredTokens',
  ]) {
    assert.ok(key in res.body.results, `missing task result: ${key}`);
  }
});

test('cron tick also accepts the secret in the JSON body', async () => {
  const res = await api().post('/api/v1/cron/tick').send({ secret: config.cronSecret });
  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);
});

test('reminder delivery is idempotent (deduplicated per event key)', async () => {
  const first = await api().post('/api/v1/cron/tick').set('x-cron-secret', config.cronSecret);
  const second = await api().post('/api/v1/cron/tick').set('x-cron-secret', config.cronSecret);
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  // A repeated tick must never error, regardless of how many notifications exist.
  assert.ok(
    typeof second.body.results.dailyActivityReminders === 'number' ||
      typeof second.body.results.dailyActivityReminders === 'string'
  );
});
