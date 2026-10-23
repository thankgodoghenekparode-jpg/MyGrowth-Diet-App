/**
 * Repeatable, idempotent seed for MyGrowth Diet App.
 *
 * - Creates the 2027 "Growth Diet Plan 2027" programme with all annual content
 *   (prayer focus, daily affirmation, quarterly confession, quarterly review
 *   topics, annual reflection template) faithful to spec Section 9.
 * - Creates all 12 monthly plans exactly as supplied. No weekly/day-by-day
 *   assignments are fabricated — those stay empty and admin-editable.
 * - Creates activity category + notification event definitions and settings.
 * - In non-production environments, also creates clearly-documented development
 *   sample accounts (main admin, admins, members) with varied sample data.
 *
 * Usage: npm run seed
 */
import { pathToFileURL } from 'node:url';
import { hashPassword } from '../src/lib/password.js';
import { prisma } from '../src/db/index.js';
import { SETTING_DEFAULTS } from '../src/lib/settings.js';
import { DEFAULT_DAILY_DIET_SECTIONS } from '../src/lib/dailyDiet.js';
import { buildDailyDietContent } from './data/dailyDietContent.js';
import config from '../src/config/index.js';

// ---------------------------------------------------------------------------
// Annual programme content (spec Section 9 — preserve wording)
// ---------------------------------------------------------------------------

const PROGRAMME = {
  title: 'Growth Diet Plan 2027',
  year: 2027,
  ministry: 'Healings Erhuvwuigho Azuike Ministry',
  description:
    'The 2027 Growth Diet Plan — a year-long programme of prayer, Bible reading, study, literature, fasting and accountability for members of Healings Erhuvwuigho Azuike Ministry.',
  annualPrayerFocus:
    'In the name of the Lord Jesus, I walk in the will, plan, and purpose of God for my life. My steps, stops, and turns are divinely orchestrated, I experience furtherance, favor, divine relationships, and supernatural help throughout 2027.',
  dailyAffirmation:
    'I affirm that goodness and mercy follow me all the days of my life. I am healed, favored, protected, provided for, promoted, and divinely guided. Angels guard my path, and God is working all things together for my good.',
  startDate: new Date(Date.UTC(2027, 0, 1)),
  endDate: new Date(Date.UTC(2027, 11, 31)),
  quarterlyConfession:
    "I am growing in grace, wisdom, discipline, faith, prayer, stewardship, and service. The Word of God is producing results in my life daily. I walk in divine direction and fulfill God's purpose.",
  quarterlyReviewTopics: [
    'Bible reading',
    'Prayer life',
    'Stewardship',
    'Service',
    'Relationships',
    'Character growth',
  ],
  annualReflectionTemplate: {
    title: 'Annual Reflection and Letter to Myself',
    introduction:
      'Take time to look back over the year before writing your letter to yourself for the coming year. This reflection is private to you unless you choose to share it.',
    sections: [
      { key: 'victories', label: 'Victories', hint: 'What did I accomplish and celebrate this year?' },
      { key: 'lessons_learned', label: 'Lessons learned', hint: 'What did God teach me this year?' },
      { key: 'answered_prayers', label: 'Answered prayers', hint: 'Which prayers did God answer this year?' },
      { key: 'relationships', label: 'Relationships', hint: 'How did my relationships grow or change?' },
      { key: 'growth_areas', label: 'Growth areas', hint: 'Where did I grow, and where do I still need to grow?' },
      { key: 'goals_next_year', label: 'Goals for the following year', hint: 'What will I pursue in the coming year?' },
      { key: 'letter_to_self', label: 'Letter to myself', hint: 'Write a letter to yourself to open next year.' },
    ],
  },
};

const STANDARD_REFLECTION_QUESTIONS = [
  'What progress did I make spiritually this month?',
  'What did God teach me this month?',
  'What habits strengthened my walk with God?',
  'What challenges hindered my growth?',
  'What will I improve next month?',
  'What testimonies can I record?',
];

