#!/usr/bin/env node
/**
 * Contract probe #3 — the remaining member/admin endpoints the Flutter client
 * calls that probe1/probe2 do not cover. Read-only apart from harmless dev
 * records. Dumps response shapes so they can be compared with the Flutter
 * models.
 */
const BASE = process.env.PROBE_API || 'http://localhost:4000/api/v1';
const ADMIN = { email: 'mainadmin@mygrowth.dev', password: 'MyGrowth!Dev2027' };
const MEMBER = { email: 'grace.member@mygrowth.dev', password: 'MyGrowth!Dev2027' };

async function req(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, json };
}
const keysOf = (v) => {
  if (Array.isArray(v)) return `Array(${v.length})${v[0] && typeof v[0] === 'object' ? ' → ' + Object.keys(v[0]).join(',') : ''}`;
  if (v && typeof v === 'object') return Object.keys(v).join(',');
  return typeof v;
};
function show(label, r) {
  const note = r.status >= 400 ? `  <-- HTTP ${r.status} ${JSON.stringify(r.json)?.slice(0, 160)}` : '';
  console.log(`\n### ${label} -> ${r.status}${note}`);
  if (r.json && typeof r.json === 'object') for (const [k, v] of Object.entries(r.json)) console.log(`   ${k}: ${keysOf(v)}`);
}

const a = await req('POST', '/auth/login', { body: ADMIN });
const m = await req('POST', '/auth/login', { body: MEMBER });
if (a.status !== 200 || m.status !== 200) { console.log('login failed', a.status, m.status); process.exit(1); }
const at = a.json.accessToken, mt = m.json.accessToken;

// ---- member identity surfaces
show('GET /prayer-partners/availability', await req('GET', '/prayer-partners/availability', { token: mt }));
show('GET /prayer-partners/partnerships', await req('GET', '/prayer-partners/partnerships', { token: mt }));
show('GET /me/goals', await req('GET', '/me/goals', { token: mt }));
show('GET /me/report-fields', await req('GET', '/me/report-fields', { token: mt }));
show('GET /me/reports-status/current', await req('GET', '/me/reports-status/current', { token: mt }));
show('GET /me/annual-letter', await req('GET', '/me/annual-letter', { token: mt }));
show('GET /me/reading-list', await req('GET', '/me/reading-list', { token: mt }));
show('GET /me/testimonies', await req('GET', '/me/testimonies', { token: mt }));
show('GET /me/notifications', await req('GET', '/me/notifications', { token: mt }));
show('GET /me/activity-records', await req('GET', '/me/activity-records', { token: mt }));

// ---- testimonies create with the Flutter body
show('POST /me/testimonies', await req('POST', '/me/testimonies', {
  token: mt,
  body: { title: `Probe testimony ${Date.now()}`, body: 'God is faithful.', consentToShare: true },
}));

// ---- admin member detail (real path is /admin/users/:id)
const users = await req('GET', '/admin/users?page=1&pageSize=1', { token: at });
const uid = users.json?.data?.[0]?.id;
if (uid) show(`GET /admin/users/:id (${uid})`, await req('GET', `/admin/users/${uid}`, { token: at }));

// ---- admin analytics overview keys
show('GET /admin/analytics/overview', await req('GET', '/admin/analytics/overview', { token: at }));
show('GET /admin/audit-logs', await req('GET', '/admin/audit-logs?page=1&pageSize=3', { token: at }));
