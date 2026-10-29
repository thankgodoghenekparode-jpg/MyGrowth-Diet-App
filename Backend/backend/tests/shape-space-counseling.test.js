import './helpers/env.js';

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { api, resetDb, createUser, tokenFor } from './helpers/setup.js';

beforeEach(async () => {
  await resetDb();
});

test('Shape Space: 1-on-1 pastoral counselling and anonymous toggle', async () => {
  const pastor = await createUser({
    firstName: 'Healings',
    lastName: 'Azuike',
    role: 'MAIN_ADMIN',
    adminAccess: 'ACTIVE',
  });
  const member = await createUser({
    firstName: 'Brother',
    lastName: 'John',
    role: 'MEMBER',
  });

  const memberToken = await tokenFor(member.email);
  const pastorToken = await tokenFor(pastor.email);

  // 1. Member loads shape space: initial empty state with auto-created conversation
  const initRes = await api()
    .get('/api/v1/shape-space/messages')
    .set('Authorization', `Bearer ${memberToken}`);

  assert.equal(initRes.status, 200);
  assert.ok(initRes.body.conversation);
  assert.equal(initRes.body.messages.length, 0);

  // 2. Member sends an anonymous message to the Pastor
  const sendRes = await api()
    .post('/api/v1/shape-space/messages')
    .set('Authorization', `Bearer ${memberToken}`)
    .send({
      body: 'Pastor, I have a personal prayer request regarding a family issue.',
      isAnonymous: true,
    });

  assert.equal(sendRes.status, 201);
  assert.equal(sendRes.body.message.isAnonymous, true);

  // 3. Pastor checks pastoral counselling conversations
  const adminListRes = await api()
    .get('/api/v1/admin/shape-space/conversations')
    .set('Authorization', `Bearer ${pastorToken}`);

  assert.equal(adminListRes.status, 200);
  assert.equal(adminListRes.body.conversations.length, 1);
  const conv = adminListRes.body.conversations[0];
  assert.equal(conv.isAnonymous, true);
  assert.ok(conv.memberName.includes('Anonymous Member'));
  assert.equal(conv.memberEmail, null); // Email hidden for anonymity

  // 4. Pastor opens the conversation thread and sends a pastoral reply
  const threadRes = await api()
    .get(`/api/v1/admin/shape-space/conversations/${conv.id}`)
    .set('Authorization', `Bearer ${pastorToken}`);

  assert.equal(threadRes.status, 200);
  assert.equal(threadRes.body.messages.length, 1);

  const replyRes = await api()
    .post(`/api/v1/admin/shape-space/conversations/${conv.id}/reply`)
    .set('Authorization', `Bearer ${pastorToken}`)
    .send({
      body: 'Grace to you, beloved. We are standing with you in prayer. God is working all things out.',
    });

  assert.equal(replyRes.status, 201);
  assert.equal(replyRes.body.message.isFromAdmin, true);

  // 5. Member fetches messages and sees Pastor's reply
  const memberCheckRes = await api()
    .get('/api/v1/shape-space/messages')
    .set('Authorization', `Bearer ${memberToken}`);

  assert.equal(memberCheckRes.status, 200);
  assert.equal(memberCheckRes.body.messages.length, 2);
  const pastorReply = memberCheckRes.body.messages[1];
  assert.equal(pastorReply.isFromAdmin, true);
  assert.equal(pastorReply.senderName, 'Pastor / Spiritual Counselor');
});
