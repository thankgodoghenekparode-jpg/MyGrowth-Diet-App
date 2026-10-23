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
let programme;

const DATE = '2027-03-17';
const REPORT = 'Weekly report\nWhat went well: prayer and fasting.\n';

before(async () => {
  await resetDb();
  await seedBaseline();
  programme = await prisma.programme.findFirst({ where: { year: 2027 } });
  await seedDailyDiet(programme);

  await createUser({ email: 'files.member@test.local' });
  await createUser({ email: 'files.other@test.local' });

  memberToken = await tokenFor('files.member@test.local');
  otherToken = await tokenFor('files.other@test.local');
});

async function upload(token, name = 'weekly-report.txt', body = REPORT) {
  return api()
    .post('/api/v1/files')
    .set(bearer(token))
    .field('category', 'report')
    .attach('file', Buffer.from(body, 'utf8'), {
      filename: name,
      contentType: 'text/plain',
    });
}

test('a member can upload a file', async () => {
  const res = await upload(memberToken);

  assert.equal(res.status, 201);
  assert.equal(res.body.file.originalName, 'weekly-report.txt');
  assert.equal(res.body.file.mimeType, 'text/plain');
  assert.equal(res.body.file.sizeBytes, Buffer.byteLength(REPORT));
  assert.match(res.body.file.url, /^\/api\/v1\/files\/[0-9a-f-]{36}$/);

  // The raw body must never leak the storage key.
  assert.equal(res.body.file.storageKey, undefined);
});

test('the uploader can download their own file', async () => {
  const created = await upload(memberToken);
  const res = await api()
    .get(created.body.file.url)
    .set(bearer(memberToken));

  assert.equal(res.status, 200);
  assert.equal(res.headers['content-type'], 'text/plain');
  assert.equal(res.text, REPORT);
});

test('another member cannot download it', async () => {
  const created = await upload(memberToken);
  const res = await api()
    .get(created.body.file.url)
    .set(bearer(otherToken));

  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'FILE_ACCESS_DENIED');
});

test('another member cannot delete it', async () => {
  const created = await upload(memberToken);
  const res = await api()
    .delete(created.body.file.url)
    .set(bearer(otherToken));

  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'FILE_ACCESS_DENIED');

  // Still there for its owner.
  const still = await api().get(created.body.file.url).set(bearer(memberToken));
  assert.equal(still.status, 200);
});

test('a file attached to a report cannot be deleted', async () => {
  const created = await upload(memberToken);

  const completion = await api()
    .post('/api/v1/daily-diet/completions')
    .set(bearer(memberToken))
    .send({
      sectionKey: 'report',
      date: DATE,
      status: 'COMPLETED',
      note: 'Weekly report attached',
      attachmentFileId: created.body.file.id,
    });
  assert.equal(completion.status, 201);
  assert.equal(
    completion.body.completion.attachment.url,
    created.body.file.url
  );

  const refused = await api()
    .delete(created.body.file.url)
    .set(bearer(memberToken));
  assert.equal(refused.status, 409);
  assert.equal(refused.body.error.code, 'FILE_IN_USE');

  // Clearing the tick-off releases the file.
  await api()
    .delete(`/api/v1/daily-diet/completions/${completion.body.completion.id}`)
    .set(bearer(memberToken));

  const removed = await api()
    .delete(created.body.file.url)
    .set(bearer(memberToken));
  assert.equal(removed.status, 200);
  assert.equal(removed.body.ok, true);

  const gone = await api().get(created.body.file.url).set(bearer(memberToken));
  assert.equal(gone.status, 404);
});

test('the uploader can delete a file they no longer need', async () => {
  const created = await upload(memberToken);

  const res = await api()
    .delete(created.body.file.url)
    .set(bearer(memberToken));

  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);

  const row = await prisma.file.findUnique({
    where: { id: created.body.file.id },
  });
  assert.equal(row, null);
});

test('an unsupported file type is refused', async () => {
  const res = await api()
    .post('/api/v1/files')
    .set(bearer(memberToken))
    .attach('file', Buffer.from('MZ executable'), {
      filename: 'tool.exe',
      contentType: 'application/x-msdownload',
    });

  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'UNSUPPORTED_FILE_TYPE');
});
