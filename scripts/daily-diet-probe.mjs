/**
 * Daily Diet end-to-end probe.
 *
 * Exercises the member and admin Daily Diet flows against a running backend
 * and prints a pass/fail report. It writes its own content rows and tick-offs
 * and deletes them again, so it can be run against the dev database.
 *
 * Usage:
 *   node scripts/daily-diet-probe.mjs [baseUrl]
 *
 * Defaults to http://localhost:4000/api/v1 and the seeded dev logins.
 */
const BASE = process.argv[2] ?? 'http://localhost:4000/api/v1';
const PASSWORD = process.env.DEV_PASSWORD ?? 'MyGrowth!Dev2027';

const MEMBER = 'grace.member@mygrowth.dev';
const OTHER = 'daniel.member@mygrowth.dev';
const ADMIN = 'admin@mygrowth.dev';

let passed = 0;
let failed = 0;

function check(label, condition, detail) {
  if (condition) {
    passed += 1;
    console.log(`  ✓ ${label}`);
  } else {
    failed += 1;
    console.log(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

async function request(path, { token, method = 'GET', body, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body) headers['Content-Type'] = 'application/json';

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: form ?? (body ? JSON.stringify(body) : undefined),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = text;
  }
  // The auth endpoints double-encode their payload in this project.
  if (typeof json === 'string') {
    try {
      json = JSON.parse(json);
    } catch {
      /* leave it as a string */
    }
  }
  return { status: res.status, body: json };
}

async function login(email) {
  const res = await request('/auth/login', {
    method: 'POST',
    body: { email, password: PASSWORD },
  });
  if (res.status !== 200 || !res.body?.accessToken) {
    throw new Error(`login failed for ${email}: ${res.status}`);
  }
  return res.body.accessToken;
}

/** The data array from an envelope, whether or not the client unwraps it. */
function items(body) {
  if (Array.isArray(body)) return body;
  if (body && Array.isArray(body.data)) return body.data;
  return [];
}

const created = { completions: [], content: [] };

async function main() {
  console.log(`Daily Diet probe -> ${BASE}\n`);

  const member = await login(MEMBER);
  const other = await login(OTHER);
  const admin = await login(ADMIN);

  const DATE = '2027-03-17';
  const SECTION_KEYS = [
    'prayer',
    'scripture_reading',
    'bible_study',
    'literature_reading',
    'proverbs_reading',
    'fasting_and_prayer',
    'report',
    'declarations',
    'audio_message',
    'prayer_partner_session',
    'music',
  ];
  const BEHAVIOURS = {
    prayer: 'TIMER',
    scripture_reading: 'TEXT',
    bible_study: 'TEXT',
    literature_reading: 'MATERIAL',
    proverbs_reading: 'TEXT',
    fasting_and_prayer: 'TICK',
    report: 'REPORT',
    declarations: 'TEXT',
    audio_message: 'MATERIAL',
    prayer_partner_session: 'PARTNER',
    music: 'MATERIAL',
  };

  console.log('Member: the day');
  const day = await request(`/daily-diet?date=${DATE}`, { token: member });
  check('GET /daily-diet returns 200', day.status === 200, `got ${day.status}`);
  const sectionList = day.body?.sections ?? [];
  check('all 11 sections are published', sectionList.length === 11, `got ${sectionList.length}`);
  check(
    'the canonical keys are present',
    SECTION_KEYS.every((k) => sectionList.some((s) => s.key === k))
  );
  const wrongBehaviour = SECTION_KEYS.filter((key) => {
    const section = sectionList.find((s) => s.key === key);
    return section && section.behaviour !== BEHAVIOURS[key];
  });
  check('every section has its configured behaviour', wrongBehaviour.length === 0, wrongBehaviour.join(', '));
  check('the date is inside the programme', day.body?.dateInProgramme === true);

  const reading = sectionList.find((s) => s.key === 'scripture_reading');
  check(
    'the scripture reading is attached',
    Boolean(reading?.content?.details?.reading),
    reading?.content?.title
  );
  check(
    'the reading plan heading and focus are attached',
    Boolean(reading?.content?.details?.heading) &&
      Boolean(reading?.content?.details?.focus)
  );
  const study = sectionList.find((s) => s.key === 'bible_study');
  check('the Bible study topic is attached', Boolean(study?.content?.details?.topic), study?.content?.title);
  check('the month scope reaches the study', study?.content?.scope === 'MONTH');
  const prayer = sectionList.find((s) => s.key === 'prayer');
  check('the prayer focus is attached', Boolean(prayer?.content?.details?.monthlyFocus));

  console.log('\nMember: tick-offs');
  const before = day.body?.progress ?? {};
  const tick = await request('/daily-diet/completions', {
    token: member,
    method: 'POST',
    body: { sectionKey: 'scripture_reading', date: DATE, status: 'COMPLETED' },
  });
  check('ticking a section returns 201', tick.status === 201, `got ${tick.status}`);
  if (tick.body?.completion?.id) created.completions.push(tick.body.completion.id);

  const after = await request(`/daily-diet?date=${DATE}`, { token: member });
  check(
    'progress goes up by one',
    after.body?.progress?.completed === before.completed + 1,
    `${before.completed} -> ${after.body?.progress?.completed}`
  );
  check(
    'the section reports itself completed',
    after.body?.sections?.find((s) => s.key === 'scripture_reading')?.isCompleted === true
  );

  const timed = await request('/daily-diet/completions', {
    token: member,
    method: 'POST',
    body: { sectionKey: 'prayer', date: DATE, status: 'COMPLETED', actualDurationMinutes: 45 },
  });
  check('prayer minutes are recorded', timed.body?.completion?.actualDurationMinutes === 45);
  if (timed.body?.completion?.id) created.completions.push(timed.body.completion.id);

  const noted = await request('/daily-diet/completions', {
    token: member,
    method: 'POST',
    body: {
      sectionKey: 'fasting_and_prayer',
      date: DATE,
      status: 'COMPLETED',
      note: 'Fasted 6am-3pm.',
    },
  });
  check('a note is recorded', noted.body?.completion?.note === 'Fasted 6am-3pm.');
  if (noted.body?.completion?.id) created.completions.push(noted.body.completion.id);

  const foreign = await request(
    `/daily-diet/completions/${created.completions[0]}`,
    { token: other, method: 'DELETE' }
  );
  check("another member cannot clear this member's tick-off", foreign.status === 403, `got ${foreign.status}`);

  const progress = await request('/daily-diet/progress?from=2027-03-01&to=2027-03-31', {
    token: member,
  });
  const progressRow = items(progress.body).find((d) => d.date === DATE);
  check('the day appears in the member progress list', Boolean(progressRow));
  check('the completed count is correct', progressRow?.completed === 3, `got ${progressRow?.completed}`);

  const otherProgress = await request(
    '/daily-diet/progress?from=2027-03-01&to=2027-03-31',
    { token: other }
  );
  check(
    "another member's progress does not include this day",
    !items(otherProgress.body).some((d) => d.date === DATE)
  );

  console.log('\nMember: the report upload');
  const uploadForm = new FormData();
  uploadForm.append(
    'file',
    new Blob(['Weekly report probe\nWhat went well: prayer.'], {
      type: 'text/plain',
    }),
    'probe-weekly-report.txt'
  );
  uploadForm.append('category', 'report');
  const uploaded = await request('/files', {
    token: member,
    method: 'POST',
    form: uploadForm,
  });
  check('a member can upload a file', uploaded.status === 201, `got ${uploaded.status}`);
  const fileId = uploaded.body?.file?.id;
  const fileUrl = uploaded.body?.file?.url;
  check('the upload returns file metadata', Boolean(fileId) && Boolean(fileUrl));

  if (fileId) {
    const withReport = await request('/daily-diet/completions', {
      token: member,
      method: 'POST',
      body: {
        sectionKey: 'report',
        date: DATE,
        status: 'COMPLETED',
        note: 'Weekly report attached',
        attachmentFileId: fileId,
      },
    });
    const reportCompletionId = withReport.body?.completion?.id;
    check(
      'the report records the uploaded file',
      withReport.body?.completion?.attachment?.url === fileUrl,
      withReport.body?.completion?.attachment?.url
    );

    const blocked = await request(`/files/${fileId}`, {
      token: member,
      method: 'DELETE',
    });
    check(
      'a file attached to a report cannot be deleted',
      blocked.status === 409,
      `got ${blocked.status}`
    );

    // Clearing the tick-off releases the file again.
    if (reportCompletionId) {
      await request(`/daily-diet/completions/${reportCompletionId}`, {
        token: member,
        method: 'DELETE',
      });
    }
    const removed = await request(`/files/${fileId}`, {
      token: member,
      method: 'DELETE',
    });
    check(
      'the uploader can delete their own file',
      removed.status === 200,
      `got ${removed.status}`
    );
  }

  console.log('\nAdmin: the structure');
  const forbidden = await request('/admin/daily-diet/sections?year=2027', { token: member });
  check('a member is refused the admin routes', forbidden.status === 403, `got ${forbidden.status}`);

  const sections = await request('/admin/daily-diet/sections?year=2027', { token: admin });
  check('an admin can list the sections', items(sections.body).length === 11, `got ${items(sections.body).length}`);

  const added = await request('/admin/daily-diet/sections', {
    token: admin,
    method: 'POST',
    body: {
      year: 2027,
      key: 'probe_family_altar',
      label: 'Family altar (probe)',
      behaviour: 'TICK',
      status: 'DRAFT',
    },
  });
  check('an admin can add a section', added.status === 201, `got ${added.status}`);
  const sectionId = added.body?.section?.id;

  if (sectionId) {
    const published = await request(`/admin/daily-diet/sections/${sectionId}/publish`, {
      token: admin,
      method: 'POST',
    });
    check('the new section can be published', published.body?.section?.status === 'PUBLISHED');

    const memberDay = await request(`/daily-diet?date=${DATE}`, { token: member });
    check('the published section reaches members', memberDay.body?.sections?.some((s) => s.key === 'probe_family_altar'));

    const archived = await request(`/admin/daily-diet/sections/${sectionId}/archive`, {
      token: admin,
      method: 'POST',
    });
    check('the section can be archived again', archived.body?.section?.status === 'ARCHIVED');
  }

  console.log('\nAdmin: the content and its scopes');
  const music = items(sections.body).find((s) => s.key === 'music');

  // A week row written on a Wednesday must land on the Sunday anchor.
  const weekRow = await request('/admin/daily-diet/content', {
    token: admin,
    method: 'PUT',
    body: {
      sectionId: music?.id,
      date: '2027-04-14',
      scope: 'WEEK',
      title: 'Probe songs for the week',
      details: { songs: ['Great is Thy Faithfulness'] },
      status: 'PUBLISHED',
    },
  });
  check('a week row is accepted', weekRow.status === 200, `got ${weekRow.status}`);
  check('it is filed on the Sunday anchor', weekRow.body?.content?.date === '2027-04-11', weekRow.body?.content?.date);
  if (weekRow.body?.content?.id) created.content.push(weekRow.body.content.id);

  for (const [label, date] of [['Sunday', '2027-04-11'], ['Wednesday', '2027-04-14'], ['Saturday', '2027-04-17']]) {
    const snapshot = await request(`/daily-diet?date=${date}`, { token: member });
    const row = snapshot.body?.sections?.find((s) => s.key === 'music');
    check(
      `the week row reaches members on ${label}`,
      row?.content?.title === 'Probe songs for the week',
      row?.content?.title
    );
  }

  // A day row overrides the week for that one day.
  const dayRow = await request('/admin/daily-diet/content', {
    token: admin,
    method: 'PUT',
    body: {
      sectionId: music?.id,
      date: '2027-04-14',
      scope: 'DAY',
      title: 'Probe song for today',
      status: 'PUBLISHED',
    },
  });
  check('a day row is accepted', dayRow.status === 200, `got ${dayRow.status}`);
  if (dayRow.body?.content?.id) created.content.push(dayRow.body.content.id);

  const override = await request('/daily-diet?date=2027-04-14', { token: member });
  const overrideRow = override.body?.sections?.find((s) => s.key === 'music');
  check('the day row wins over the week row', overrideRow?.content?.title === 'Probe song for today', overrideRow?.content?.title);
  check('the winning scope is DAY', overrideRow?.content?.scope === 'DAY', overrideRow?.content?.scope);

  // The admin day listing shows every scope that covers the day.
  const adminDay = await request('/admin/daily-diet/content?date=2027-04-14', { token: admin });
  const dayRows = items(adminDay.body).filter((c) => c.sectionId === music?.id);
  check(
    'the admin day listing shows the day and week rows',
    dayRows.some((c) => c.scope === 'DAY') && dayRows.some((c) => c.scope === 'WEEK'),
    dayRows.map((c) => c.scope).join(', ')
  );

  // Publish-day covers the day plus its week and month rows.
  const draftWeek = await request('/admin/daily-diet/content', {
    token: admin,
    method: 'PUT',
    body: {
      sectionId: music?.id,
      date: '2027-05-05',
      scope: 'WEEK',
      title: 'Probe draft week',
      status: 'DRAFT',
    },
  });
  if (draftWeek.body?.content?.id) created.content.push(draftWeek.body.content.id);
  const publishedDay = await request('/admin/daily-diet/content/publish-day', {
    token: admin,
    method: 'POST',
    body: { date: '2027-05-05' },
  });
  check('publish-day reports what it published', publishedDay.body?.published >= 1, `got ${publishedDay.body?.published}`);
  const afterPublish = await request('/daily-diet?date=2027-05-05', { token: member });
  const publishedRow = afterPublish.body?.sections?.find((s) => s.key === 'music');
  check('the published week row reaches members', publishedRow?.content?.title === 'Probe draft week', publishedRow?.content?.title);

  console.log('\nClean-up');
  for (const id of created.content) {
    await request(`/admin/daily-diet/content/${id}`, { token: admin, method: 'DELETE' });
  }
  for (const id of created.completions) {
    await request(`/daily-diet/completions/${id}`, { token: member, method: 'DELETE' });
  }
  if (sectionId) {
    await request(`/admin/daily-diet/sections/${sectionId}`, { token: admin, method: 'DELETE' });
  }
  console.log('  ✓ probe data removed');

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error('\nprobe failed:', error.message);
  process.exit(1);
});
