import './helpers/env.js';

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { api, resetDb, createUser, tokenFor } from './helpers/setup.js';

beforeEach(async () => {
  await resetDb();
});

test('Shape Space community supports anonymous questions and admin replies', async () => {
  const admin = await createUser({
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
  const adminToken = await tokenFor(admin.email);

  const initial = await api()
    .get('/api/v1/shape-space/questions')
    .set('Authorization', `Bearer ${memberToken}`);
  assert.equal(initial.status, 200);
  assert.deepEqual(initial.body.questions, []);

  const posted = await api()
    .post('/api/v1/shape-space/questions')
    .set('Authorization', `Bearer ${memberToken}`)
    .send({ body: 'Please pray for my family.', isAnonymous: true });
  assert.equal(posted.status, 201);
  assert.equal(posted.body.question.isAnonymous, true);

  const adminList = await api()
    .get('/api/v1/admin/shape-space/conversations')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.equal(adminList.status, 200);
  assert.equal(adminList.body.conversations.length, 1);
  const conversation = adminList.body.conversations[0];
  assert.equal(conversation.isAnonymous, true);
  assert.match(conversation.memberName, /Anonymous Member/);
  assert.equal(conversation.memberEmail, null);

  const reply = await api()
    .post(`/api/v1/admin/shape-space/conversations/${conversation.id}/reply`)
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ body: 'We are standing with you in prayer.' });
  assert.equal(reply.status, 201);
  assert.equal(reply.body.message.isFromAdmin, true);

  const thread = await api()
    .get(`/api/v1/shape-space/questions/${conversation.id}`)
    .set('Authorization', `Bearer ${memberToken}`);
  assert.equal(thread.status, 200);
  assert.equal(thread.body.answers.length, 1);
  assert.equal(thread.body.answers[0].body, 'We are standing with you in prayer.');
});
