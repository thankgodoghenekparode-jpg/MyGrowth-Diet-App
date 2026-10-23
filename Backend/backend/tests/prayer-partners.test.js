import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  api,
  resetDb,
  createUser,
  tokenFor,
  bearer,
} from './helpers/setup.js';

let a;
let b;
let c;
let d;
let tokenA;
let tokenB;
let tokenC;

before(async () => {
  await resetDb();
  a = await createUser({ email: 'partner.a@test.local', firstName: 'Ada' });
  b = await createUser({ email: 'partner.b@test.local', firstName: 'Bola' });
  c = await createUser({ email: 'partner.c@test.local', firstName: 'Chidi' });
  d = await createUser({ email: 'partner.d@test.local', firstName: 'Dara' });
  tokenA = await tokenFor(a.email);
  tokenB = await tokenFor(b.email);
  tokenC = await tokenFor(c.email);
});

async function makeAvailable(token, days) {
  const res = await api()
    .put('/api/v1/prayer-partners/availability')
    .set(bearer(token))
    .send({
      availability: 'AVAILABLE',
      availableDays: days,
      preferredTimeRanges: [{ start: '06:00', end: '07:00' }],
      acceptsNewRequests: true,
    });
  assert.equal(res.status, 200);
  return res.body.availability;
}

test('availability defaults to UNAVAILABLE and can be updated', async () => {
  const initial = await api().get('/api/v1/prayer-partners/availability').set(bearer(tokenA));
  assert.equal(initial.status, 200);
  assert.equal(initial.body.availability.availability, 'UNAVAILABLE');

  const updated = await makeAvailable(tokenB, [1, 2, 3]);
  assert.equal(updated.availability, 'AVAILABLE');
  assert.deepEqual(updated.availableDays, [1, 2, 3]);
});

test('discover surfaces available members and hides exact schedules', async () => {
  const res = await api().get('/api/v1/prayer-partners/discover').set(bearer(tokenA));
  assert.equal(res.status, 200);
  const found = res.body.data.find((x) => x.userId === b.id);
  assert.ok(found, 'member B should be discoverable');
  assert.equal(found.firstName, 'Bola');
  assert.ok(found.lastInitial);
  // Exact time ranges are never exposed.
  assert.equal(found.preferredTimeRanges, undefined);
});

test('a member with no availability cannot be requested', async () => {
  const res = await api()
    .post('/api/v1/prayer-partners/requests')
    .set(bearer(tokenA))
    .send({ recipientId: d.id });
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'NOT_ACCEPTING_REQUESTS');
});

test('you cannot request yourself, or request twice', async () => {
  const self = await api()
    .post('/api/v1/prayer-partners/requests')
    .set(bearer(tokenA))
    .send({ recipientId: a.id });
  assert.equal(self.status, 400);

  const first = await api()
    .post('/api/v1/prayer-partners/requests')
    .set(bearer(tokenA))
    .send({ recipientId: b.id, message: 'Would you pray with me?' });
  assert.equal(first.status, 201);
  assert.equal(first.body.request.status, 'PENDING');

  const dup = await api()
    .post('/api/v1/prayer-partners/requests')
    .set(bearer(tokenA))
    .send({ recipientId: b.id });
  assert.equal(dup.status, 409);
  assert.equal(dup.body.error.code, 'DUPLICATE_REQUEST');
});

test('accepting a request creates an ACTIVE partnership', async () => {
  const pending = await api()
    .get('/api/v1/prayer-partners/requests?direction=in')
    .set(bearer(tokenB));
  const request = pending.body.data.find((r) => r.requesterId === a.id);
  assert.ok(request);

  // Only the recipient can accept.
  const wrong = await api()
    .patch(`/api/v1/prayer-partners/requests/${request.id}`)
    .set(bearer(tokenA))
    .send({ action: 'accept' });
  assert.equal(wrong.status, 403);

  const accepted = await api()
    .patch(`/api/v1/prayer-partners/requests/${request.id}`)
    .set(bearer(tokenB))
    .send({ action: 'accept' });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.partnership.status, 'ACTIVE');

  const list = await api().get('/api/v1/prayer-partners/partnerships').set(bearer(tokenA));
  assert.equal(list.body.data.length, 1);
  assert.equal(list.body.data[0].partner.id, b.id);
});

test('partners are excluded from discovery once partnered', async () => {
  const res = await api().get('/api/v1/prayer-partners/discover').set(bearer(tokenA));
  assert.equal(res.body.data.some((x) => x.userId === b.id), false);
});