const FASTING = 'Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum';

/** All 12 months, exactly as supplied in spec Section 9. */
const MONTHS = [
  {
    month: 1,
    theme: 'The Fatherhood of God',
    prayerFocus: 'Spend hours praying in the Spirit throughout the whole month.',
    bibleReadingGuidance: 'Matthew | Mark | Proverbs',
    audioMessages: ['God as Father 1–5 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'The Father and His Family', author: 'E. W. Kenyon' },
      { title: 'The 7 Habits of Highly Effective People', author: 'Stephen Covey' },
    ],
    monthlyConfession:
      'My path is a shining light, and it shines brighter and brighter unto a perfect day. Pro 4vs1',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 2,
    theme: "God's Purpose for Man",
    prayerFocus: "I have the discipline and character required for God's purpose for my life.",
    bibleReadingGuidance: 'Luke | John | Proverbs',
    audioMessages: ['Plan, Purpose, Pursuit 1–4 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'Plan, Purpose and Pursuit', author: null },
      { title: "Following God's Plan for Your Life", author: 'Kenneth E. Hagin' },
    ],
    monthlyConfession:
      'Thy word is a lamp unto my feet and a light unto my path. Psalm 119vs105',
    reflectionQuestions: [
      'What is driving my consistent desire to keep up with my diet plan?',
      'Why am I going through the diet plan—is it for growth or to meet up?',
      'What instructions have I received from the Lord this month?',
      'What challenges hindered my growth?',
      'What will I improve next month?',
      'What testimonies can I record?',
    ],
  },
  {
    month: 3,
    theme: 'Faithful Steward',
    prayerFocus: 'I have furtherance in my life by the Spirit.',
    bibleReadingGuidance: 'Acts | Romans | Proverbs',
    audioMessages: ['Stewards of Christ 1–5 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [{ title: 'Financial Stewardship', author: 'Andrew Womack' }],
    monthlyConfession:
      'Teach me to number my days, that I may apply my heart unto wisdom. Psalm 90vs12',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 4,
    theme: 'The Leading of the Spirit',
    prayerFocus: 'I have eyes that see, ears that can hear, and a heart that perceives.',
    bibleReadingGuidance: '1 Corinthians | 2 Corinthians | Proverbs',
    audioMessages: ['Divine Direction 1–5 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'Understanding Divine Direction', author: 'David O. Oyedepo' },
    ],
    monthlyConfession:
      'For by thee, I have run through a troop; and by my God have I leaped over a wall. Psalm 18vs29',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 5,
    theme: 'Honor',
    prayerFocus:
      'In the name of the Lord Jesus, my faith is right and my honor is right, therefore my receiving is not hindered.',
    bibleReadingGuidance: 'Galatians | Ephesians | Ruth | Proverbs',
    audioMessages: ['Honor to whom it is due 1–4 by Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [{ title: 'The Midas Touch', author: 'Kenneth E. Hagin' }],
    monthlyConfession:
      'No weapon that is formed against me shall prosper; and every tongue that shall rise against me in judgment I shalt condemn. Isaiah 54:17',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 6,
    theme: 'Understanding Relationships',
    prayerFocus:
      'In the name of the Lord Jesus, as long as I have breath in my lungs, my life will forever praise the Lord.',
    bibleReadingGuidance: 'Philippians | Colossians | Psalms | Proverbs',
    audioMessages: ['Supernatural Relationship 1–5 by Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'A Sailing Ship', author: 'Healings E. Azuike' },
      { title: 'Life Together', author: 'Dietrich Bonhoeffer' },
    ],
    monthlyConfession:
      'I am visible to the people who should be in my path, I recognize them and they recognize me, together we are fulfilling Gods plan for my life.',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 7,
    theme: 'Understanding Wealth',
    prayerFocus: 'In the name of the Lord Jesus, I am visible to those who should see me.',
    bibleReadingGuidance: '1 Thessalonians | 2 Thessalonians | Isaiah | Proverbs',
    audioMessages: ['The Love of God by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'The Psychology of Money', author: 'Morgan Housel' },
      { title: 'Giving and Receiving', author: 'Kenneth Copeland' },
    ],
    monthlyConfession:
      'Thou wilt shew me the path of life: in thy presence is fullness of joy; at thy right hand there are pleasures for evermore. Psalm 16:11',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 8,
    theme: "Believers' Conduct",
    prayerFocus:
      'In the name of the Lord Jesus, my name is in the heart of those that matters to what matters to me and I have recommendation that brings about furtherance into my life.',
    bibleReadingGuidance: '1 Timothy | 2 Timothy | Titus | Ecclesiastes | Proverbs',
    audioMessages: ['The Man in Christ 1–3 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [{ title: 'Atomic Habits', author: 'James Clear' }],
    monthlyConfession:
      'The lines are fallen unto me in pleasant places; yea, I have a goodly heritage. Psalm 16:6',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 9,
    theme: 'Service to God',
    prayerFocus:
      'In the name of the Lord Jesus, I and every member of my family are kept in safety, we are delivered from unreasonable and wicked men.',
    bibleReadingGuidance: 'Philemon | Hebrews | James | Joshua | Proverbs',
    audioMessages: ['Christian Devotion 1–3 by Pastor Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'Spiritually Social', author: 'Healings E. Azuike' },
      { title: 'The Fear of Failing', author: 'Healings E. Azuike' },
    ],
    monthlyConfession:
      'I am generous with Gods resources, I give cheerfully and bountifully, my barn is ever filled with plenty.',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 10,
    theme: 'Mentor & Discipleship',
    prayerFocus:
      'In the name of the Lord Jesus, I am in the right place at the right time at all time, it will not, it shall not, it cannot enter the heart of any man to do me evil.',
    bibleReadingGuidance: '1 Peter | 2 Peter | 1 John | Exodus | Proverbs',
    audioMessages: ['Pass It On 1–4 by Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'Scripted Life', author: 'Healings E. Azuike' },
      { title: 'Eat This Book', author: 'Eugene H. Peterson' },
    ],
    monthlyConfession:
      'The eyes of my understanding being enlightened; that I may know what the hope of his calling is, and what the riches of the glory of his inheritance in the saints. Eph 1.18',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 11,
    theme: 'The Gospel',
    prayerFocus:
      'In the name of the Lord Jesus, I am generous with Gods resources, therefore, at all times, I have seed to sow and bread to eat.',
    bibleReadingGuidance: '2 John | 3 John | Jude | Genesis | Proverbs',
    audioMessages: ['The Gospel 1–4 by Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [{ title: 'Salvation Classic One & Two', author: 'Apostle TD Philips' }],
    monthlyConfession:
      'My life is being shaped by prayer, the more I pray, the more I see a need to pray.',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
  {
    month: 12,
    theme: 'The Blessing of God',
    prayerFocus: 'Prayer of thanksgiving.',
    bibleReadingGuidance: 'Revelation | 1 Samuel | 2 Samuel | Proverbs',
    audioMessages: ['The Blessing of Work and Practicing Joy by Healings E. Azuike'],
    fastingGuidance: FASTING,
    literatureList: [
      { title: 'Out With It', author: 'Healings E. Azuike' },
      { title: 'Redefine', author: 'Healings E. Azuike' },
    ],
    monthlyConfession:
      'Be careful for nothing; but in everything by prayer and supplication with thanksgiving let your requests be made known unto God. Phil 4:6',
    reflectionQuestions: STANDARD_REFLECTION_QUESTIONS,
  },
];

const ACTIVITY_CATEGORIES = [
  { key: 'prayer', label: 'Prayer', description: 'Personal prayer time.', sortOrder: 1 },
  { key: 'scripture_reading', label: 'Scripture reading', description: 'Reading the Bible.', sortOrder: 2 },
  { key: 'bible_study', label: 'Bible study', description: 'Deeper study of Scripture.', sortOrder: 3 },
  { key: 'literature_reading', label: 'Literature reading', description: 'Reading assigned books and materials.', sortOrder: 4 },
  { key: 'proverbs_reading', label: 'Proverbs reading', description: 'Daily Proverbs reading.', sortOrder: 5 },
  { key: 'fasting_and_prayer', label: 'Fasting and prayer', description: 'Scheduled fasting periods.', sortOrder: 6 },
  { key: 'prayer_and_affirmations', label: 'Prayer and affirmations', description: 'Prayer with daily affirmations.', sortOrder: 7 },
  { key: 'confessions_declarations', label: 'Confessions and declarations', description: 'Monthly confessions and declarations.', sortOrder: 8 },
  { key: 'audio_message', label: 'Audio message', description: 'Listening to programme audio messages.', sortOrder: 9 },
  { key: 'prayer_partner_session', label: 'Prayer partner session', description: 'Paired prayer sessions.', sortOrder: 10 },
  { key: 'personal_reflection', label: 'Personal reflection', description: 'Journaling and reflection.', sortOrder: 11 },
  { key: 'custom', label: 'Custom', description: 'Member-defined activities.', sortOrder: 12 },
];

const NOTIFICATION_EVENTS = [
  { key: 'welcome_verification', label: 'Welcome / email verification', description: 'Sent when an account registers.' },
  { key: 'membership_approved', label: 'Membership approved', description: 'Sent when a member is approved by an admin.' },
  { key: 'programme_published', label: 'Programme published', description: 'Sent when a programme is published.' },
  { key: 'material_published', label: 'Material published', description: 'Sent when a study material is published.' },
  { key: 'daily_activity_reminder', label: 'Daily activity reminder', description: "Daily reminder for today's checklist." },
  { key: 'weekly_report_reminder', label: 'Weekly report reminder', description: 'Sunday reminder for the weekly report.' },
  { key: 'monthly_report_reminder', label: 'Monthly report reminder', description: 'Month-end reminder for the monthly report.' },
  { key: 'quarterly_review_reminder', label: 'Quarterly review reminder', description: 'Reminder at the start of each quarter.' },
  { key: 'annual_reflection_reminder', label: 'Annual reflection reminder', description: 'Reminder to write the annual reflection.' },
  { key: 'new_announcement', label: 'New announcement', description: 'Broadcast when an announcement is published.' },
  { key: 'partner_request_received', label: 'Prayer partner request received', description: 'A member received a partner request.' },
  { key: 'partner_request_accepted', label: 'Prayer partner request accepted', description: 'A partner request was accepted.' },
  { key: 'partner_request_declined', label: 'Prayer partner request declined', description: 'A partner request was declined or ended.' },
  { key: 'session_proposed', label: 'Prayer session proposed', description: 'A prayer session time was proposed.' },
  { key: 'session_accepted', label: 'Prayer session accepted', description: 'A proposed session was accepted.' },
  { key: 'session_rescheduled', label: 'Prayer session rescheduled', description: 'A session was rescheduled.' },
  { key: 'session_cancelled', label: 'Prayer session cancelled', description: 'A session was cancelled.' },
  { key: 'session_upcoming', label: 'Prayer session upcoming', description: 'A session starts within the hour.' },
  { key: 'admin_report_comment', label: 'Admin comment on report', description: 'An admin commented or requested follow-up.' },
  { key: 'admin_report_follow_up', label: 'Admin report follow-up', description: 'An admin marked a report as reviewed with follow-up.' },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const log = (msg) => console.log(`[seed] ${msg}`);

async function seedProgramme() {
  let programme = await prisma.programme.findFirst({ where: { year: PROGRAMME.year } });
  const data = {
    title: PROGRAMME.title,
    year: PROGRAMME.year,
    ministry: PROGRAMME.ministry,
    description: PROGRAMME.description,
    annualPrayerFocus: PROGRAMME.annualPrayerFocus,
    dailyAffirmation: PROGRAMME.dailyAffirmation,
    startDate: PROGRAMME.startDate,
    endDate: PROGRAMME.endDate,
    quarterlyConfession: PROGRAMME.quarterlyConfession,
    quarterlyReviewTopics: PROGRAMME.quarterlyReviewTopics,
    annualReflectionTemplate: PROGRAMME.annualReflectionTemplate,
    status: 'PUBLISHED',
    publishedAt: new Date(),
  };
  if (programme) {
    programme = await prisma.programme.update({ where: { id: programme.id }, data });
    log(`programme ${programme.year} updated (${programme.id})`);
  } else {
    programme = await prisma.programme.create({ data });
    log(`programme ${programme.year} created (${programme.id})`);
  }

  for (const m of MONTHS) {
    const row = { ...m, year: PROGRAMME.year, status: 'PUBLISHED', publishedAt: new Date() };
    await prisma.monthlyPlan.upsert({
      where: { programmeId_month: { programmeId: programme.id, month: m.month } },
      create: { programmeId: programme.id, ...row },
      update: row,
    });
  }
  log(`12 monthly plans upserted`);

  return programme;
}

async function seedDefinitions() {
  for (const c of ACTIVITY_CATEGORIES) {
    await prisma.activityCategoryDef.upsert({
      where: { key: c.key },
      create: { ...c, enabled: true },
      update: { label: c.label, description: c.description, sortOrder: c.sortOrder, enabled: true },
    });
  }
  log(`${ACTIVITY_CATEGORIES.length} activity categories upserted`);

  for (const e of NOTIFICATION_EVENTS) {
    await prisma.notificationEventDef.upsert({
      where: { key: e.key },
      create: { ...e, defaultEnabled: true },
      update: { label: e.label, description: e.description, defaultEnabled: true },
    });
  }
  log(`${NOTIFICATION_EVENTS.length} notification events upserted`);

  for (const [key, value] of Object.entries(SETTING_DEFAULTS)) {
    const existing = await prisma.setting.findUnique({ where: { key } });
    if (!existing) {
      await prisma.setting.create({ data: { key, value } });
    }
  }
  log(`settings ensured`);
}

// ---------------------------------------------------------------------------
// Daily Diet — structure and per-day content
// ---------------------------------------------------------------------------

/**
 * Create the Daily Diet structure for a programme and fill each section with
 * its content: the 2027 Scripture reading plan day by day, and the weekly /
 * monthly prayer direction, Bible study topic, fasting guidance, literature,
 * audio messages, declarations and report prompts taken from the ministry's
 * own monthly plans.
 */
async function seedDailyDiet(programme) {
  const sectionByKey = {};
  for (const s of DEFAULT_DAILY_DIET_SECTIONS) {
    const section = await prisma.dailyDietSection.upsert({
      where: { programmeId_key: { programmeId: programme.id, key: s.key } },
      create: {
        programmeId: programme.id,
        key: s.key,
        label: s.label,
        description: s.description,
        behaviour: s.behaviour,
        sortOrder: s.sortOrder,
        enabled: true,
        required: true,
        allowNote: true,
        trackCompletion: true,
        status: 'PUBLISHED',
      },
      update: {
        label: s.label,
        description: s.description,
        behaviour: s.behaviour,
        sortOrder: s.sortOrder,
        status: 'PUBLISHED',
      },
    });
    sectionByKey[s.key] = section;
  }
  log(`${DEFAULT_DAILY_DIET_SECTIONS.length} daily diet sections upserted`);

  const rows = buildDailyDietContent(MONTHS);
  const chunkSize = 50;
  let written = 0;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    await prisma.$transaction(
      chunk
        .filter((row) => sectionByKey[row.key])
        .map((row) => {
          const section = sectionByKey[row.key];
          const date = new Date(`${row.date}T00:00:00.000Z`);
          return prisma.dailyDietContent.upsert({
            where: { sectionId_date: { sectionId: section.id, date } },
            create: {
              sectionId: section.id,
              date,
              scope: row.scope,
              title: row.title,
              body: row.body ?? null,
              details: row.details ?? null,
              materialIds: [],
              status: 'PUBLISHED',
              publishedAt: new Date(),
            },
            update: {
              scope: row.scope,
              title: row.title,
              body: row.body ?? null,
              details: row.details ?? null,
              status: 'PUBLISHED',
              publishedAt: new Date(),
            },
          });
        })
    );
    written += chunk.length;
  }
  log(`${written} daily diet content rows upserted`);

  return sectionByKey;
}

// ---------------------------------------------------------------------------
// Development sample accounts (never in production)
// ---------------------------------------------------------------------------

// Temporary development credentials — documented in README.md for local use
// ONLY. Change or remove them before any real deployment.
const DEV_PASSWORD = 'MyGrowth!Dev2027';

const DEV_USERS = [
  {
    email: 'mainadmin@mygrowth.dev',
    firstName: 'Main',
    lastName: 'Administrator',
    role: 'MAIN_ADMIN',
    status: 'ACTIVE',
    adminAccess: 'ACTIVE',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'admin@mygrowth.dev',
    firstName: 'Programme',
    lastName: 'Administrator',
    role: 'ADMIN',
    status: 'ACTIVE',
    adminAccess: 'ACTIVE',
    createdByEmail: 'mainadmin@mygrowth.dev',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'suspended.admin@mygrowth.dev',
    firstName: 'Suspended',
    lastName: 'Administrator',
    role: 'ADMIN',
    status: 'ACTIVE',
    adminAccess: 'SUSPENDED',
    createdByEmail: 'mainadmin@mygrowth.dev',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'grace.member@mygrowth.dev',
    firstName: 'Grace',
    lastName: 'Member',
    role: 'MEMBER',
    status: 'ACTIVE',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'daniel.member@mygrowth.dev',
    firstName: 'Daniel',
    lastName: 'Member',
    role: 'MEMBER',
    status: 'ACTIVE',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'pending.member@mygrowth.dev',
    firstName: 'Pending',
    lastName: 'Member',
    role: 'MEMBER',
    status: 'PENDING',
    timezone: 'Africa/Lagos',
  },
  {
    email: 'suspended.member@mygrowth.dev',
    firstName: 'Suspended',
    lastName: 'Member',
    role: 'MEMBER',
    status: 'SUSPENDED',
    timezone: 'Africa/Lagos',
  },
];

async function seedDevUsers() {
  if (config.isProd) {
    log('production environment — skipping development sample accounts');
    return {};
  }

  const passwordHash = await hashPassword(DEV_PASSWORD);
  const byEmail = {};

  for (const u of DEV_USERS) {
    const data = {
      email: u.email,
      firstName: u.firstName,
      lastName: u.lastName,
      passwordHash,
      role: u.role,
      status: u.status,
      adminAccess: u.adminAccess,
      emailVerifiedAt: new Date(),
      timezone: u.timezone,
    };
    const existing = await prisma.user.findUnique({ where: { email: u.email } });
    let row;
    if (existing) {
      row = await prisma.user.update({ where: { id: existing.id }, data });
    } else {
      row = await prisma.user.create({ data });
    }
    byEmail[u.email] = row;
  }

  // Attach admin creators after all accounts exist.
  for (const u of DEV_USERS) {
    if (!u.createdByEmail || !byEmail[u.createdByEmail]) continue;
    await prisma.user.update({
      where: { id: byEmail[u.email].id },
      data: { createdByAdminId: byEmail[u.createdByEmail].id },
    });
  }

  log(`${DEV_USERS.length} development accounts upserted (password: ${DEV_PASSWORD})`);

  await seedDevMemberData(byEmail);
  return byEmail;
}

/** Varied sample data for the two active dev members. */
async function seedDevMemberData(users) {
  const grace = users['grace.member@mygrowth.dev'];
  const daniel = users['daniel.member@mygrowth.dev'];
  if (!grace || !daniel) return;

  const programme = await prisma.programme.findFirst({ where: { year: PROGRAMME.year } });

  // Goals for Grace (one monthly, one weekly) with a progress entry.
  const graceGoals = [
    {
      title: 'Complete the 2027 Bible reading plan by December',
      description: 'Keep pace with the monthly Bible reading guidance.',
      periodType: 'MONTHLY',
      startDate: new Date(Date.UTC(2027, 0, 1)),
      targetDate: new Date(Date.UTC(2027, 11, 31)),
      targetQuantity: 12,
      unit: 'months',
      currentProgress: 1,
      status: 'ACTIVE',
    },
    {
      title: 'Pray 30 minutes daily this week',
      description: null,
      periodType: 'WEEKLY',
      startDate: new Date(Date.UTC(2027, 0, 4)),
      targetDate: new Date(Date.UTC(2027, 0, 10)),
      targetQuantity: 7,
      unit: 'days',
      currentProgress: 3,
      status: 'ACTIVE',
    },
  ];
  for (const g of graceGoals) {
    const existing = await prisma.personalGoal.findFirst({
      where: { userId: grace.id, title: g.title },
    });
    if (existing) continue;
    const goal = await prisma.personalGoal.create({
      data: { ...g, userId: grace.id, programmeId: programme?.id ?? null },
    });
    if (goal.currentProgress > 0) {
      await prisma.goalProgressEntry.create({
        data: { goalId: goal.id, value: goal.currentProgress, note: 'Seed sample progress' },
      });
    }
  }

  // Goal for Daniel.
  const danielGoal = await prisma.personalGoal.findFirst({
    where: { userId: daniel.id, title: 'Read "Atomic Habits" before February' },
  });
  if (!danielGoal) {
    await prisma.personalGoal.create({
      data: {
        userId: daniel.id,
        programmeId: programme?.id ?? null,
        title: 'Read "Atomic Habits" before February',
        description: 'August literature, started early.',
        periodType: 'MONTHLY',
        startDate: new Date(Date.UTC(2027, 0, 1)),
        targetDate: new Date(Date.UTC(2027, 1, 1)),
        targetQuantity: 1,
        unit: 'book',
        currentProgress: 0,
        status: 'ACTIVE',
      },
    });
  }

  // Prayer availability samples.
  await prisma.prayerAvailability.upsert({
    where: { userId: grace.id },
    create: {
      userId: grace.id,
      availability: 'AVAILABLE',
      availableDays: [1, 3, 5, 6],
      preferredTimeRanges: [
        { start: '06:00', end: '07:00' },
        { start: '21:00', end: '22:00' },
      ],
      preferredDurationMinutes: 30,
      acceptsNewRequests: true,
    },
    update: {
      availability: 'AVAILABLE',
      availableDays: [1, 3, 5, 6],
      preferredTimeRanges: [
        { start: '06:00', end: '07:00' },
        { start: '21:00', end: '22:00' },
      ],
    },
  });
  await prisma.prayerAvailability.upsert({
    where: { userId: daniel.id },
    create: {
      userId: daniel.id,
      availability: 'AVAILABLE',
      availableDays: [2, 4, 6],
      preferredTimeRanges: [{ start: '18:00', end: '19:00' }],
      preferredDurationMinutes: 20,
      acceptsNewRequests: true,
    },
    update: { availability: 'AVAILABLE', availableDays: [2, 4, 6] },
  });

  log('development member sample data ensured');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

export async function main() {
  log(`seeding (env: ${config.env})`);
  const programme = await seedProgramme();
  await seedDailyDiet(programme);
  await seedDefinitions();
  await seedDevUsers();
  log('done');
}

export {
  seedProgramme,
  seedDailyDiet,
  seedDefinitions,
  seedDevUsers,
  PROGRAMME,
  MONTHS,
};

// Run only when executed directly (also importable by tests).
const isDirectRun =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isDirectRun) {
  main()
    .catch((err) => {
      console.error('[seed] failed:', err);
      process.exitCode = 1;
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
