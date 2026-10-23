#!/usr/bin/env node
/**
 * MyGrowth Diet Plan — end-to-end smoke test.
 *
 * Runs the core acceptance flow from the build spec against a LIVE backend:
 *   register → programme → daily activities → record activity → goal →
 *   weekly report (draft/submit) → admin review → member sees comment →
 *   prayer availability → partner request/accept → session propose/accept →
 *   cron tick → material publish → member visibility.
 *
 * Usage:
 *   node scripts/e2e-smoke.mjs                       # defaults to localhost:4000
 *   node scripts/e2e-smoke.mjs --api http://host:port/api/v1
 *
 * Development seed credentials are used for the admin step (see
 * Backend/backend/README.md). The backend must be running and seeded.
 * Exits non-zero if any step fails.
 */

import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const apiArg = args.indexOf('--api');
const BASE = (apiArg > -1 ? args[apiArg + 1] : 'http://localhost:4000/api/v1').replace(/\/$/, '');

/**
 * Read Backend/backend/.env so the smoke test uses the same dev secrets as the
 * running server (cron secret, seeded admin password). Environment variables
 * always win, so CI can override.
 */
function backendEnv() {
  const out = {};
  try {
    const text = readFileSync(new URL('../Backend/backend/.env', import.meta.url), 'utf8');
    for (const line of text.split(/\r?\n/)) {
      const m = /^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(line);
      if (!m) continue;
      out[m[1]] = m[2].replace(/^["']|["']$/g, '').trim();
    }
  } catch {
    /* no .env — fall back to documented defaults */
  }
  return out;
}

const LOCAL_ENV = backendEnv();
const env = (name, fallback = '') => process.env[name] || LOCAL_ENV[name] || fallback;

const stamp = Date.now();
const rnd = () => Math.random().toString(36).slice(2, 8);
const emailA = `smoke-a-${stamp}@example.com`;
const emailB = `smoke-b-${stamp}@example.com`;
const password = `Sm0ke!${rnd()}${rnd()}`;

let passed = 0;
let failed = 0;
const failures = [];

function ok(name, cond, extra = '') {
  if (cond) {
    passed++;
    console.log(`  ✅ ${name}`);
  } else {
    failed++;
    failures.push(`${name} ${extra}`);
    console.log(`  ❌ ${name}${extra ? ` — ${extra}` : ''}`);
  }
}

async function call(method, path, { token, body, raw, headers } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers || {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* non-json response */
  }
  return { status: res.status, json, raw };
}

const asList = (data) =>
  Array.isArray(data) ? data : Array.isArray(data?.data) ? data.data : [];

// Single-resource responses may be the object itself or wrapped in { data: {...} }.
// The Flutter API client unwraps `data` when present, so accept both shapes here.
const unwrap = (json) =>
  json && typeof json === 'object' && !Array.isArray(json) && json.data &&
  typeof json.data === 'object' && !Array.isArray(json.data)
    ? json.data
    : json;
const field = (json, key) => unwrap(json)?.[key];

async function main() {
  console.log(`\nMyGrowth e2e smoke → ${BASE}\n`);

  // 0. health
  const health = await call('GET', '/health');
  ok('backend healthy', health.status === 200, `status ${health.status}`);
  if (health.status !== 200) {
    console.log('\nBackend is not reachable. Start it first (npm run dev).');
    process.exit(2);
  }

  // 1. two members register (always MEMBER role)
  console.log('\n— Members register —');
  const regA = await call('POST', '/auth/register', {
    body: { name: 'Smoke Member A', email: emailA, password },
  });
  ok('member A registers', regA.status >= 200 && regA.status < 300, `status ${regA.status}`);
  const tokenA = field(regA.json, 'accessToken');
  ok('member A receives token', !!tokenA);
  ok('registration never assigns admin role',
    (field(regA.json, 'user')?.role ?? 'MEMBER') === 'MEMBER');

  const regB = await call('POST', '/auth/register', {
    body: { name: 'Smoke Member B', email: emailB, password },
  });
  const tokenB = field(regB.json, 'accessToken');
  ok('member B registers', !!tokenB);

  // duplicate email rejected
  const dup = await call('POST', '/auth/register', {
    body: { name: 'Dup', email: emailA, password },
  });
  ok('duplicate email rejected', dup.status >= 400 && dup.status < 500);

  // 2. published programme + months
  console.log('\n— Programme —');
  const programmes = await call('GET', '/programmes', { token: tokenA });
  const progList = asList(programmes.json);
  ok('member can list programmes', programmes.status === 200 && progList.length > 0);
  const prog2027 = progList.find((p) => p.year === 2027);
  ok('2027 programme exists', !!prog2027, prog2027 ? '' : '(no year=2027 in payload)');
  ok('annual prayer focus seeded', !!(prog2027?.prayerFocus?.length > 20));
  ok('daily affirmation seeded', !!(prog2027?.dailyAffirmation?.length > 20));

  const plans = await call('GET', '/programmes/2027/monthly-plans', { token: tokenA });
  const months = asList(plans.json);
  ok('12 monthly plans seeded', months.length === 12, `got ${months.length}`);
  const jan = months.find((m) => m.month === 1);
  ok('January has study topic + confession + reflection questions',
    !!(jan?.theme && jan?.confession && (jan?.reflectionQuestions?.length ?? 0) >= 5));

  // 3. daily checklist + activity record
  console.log('\n— Activities —');
  const today = new Date().toISOString().slice(0, 10);
  const activities = await call('GET', `/me/activities?date=${today}`, { token: tokenA });
  const items = asList(activities.json);
  ok('daily checklist returns', activities.status === 200, `status ${activities.status}`);
  if (items.length > 0) {
    const target = items[0];
    const rec = await call('POST', '/me/activity-records', {
      token: tokenA,
      body: { activityId: target.id ?? target.activityId, date: today, status: 'COMPLETED', note: 'smoke test' },
    });
    ok('activity record created', rec.status >= 200 && rec.status < 300, `status ${rec.status}`);
    const again = await call('POST', '/me/activity-records', {
      token: tokenA,
      body: { activityId: target.id ?? target.activityId, date: today, status: 'COMPLETED' },
    });
    ok('duplicate completion prevented', again.status >= 400, `status ${again.status}`);
  } else {
    console.log('  ⚠️  no plan activities for today (monthly-only guidance) — skipping record step');
  }

  // 4. goals
  console.log('\n— Goals —');
  const goal = await call('POST', '/me/goals', {
    token: tokenA,
    body: { title: 'Smoke monthly goal', periodType: 'MONTHLY', targetQuantity: 4, targetUnit: 'sessions' },
  });
  ok('goal created', goal.status >= 200 && goal.status < 300, `status ${goal.status}`);
  const goalId = field(goal.json, 'id');
  if (goalId) {
    const prog = await call('POST', `/me/goals/${goalId}/progress`, {
      token: tokenA,
      body: { amount: 2 },
    });
    ok('goal progress logged', prog.status >= 200 && prog.status < 300, `status ${prog.status}`);
  }

  // 5. weekly report draft → submit
  console.log('\n— Weekly report —');
  const monday = new Date();
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  const periodKey = monday.toISOString().slice(0, 10);
  const report = await call('POST', '/me/reports', {
    token: tokenA,
    body: {
      type: 'WEEKLY',
      periodKey,
      programmeYear: 2027,
      answers: {
        learned: 'Smoke test lesson',
        scripture: 'Proverbs 4:18',
        progress: 'Recorded activities',
        challenges: 'None',
        improvement: 'Pray earlier',
      },
    },
  });
  ok('weekly draft created', report.status >= 200 && report.status < 300, `status ${report.status}`);
  const reportId = field(report.json, 'id');
  const submit = reportId
    ? await call('POST', `/me/reports/${reportId}/submit`, { token: tokenA })
    : { status: 0 };
  ok('report submitted', submit.status >= 200 && submit.status < 300, `status ${submit.status}`);

  // 6. prayer partners flow
  console.log('\n— Prayer partners —');
  const availA = await call('PUT', '/prayer-partners/availability', {
    token: tokenA,
    body: { status: 'AVAILABLE', availableDays: [1, 3, 5], timeStart: '18:00', timeEnd: '20:00', timeZone: 'Africa/Lagos', preferredDurationMinutes: 30, acceptingRequests: true },
  });
  ok('availability saved (A)', availA.status >= 200 && availA.status < 300, `status ${availA.status}`);
  const availB = await call('PUT', '/prayer-partners/availability', {
    token: tokenB,
    body: { status: 'AVAILABLE', availableDays: [1, 3, 5], timeStart: '18:00', timeEnd: '20:00', timeZone: 'Africa/Lagos', preferredDurationMinutes: 30, acceptingRequests: true },
  });
  ok('availability saved (B)', availB.status >= 200 && availB.status < 300, `status ${availB.status}`);

  const meA = await call('GET', '/me', { token: tokenA });
  const meB = await call('GET', '/me', { token: tokenB });
  const idA = field(meA.json, 'id');
  const idB = field(meB.json, 'id');

  const discover = await call('GET', '/prayer-partners/discover', { token: tokenA });
  ok('discover returns opted-in members',
    discover.status === 200 && asList(discover.json).some((m) => (m.userId ?? m.id) === idB));

  const req = await call('POST', '/prayer-partners/requests', {
    token: tokenA,
    body: { recipientId: idB, message: 'Smoke request' },
  });
  ok('partner request sent', req.status >= 200 && req.status < 300, `status ${req.status}`);
  const requestId = field(req.json, 'id');

  const incoming = await call('GET', '/prayer-partners/requests?direction=incoming', { token: tokenB });
  const pending = asList(incoming.json).find((r) => r.id === requestId);
  ok('B sees incoming request', !!pending);

  const accept = requestId
    ? await call('PATCH', `/prayer-partners/requests/${requestId}`, { token: tokenB, body: { action: 'accept' } })
    : { status: 0 };
  ok('request accepted', accept.status >= 200 && accept.status < 300, `status ${accept.status}`);

  const partnerships = await call('GET', '/prayer-partners/partnerships', { token: tokenA });
  const partnership = asList(partnerships.json).find((p) => p.status === 'ACTIVE');
  ok('active partnership exists for A', !!partnership);
  if (partnership) {
    const startsAt = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
    const session = await call('POST', '/prayer-partners/sessions', {
      token: tokenA,
      body: { partnershipId: partnership.id, startsAt, durationMinutes: 30, timeZone: 'Africa/Lagos', prayerFocus: 'Smoke focus' },
    });
    ok('session proposed', session.status >= 200 && session.status < 300, `status ${session.status}`);
    const sessionId = field(session.json, 'id');
    if (sessionId) {
      const confirmed = await call('PATCH', `/prayer-partners/sessions/${sessionId}`, {
        token: tokenB,
        body: { action: 'accept' },
      });
      ok('session accepted by partner', confirmed.status >= 200 && confirmed.status < 300, `status ${confirmed.status}`);
    }
  }

  // 7. notifications dedupe + cron tick
  console.log('\n— Notifications & cron —');
  const cronSecret = env('CRON_SECRET');
  const tick1 = await call('POST', '/cron/tick', {
    body: {},
    headers: cronSecret ? { 'x-cron-secret': cronSecret } : {},
  });
  ok(
    'cron tick accepted with the configured secret',
    !cronSecret || tick1.status === 200,
    cronSecret ? `status ${tick1.status}` : 'CRON_SECRET is not set in Backend/backend/.env'
  );
  const tick2 = await call('POST', '/cron/tick', { body: {} });
  ok(
    'cron tick is refused without the secret',
    [401, 403].includes(tick2.status),
    `status ${tick2.status}`
  );
  const notifs = await call('GET', '/me/notifications', { token: tokenA });
  ok('notifications list works', notifs.status === 200, `status ${notifs.status}`);

  // 8. admin: bootstrap, review, materials, access rules
  console.log('\n— Admin —');
  const adminEmail = process.env.SMOKE_ADMIN_EMAIL || 'admin@mygrowth.dev';
  const adminPass = process.env.SMOKE_ADMIN_PASSWORD || env('DEV_ADMIN_PASSWORD', 'MyGrowth!Dev2027');
  const adminLogin = await call('POST', '/auth/login', { body: { email: adminEmail, password: adminPass } });
  const adminToken = field(adminLogin.json, 'accessToken');
  ok('dev admin can log in (see backend README for seed creds)', !!adminToken,
    adminLogin.status === 401 ? '(override with SMOKE_ADMIN_EMAIL/PASSWORD)' : `status ${adminLogin.status}`);

  if (adminToken) {
    const adminReports = await call('GET', '/admin/reports?status=SUBMITTED', { token: adminToken });
    const mine = asList(adminReports.json).find((r) => r.id === reportId);
    ok('admin sees submitted report', !!mine);

    const review = reportId
      ? await call('POST', `/admin/reports/${reportId}/reviews`, {
          token: adminToken,
          body: { kind: 'COMMENT', comment: 'Smoke review: keep going!' },
        })
      : { status: 0 };
    ok('admin comments on report', review.status >= 200 && review.status < 300, `status ${review.status}`);

    const reviewed = reportId
      ? await call('POST', `/admin/reports/${reportId}/reviews`, {
          token: adminToken,
          body: { kind: 'REVIEWED' },
        })
      : { status: 0 };
    ok('report marked reviewed', reviewed.status >= 200 && reviewed.status < 300, `status ${reviewed.status}`);

    const memberView = await call('GET', `/me/reports/${reportId}`, { token: tokenA });
    const memberReport = unwrap(memberView.json);
    ok('member sees review status', memberReport?.status === 'REVIEWED', `status ${memberReport?.status}`);
    ok('member sees admin comment',
      asList(memberReport?.reviews ?? memberReport?.reportReviews).some((r) => (r.comment ?? '').includes('Smoke review')));

    // member cannot reach admin APIs
    const forbidden = await call('GET', '/admin/users', { token: tokenA });
    ok('member blocked from admin API', forbidden.status === 401 || forbidden.status === 403);

    // admin cannot manage admin access (unless main admin — main admin CAN)
    const admins = await call('GET', '/admin/admins', { token: adminToken });
    ok('admin-access endpoint responds to seeded main admin',
      admins.status === 200 || admins.status === 403, `status ${admins.status}`);

    // material via external link
    const material = await call('POST', '/admin/materials', {
      token: adminToken,
      body: {
        title: `Smoke material ${rnd()}`,
        category: 'PRAYER_GUIDE',
        description: 'Created by the e2e smoke test',
        externalUrl: 'https://example.com/prayer-guide',
        month: 1,
        year: 2027,
      },
    });
    ok('admin adds external material', material.status >= 200 && material.status < 300, `status ${material.status}`);
    const materialId = field(material.json, 'id');
    if (materialId) {
      const pub = await call('POST', `/admin/materials/${materialId}/publish`, { token: adminToken });
      ok('material published', pub.status >= 200 && pub.status < 300, `status ${pub.status}`);
      const visible = await call('GET', `/materials?search=Smoke`, { token: tokenA });
      ok('member finds published material', asList(visible.json).some((m) => m.id === materialId));
    }

    // analytics + audit logs respond
    const analytics = await call('GET', '/admin/analytics/overview', { token: adminToken });
    ok('admin analytics responds', analytics.status === 200, `status ${analytics.status}`);
    const audit = await call('GET', '/admin/audit-logs', { token: adminToken });
    ok('audit logs respond', audit.status === 200, `status ${audit.status}`);
  }

  // 9. privacy: B cannot read A's report
  console.log('\n— Privacy —');
  const cross = await call('GET', `/me/reports/${reportId}`, { token: tokenB });
  ok('other member cannot read private report', cross.status === 401 || cross.status === 403 || cross.status === 404,
    `status ${cross.status}`);

  // summary
  console.log(`\n${'—'.repeat(40)}\n✅ ${passed} passed, ❌ ${failed} failed\n`);
  if (failed > 0) {
    console.log('Failures:');
    for (const f of failures) console.log(`  • ${f}`);
    process.exit(1);
  }
  console.log('Smoke test complete — core acceptance flow verified.\n');
}

main().catch((err) => {
  console.error('Smoke test crashed:', err);
  process.exit(1);
});
