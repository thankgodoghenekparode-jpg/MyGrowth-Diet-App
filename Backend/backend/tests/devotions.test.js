import './helpers/env.js';

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { api, resetDb, createUser, tokenFor } from './helpers/setup.js';

beforeEach(async () => {
  await resetDb();
});

test('Daily Devotions: Admin bulk-import and member daily reading/completion', async () => {
  const admin = await createUser({
    role: 'ADMIN',
    adminAccess: 'ACTIVE',
  });
  const member = await createUser({
    role: 'MEMBER',
  });

  const adminToken = await tokenFor(admin.email);
  const memberToken = await tokenFor(member.email);

  // 1. Admin bulk-imports daily devotions
  const sampleDevotions = [
    {
      dayOfYear: 1,
      month: 1,
      day: 1,
      title: 'A New Beginning in Christ',
      anchorScripture: '2 Corinthians 5:17',
      scriptureReading: '2 Corinthians 5:14-21',
      scriptureText: 'Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new.',
      content: 'Every new season in God brings fresh grace and renewed strength...',
      confession: 'I am a new creation in Christ, established in righteousness.',
      prayer: 'Lord, guide my steps each day of this year.',
      oneYearBibleReading: 'Genesis 1-3; Matthew 1',
      thoughtForTheDay: 'Your past is gone; God has a glorious future for you.',
    },
  ];

  const importRes = await api()
    .post('/api/v1/admin/devotions/bulk-import')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ devotions: sampleDevotions });

  assert.equal(importRes.status, 200);
  assert.equal(importRes.body.count, 1);

  // 2. Member fetches devotion by dayOfYear
  const getRes = await api()
    .get('/api/v1/devotions?dayOfYear=1')
    .set('Authorization', `Bearer ${memberToken}`);

  assert.equal(getRes.status, 200);
  assert.ok(getRes.body.devotion);
  assert.equal(getRes.body.devotion.title, 'A New Beginning in Christ');
  assert.equal(getRes.body.devotion.isCompleted, false);

  const devotionId = getRes.body.devotion.id;

  // 3. Member marks completion and adds personal reflection note
  const completeRes = await api()
    .post(`/api/v1/devotions/${devotionId}/complete`)
    .set('Authorization', `Bearer ${memberToken}`)
    .send({
      isBookmarked: true,
      reflectionNotes: 'God reminded me today that my past has no power over my future.',
    });

  assert.equal(completeRes.status, 200);
  assert.equal(completeRes.body.completion.isCompleted, true);
  assert.equal(completeRes.body.completion.isBookmarked, true);
  assert.ok(completeRes.body.completion.reflectionNotes.includes('past has no power'));

  // 4. Member checks bookmarks
  const bookmarksRes = await api()
    .get('/api/v1/devotions/user/bookmarks')
    .set('Authorization', `Bearer ${memberToken}`);

  assert.equal(bookmarksRes.status, 200);
  assert.equal(bookmarksRes.body.bookmarks.length, 1);
  assert.equal(bookmarksRes.body.bookmarks[0].id, devotionId);
});
