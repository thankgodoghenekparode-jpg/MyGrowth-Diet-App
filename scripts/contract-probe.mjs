#!/usr/bin/env node
/**
 * Contract probe: logs in as a seeded member + admin and dumps the response
 * shape (keys + a sample value) for the endpoints the Flutter client consumes.
 * Read-only. Used to compare the backend wire contract against the Flutter models.
 */
const BASE = process.env.PROBE_API || 'http://localhost:4000/api/v1';
const MEMBER = { email: 'grace.member@mygrowth.dev', password: 'MyGrowth!Dev2027' };
const ADMIN = { email: 'mainadmin@mygrowth.dev', password: 'MyGrowth!Dev2027' };

async function post(path, body, token) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, json };
}

async function get(path, token) {
  const res = await fetch(BASE + path, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, json };
}

function describe(label, value) {
  const seen = (v, depth = 0) => {
    if (v === null) return 'null';
    if (Array.isArray(v)) {
      return `Array(${v.length})` + (v.length && depth < 2 ? ` of ${typeof v[0]}${depth < 1 ? ' ' + JSON.stringify(firstKeys(v[0])) : ''}` : '');
    }
    if (typeof v === 'object') return `Object ${JSON.stringify(firstKeys(v, depth))}`;
    if (typeof v === 'string') return `string(${v.length})`;
    return typeof v;
  };
  const line = `  ${label}: ${seen(value)}`;
  console.log(line);
}

function firstKeys(obj, depth = 0) {
  if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) return obj;
  const out = {};
  for (const k of Object.keys(obj).slice(0, 40)) {
    const v = obj[k];
    if (v === null || typeof v !== 'object') out[k] = typeof v === 'string' ? `<${String(v).slice(0, 24)}>` : v;
    else if (Array.isArray(v)) out[k] = `[${v.length}]`;
    else out[k] = depth > 0 ? '{...}' : firstKeys(v, depth + 1);
  }
  return out;
}

function show(title, r) {
  console.log(`\n### ${title}  -> HTTP ${r.status}`);
  if (r.json === null) { console.log('  (no JSON)'); return; }
  if (typeof r.json === 'object' && !Array.isArray(r.json)) {
    for (const k of Object.keys(r.json)) describe(k, r.json[k]);
  } else {
    describe('(root)', r.json);
  }
}

const lr = await post('/auth/login', MEMBER);
console.log(`MEMBER login -> ${lr.status}`);
if (lr.status !== 200) { console.log(JSON.stringify(lr.json)); process.exit(1); }
const mt = lr.json.accessToken;
const ar = await post('/auth/login', ADMIN);
const at = ar.json?.accessToken;

const today = new Date().toISOString().slice(0, 10);
const calls = [
  ['GET /me', () => get('/me', mt)],
  ['GET /me/dashboard', () => get('/me/dashboard', mt)],
  ['GET /me/progress', () => get('/me/progress', mt)],
  ['GET /programmes', () => get('/programmes', mt)],
  ['GET /programmes/2027/monthly-plans', () => get('/programmes/2027/monthly-plans', mt)],
  [`GET /me/activities?date=${today}`, () => get(`/me/activities?date=${today}`, mt)],
  ['GET /me/goals', () => get('/me/goals', mt)],
  ['GET /me/reports?type=WEEKLY', () => get('/me/reports?type=WEEKLY', mt)],
  ['GET /me/reflections', () => get('/me/reflections', mt)],
  ['GET /me/testimonies', () => get('/me/testimonies', mt)],
  ['GET /me/notifications', () => get('/me/notifications', mt)],
  ['GET /me/notification-preferences', () => get('/me/notification-preferences', mt)],
  ['GET /announcements', () => get('/announcements', mt)],
  ['GET /materials', () => get('/materials', mt)],
  ['GET /prayer-partners/discover', () => get('/prayer-partners/discover', mt)],
];
for (const [t, fn] of calls) show(t, await fn());

if (at) {
  show('ADMIN GET /admin/analytics/overview', await get('/admin/analytics/overview', at));
  show('ADMIN GET /admin/members', await get('/admin/members', at));
  show('ADMIN GET /admin/reports', await get('/admin/reports', at));
}