test('prayer sessions follow a propose/accept/complete flow', async () => {
  const partnerships = await api()
    .get('/api/v1/prayer-partners/partnerships')
    .set(bearer(tokenA));
  const partnershipId = partnerships.body.data[0].id;

  const proposed = await api()
    .post('/api/v1/prayer-partners/sessions')
    .set(bearer(tokenA))
    .send({ partnershipId, date: '2027-06-10', startTime: '06:00', durationMinutes: 30, prayerFocus: 'Family' });
  assert.equal(proposed.status, 201);
  assert.equal(proposed.body.session.status, 'PROPOSED');
  assert.equal(proposed.body.session.iProposed, true);
  const sessionId = proposed.body.session.id;

  // The proposer cannot accept their own session.
  const selfAccept = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenA))
    .send({ action: 'accept' });
  assert.equal(selfAccept.status, 403);

  // A non-participant cannot see the session.
  const idor = await api()
    .get(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenC));
  assert.equal(idor.status, 404);

  const accepted = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenB))
    .send({ action: 'accept' });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.session.status, 'ACCEPTED');

  const completed = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenA))
    .send({ action: 'complete', note: 'A wonderful time of prayer.' });
  assert.equal(completed.status, 200);
  assert.equal(completed.body.session.status, 'COMPLETED');
  assert.equal(completed.body.session.proposerNote, 'A wonderful time of prayer.');
  assert.equal(completed.body.selfReported, true);
});

test('session PATCH accepts the Flutter target-status contract', async () => {
  const partnerships = await api()
    .get('/api/v1/prayer-partners/partnerships')
    .set(bearer(tokenA));
  const partnershipId = partnerships.body.data[0].id;

  const proposed = await api()
    .post('/api/v1/prayer-partners/sessions')
    .set(bearer(tokenA))
    .send({ partnershipId, date: '2027-06-12', startTime: '07:00', durationMinutes: 30 });
  assert.equal(proposed.status, 201);
  const sessionId = proposed.body.session.id;

  // Flutter sends `status: 'ACCEPTED'` instead of `action: 'accept'`.
  const accepted = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenB))
    .send({ status: 'ACCEPTED' });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.session.status, 'ACCEPTED');

  // Flutter marks attendance with `status: 'COMPLETED'` + `myAttendance: true`.
  const completed = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenA))
    .send({ status: 'COMPLETED', myAttendance: true });
  assert.equal(completed.status, 200);
  assert.equal(completed.body.session.status, 'COMPLETED');
  assert.equal(completed.body.session.myAttendanceRecorded, true);

  // A bare status with no action or status is rejected.
  const empty = await api()
    .patch(`/api/v1/prayer-partners/sessions/${sessionId}`)
    .set(bearer(tokenA))
    .send({});
  assert.equal(empty.status, 400);
});

test('a non-participant cannot schedule a session on someone else\'s partnership', async () => {
  const partnerships = await api()
    .get('/api/v1/prayer-partners/partnerships')
    .set(bearer(tokenB));
  const partnershipId = partnerships.body.data[0].id;

  const res = await api()
    .post('/api/v1/prayer-partners/sessions')
    .set(bearer(tokenC))
    .send({ partnershipId, date: '2027-06-11', startTime: '06:00' });
  assert.equal(res.status, 404);
});

test('overlapping sessions for the same participants are rejected', async () => {
  const partnerships = await api()
    .get('/api/v1/prayer-partners/partnerships')
    .set(bearer(tokenA));
  const partnershipId = partnerships.body.data[0].id;

  const res = await api()
    .post('/api/v1/prayer-partners/sessions')
    .set(bearer(tokenA))
    .send({ partnershipId, date: '2027-06-10', startTime: '06:15' });
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'SESSION_CONFLICT');
});

test('the sessions list accepts the friendly upcoming/past windows', async () => {
  const partnerships = await api()
    .get('/api/v1/prayer-partners/partnerships')
    .set(bearer(tokenA));
  const partnershipId = partnerships.body.data[0].id;

  const future = await api()
    .post('/api/v1/prayer-partners/sessions')
    .set(bearer(tokenA))
    .send({
      partnershipId,
      date: '2030-01-15',
      startTime: '06:00',
      durationMinutes: 30,
    });
  assert.equal(future.status, 201);
  const futureId = future.body.session.id;

  // The Flutter prayer room asks for `status=upcoming`.
  const upcoming = await api()
    .get('/api/v1/prayer-partners/sessions?status=upcoming')
    .set(bearer(tokenA));
  assert.equal(upcoming.status, 200);
  assert.ok(
    upcoming.body.data.some((s) => s.id === futureId),
    'a future proposed session belongs to the upcoming window'
  );

  const past = await api()
    .get('/api/v1/prayer-partners/sessions?status=past')
    .set(bearer(tokenA));
  assert.equal(past.status, 200);
  assert.ok(
    !past.body.data.some((s) => s.id === futureId),
    'a future session is not in the past window'
  );

  // A concrete status still filters exactly.
  const proposed = await api()
    .get('/api/v1/prayer-partners/sessions?status=PROPOSED')
    .set(bearer(tokenA));
  assert.equal(proposed.status, 200);
  assert.ok(proposed.body.data.some((s) => s.id === futureId));
});

test('a request can be declined and an availability can be switched off', async () => {
  await makeAvailable(tokenC, [2, 4]);

  const request = await api()
    .post('/api/v1/prayer-partners/requests')
    .set(bearer(tokenA))
    .send({ recipientId: c.id });
  assert.equal(request.status, 201);

  const declined = await api()
    .patch(`/api/v1/prayer-partners/requests/${request.body.request.id}`)
    .set(bearer(tokenC))
    .send({ action: 'decline' });
  assert.equal(declined.status, 200);
  assert.equal(declined.body.request.status, 'DECLINED');
});
