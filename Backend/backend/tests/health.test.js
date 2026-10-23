import { test } from 'node:test';
import assert from 'node:assert/strict';
import { api } from './helpers/setup.js';

test('GET /api/v1/health reports ok with the database up', async () => {
  const res = await api().get('/api/v1/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
  assert.equal(res.body.db, 'up');
  assert.equal(res.body.service, 'mygrowth-diet-app-backend');
  assert.equal(res.body.env, 'test');
  assert.equal(typeof res.body.uptimeSeconds, 'number');
});

test('GET /health (alias) also responds', async () => {
  const res = await api().get('/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
});

test('unknown routes return a structured 404', async () => {
  const res = await api().get('/api/v1/does-not-exist');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

test('security headers are present (helmet)', async () => {
  const res = await api().get('/api/v1/health');
  assert.ok(res.headers['x-content-type-options']);
  assert.equal(res.headers['x-powered-by'], undefined);
});
