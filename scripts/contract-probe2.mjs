#!/usr/bin/env node
/**
 * Contract probe #2 — exercises the authoring flows the smoke test does not
 * cover (weekly plans, daily activities, materials, announcements, reflections,
 * notification-preferences save) using the EXACT request bodies the Flutter
 * screens send, then dumps the responses the Flutter models must parse.
 *
 * Read-only except for the records it creates (they are clearly labelled and
 * harmless in a dev database). Safe to re-run.
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
  if (r.json && typeof r.json === 'object') {
    for (const [k, v] of Object.entries(r.json)) console.log(`   ${k}: ${keysOf(v)}`);
  }
}
const id = (r, key) => r.json?.[key]?.id ?? r.json?.id ?? r.json?.data?.id;

const a = await req('POST', '/auth/login', { body: ADMIN });
const m = await req('POST', '/auth/login', { body: MEMBER });
if (a.status !== 200 || m.status !== 200) { console.log('login failed', a.status, m.status); process.exit(1); }
const at = a.json.accessToken, mt = m.json.accessToken;

// --- resolve the 2027 programme id
const programmes = await req('GET', '/admin/programmes', { token: at });
const prog = (programmes.json?.data ?? []).find((p) => p.year === 2027) ?? programmes.json?.data?.[0];
console.log('programme id:', prog?.id, 'status:', prog?.status);

// --- Flutter ProgressSummary shape
show('GET /me/progress?period=all', await req('GET', '/me/progress?period=all', { token: mt }));

// --- admin activity definitions (primary 404s; fallback must work)
show('GET /admin/activity-definitions (primary)', await req('GET', '/admin/activity-definitions?page=1&pageSize=20', { token: at }));
show('GET /admin/activities (fallback)', await req('GET', '/admin/activities?page=1&pageSize=20', { token: at }));

// --- weekly plans (member list endpoint used by weeklyPlansProvider)
show('GET /programmes/weekly-plans?year=2027&month=1', await req('GET', '/programmes/weekly-plans?year=2027&month=1', { token: mt }));

// --- create a weekly plan with the Flutter body
const wp = await req('POST', `/admin/programmes/${prog.id}/weekly-plans`, {
  token: at,
  body: {
    weekNumber: 1, month: 1,
    bibleReading: 'Matthew 1-7', prayerDurationTargetMinutes: 30,
    bookReading: 'The Father and His Family', fastingSchedule: 'Wednesday',
    keyLessonPrompt: 'What does sonship mean to you?', memoryVerse: 'John 1:12',
    extraActivities: ['Journal one page'], startDate: '2027-01-01', endDate: '2027-01-07',
  },
});
show('POST /admin/programmes/:id/weekly-plans (Flutter body)', wp);
const wpId = id(wp, 'weeklyPlan') ?? (await req('GET', `/admin/weekly-plans?year=2027&month=1`, { token: at })).json?.data?.[0]?.id;
if (wpId) show('POST /admin/weekly-plans/:id/publish', await req('POST', `/admin/weekly-plans/${wpId}/publish`, { token: at }));

// --- member weekly list now (should parse into WeeklyPlan)
show('GET /programmes/weekly-plans?year=2027&month=1 (after create)', await req('GET', '/programmes/weekly-plans?year=2027&month=1', { token: mt }));

// --- create a daily activity with the Flutter body
const da = await req('POST', `/admin/programmes/${prog.id}/daily-activities`, {
  token: at,
  body: {
    title: 'Probe daily prayer', category: 'prayer', description: 'Probe activity',
    month: 1, date: '2027-01-02', startTime: '06:00', durationMinutes: 20, trackCompletion: true,
  },
});
show('POST /admin/programmes/:id/daily-activities (Flutter body)', da);
const daId = id(da, 'dailyActivity');
if (daId) show('POST /admin/daily-activities/:id/publish', await req('POST', `/admin/daily-activities/${daId}/publish`, { token: at }));

// --- member checklist for that date (the `data` alias dailyChecklistProvider reads)
show('GET /me/activities?date=2027-01-02', await req('GET', '/me/activities?date=2027-01-02', { token: mt }));

// --- material create with the Flutter admin body
const mat = await req('POST', '/admin/materials', {
  token: at,
  body: {
    title: `Probe material ${Date.now()}`, category: 'PRAYER_GUIDE', description: 'Probe',
    authorSpeaker: 'Healings E. Azuike', programmeYear: 2027, month: 1,
    externalUrl: 'https://example.com/probe', visibility: 'ALL_MEMBERS', trackCompletion: true,
  },
});
show('POST /admin/materials (Flutter body)', mat);
const matId = id(mat, 'material');
if (matId) show('POST /admin/materials/:id/publish', await req('POST', `/admin/materials/${matId}/publish`, { token: at }));
show('GET /admin/materials', await req('GET', '/admin/materials', { token: at }));
show('GET /materials (member)', await req('GET', '/materials', { token: mt }));

// --- announcement create with the Flutter admin body
const ann = await req('POST', '/admin/announcements', {
  token: at,
  body: { title: `Probe announcement ${Date.now()}`, body: 'Probe body', audience: 'ALL_MEMBERS', link: null, startsAt: '2027-01-01T00:00:00.000Z', endsAt: '2027-12-31T23:59:59.000Z' },
});
show('POST /admin/announcements (Flutter body)', ann);
const annId = id(ann, 'announcement');
if (annId) show('POST /admin/announcements/:id/publish', await req('POST', `/admin/announcements/${annId}/publish`, { token: at }));
show('GET /admin/announcements', await req('GET', '/admin/announcements', { token: at }));
show('GET /announcements (member)', await req('GET', '/announcements', { token: mt }));

// --- reflection create with the Flutter body
const refl = await req('POST', '/me/reflections', {
  token: mt,
  body: { title: `Probe reflection ${Date.now()}`, body: 'Probe reflection body', entryDate: '2027-01-03' },
});
show('POST /me/reflections (Flutter body)', refl);
show('GET /me/reflections (after create)', await req('GET', '/me/reflections', { token: mt }));

// --- notification preferences save (Flutter sends PUT with these keys)
const prefsBody = {
  emailEnabled: true, dailyReminderEnabled: true, dailyReminderTime: '06:00',
  weeklyReportReminder: true, monthlyReportReminder: true, sessionReminders: true,
  sessionReminderMinutes: 30, timeZone: 'Africa/Lagos', summaryFrequency: 'WEEKLY',
};
show('PUT /me/notification-preferences (Flutter body)', await req('PUT', '/me/notification-preferences', { token: mt, body: prefsBody }));
show('PATCH /me/notification-preferences (Flutter body)', await req('PATCH', '/me/notification-preferences', { token: mt, body: prefsBody }));
show('GET /me/notification-preferences (after save)', await req('GET', '/me/notification-preferences', { token: mt }));

// --- admin access management (Main Admin only) + settings + audit
show('GET /admin/admins', await req('GET', '/admin/admins', { token: at }));
show('GET /admin/settings', await req('GET', '/admin/settings', { token: at }));
show('GET /admin/activity-categories', await req('GET', '/admin/activity-categories', { token: at }));
show('GET /admin/activity-definitions', await req('GET', '/admin/activity-definitions', { token: at }));
show('GET /admin/prayer-partnerships', await req('GET', '/admin/prayer-partnerships', { token: at }));
show('GET /admin/safety-reports', await req('GET', '/admin/safety-reports', { token: at }));
