/**
 * Daily Diet — the admin-configured devotional structure.
 *
 * The structure of the Daily Diet (which sections exist, their labels, their
 * order and how each one behaves) is set by an administrator in the admin
 * dashboard. Members simply open a date and follow what is published.
 *
 * This module holds the shared vocabulary used by the member routes, the
 * admin routes and the seed so the three never drift apart.
 */
import { DateTime } from 'luxon';

/** Canonical section keys. */
export const DAILY_DIET_SECTION_KEYS = {
  PRAYER: 'prayer',
  SCRIPTURE_READING: 'scripture_reading',
  BIBLE_STUDY: 'bible_study',
  LITERATURE: 'literature_reading',
  PROVERBS: 'proverbs_reading',
  FASTING: 'fasting_and_prayer',
  REPORT: 'report',
  DECLARATIONS: 'declarations',
  AUDIO: 'audio_message',
  PRAYER_PARTNER: 'prayer_partner_session',
  MUSIC: 'music',
};

export const DAILY_DIET_BEHAVIOURS = [
  'TEXT',
  'MATERIAL',
  'TIMER',
  'TICK',
  'REPORT',
  'PARTNER',
];

/**
 * The structure seeded for every programme. Administrators may rename,
 * reorder, disable or add sections afterwards — this is only the starting
 * point, not a hard-coded list.
 */
export const DEFAULT_DAILY_DIET_SECTIONS = [
  {
    key: DAILY_DIET_SECTION_KEYS.PRAYER,
    label: 'Prayers',
    behaviour: 'TIMER',
    sortOrder: 1,
    description:
      'Prayer direction for the week and month. Set the duration you are able to pray and record it with the stopwatch.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.SCRIPTURE_READING,
    label: 'Scriptures reading',
    behaviour: 'TEXT',
    sortOrder: 2,
    description: "The scriptural reading assigned to this day.",
  },
  {
    key: DAILY_DIET_SECTION_KEYS.BIBLE_STUDY,
    label: 'Bible study topics',
    behaviour: 'TEXT',
    sortOrder: 3,
    description: "The month's Bible study topic with its teachings.",
  },
  {
    key: DAILY_DIET_SECTION_KEYS.LITERATURE,
    label: 'Literature daily read',
    behaviour: 'MATERIAL',
    sortOrder: 4,
    description: 'The literature uploaded for this day.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.PROVERBS,
    label: 'Daily proverbs',
    behaviour: 'TEXT',
    sortOrder: 5,
    description: "Today's proverb.",
  },
  {
    key: DAILY_DIET_SECTION_KEYS.FASTING,
    label: 'Fasting days',
    behaviour: 'TICK',
    sortOrder: 6,
    description:
      'Your fasting days for the week and month. Tick the days you fasted.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.REPORT,
    label: 'Weekly, monthly report',
    behaviour: 'REPORT',
    sortOrder: 7,
    description: 'Write or upload your weekly and monthly report.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.DECLARATIONS,
    label: 'Declarations',
    behaviour: 'TEXT',
    sortOrder: 8,
    description: 'The declarations to make out loud.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.AUDIO,
    label: 'Daily / weekly audio messages',
    behaviour: 'MATERIAL',
    sortOrder: 9,
    description: 'Audio messages uploaded for this period.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.PRAYER_PARTNER,
    label: 'Prayer accountability partner',
    behaviour: 'PARTNER',
    sortOrder: 10,
    description:
      'Connect with your prayer accountability partner in the prayer room.',
  },
  {
    key: DAILY_DIET_SECTION_KEYS.MUSIC,
    label: 'Music',
    behaviour: 'MATERIAL',
    sortOrder: 11,
    description:
      'Songs uploaded for this day, or play from your own device library.',
  },
];

/** Default content titles used when an admin creates a section without one. */
export function defaultContentTitle(key) {
  const section = DEFAULT_DAILY_DIET_SECTIONS.find((s) => s.key === key);
  return section?.label ?? 'Daily Diet';
}

/**
 * Resolve the week-of-month (1..6) that a date belongs to. Used to find the
 * weekly plan that carries prayer direction and fasting schedules.
 */
export function weekOfMonth(dateISO) {
  const day = Number.parseInt(dateISO.slice(8, 10), 10);
  return Math.min(6, Math.ceil(day / 7));
}

/**
 * Content can be written for a day, a week or a month. Each scope is stored
 * against an anchor date: the exact day, the Sunday that starts the week, or
 * the first of the month. When a member opens a date the closest scope wins:
 * day → week → month.
 */
export const DAILY_DIET_SCOPES = ['DAY', 'WEEK', 'MONTH'];

/** The Sunday that starts the week containing `dateISO`. */
export function weekAnchorISO(dateISO) {
  const dt = DateTime.fromISO(dateISO, { zone: 'utc' });
  return dt.minus({ days: dt.weekday % 7 }).toFormat('yyyy-MM-dd');
}

/** The first day of the month containing `dateISO`. */
export function monthAnchorISO(dateISO) {
  return `${dateISO.slice(0, 7)}-01`;
}

/**
 * The anchor dates to look for when resolving content for a date, in order
 * of preference: the day itself, its week, then its month.
 */
export function contentAnchors(dateISO) {
  return [
    { scope: 'DAY', date: dateISO },
    { scope: 'WEEK', date: weekAnchorISO(dateISO) },
    { scope: 'MONTH', date: monthAnchorISO(dateISO) },
  ];
}

/**
 * The date a content row is stored against for a given scope: the day itself
 * for `DAY`, the Sunday that starts its week for `WEEK` and the first of its
 * month for `MONTH`. Administrators may pick any day of the period; the row is
 * always filed against the anchor so members find it on every matching day.
 */
export function anchorDateForScope(dateISO, scope) {
  switch (scope) {
    case 'WEEK':
      return weekAnchorISO(dateISO);
    case 'MONTH':
      return monthAnchorISO(dateISO);
    default:
      return dateISO;
  }
}
