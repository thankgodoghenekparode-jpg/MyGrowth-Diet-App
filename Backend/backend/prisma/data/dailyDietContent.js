/**
 * Daily Diet seed content for the 2027 programme.
 *
 * Two parts:
 *  1. the structure — the sections a member follows (admin-editable);
 *  2. the content each section carries, drawn from the ministry's own 2027
 *     programme data plus the supplied daily Scripture reading plan.
 *
 * Content is written against an anchor date and a scope:
 *  - DAY   → applies to that one date;
 *  - WEEK  → applies to the week starting on that (Sunday) date;
 *  - MONTH → applies to the whole month.
 *
 * When a member opens a date the closest scope wins, so a monthly prayer
 * direction is shown until an administrator writes a day- or week-specific one.
 */
import { DEFAULT_DAILY_DIET_SECTIONS } from '../../src/lib/dailyDiet.js';
import { scriptureReadingDays2027 } from './scriptureReading2027.js';

const MONTH_NAMES = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/** The Sunday that starts the week containing a date. */
function weekAnchor(dateISO) {
  const d = new Date(`${dateISO}T00:00:00.000Z`);
  const dow = d.getUTCDay(); // 0 = Sunday
  d.setUTCDate(d.getUTCDate() - dow);
  return d.toISOString().slice(0, 10);
}

/**
 * Build every content row for the programme.
 * @param {Array} months the 12 monthly plan definitions
 * @returns {Array<{key: string, date: string, scope: string, title: string, body: string|null, details: object|null}>}
 */
export function buildDailyDietContent(months) {
  const rows = [];
  const scriptureDays = scriptureReadingDays2027();

  // --- Scripture reading: one row per day of 2027 -------------------------
  for (const day of scriptureDays) {
    rows.push({
      key: 'scripture_reading',
      date: day.date,
      scope: 'DAY',
      title: day.reading,
      body: day.focus,
      details: {
        reading: day.reading,
        heading: day.heading,
        focus: day.focus,
        note: day.note,
        month: day.month,
        dayOfMonth: day.day,
        year: 2027,
      },
    });
  }

  // --- Month-scoped content ----------------------------------------------
  for (const month of months) {
    const m = month.month;
    const monthStart = `2027-${String(m).padStart(2, '0')}-01`;
    const monthName = MONTH_NAMES[m - 1];

    // Prayer direction (weekly / monthly).
    rows.push({
      key: 'prayer',
      date: monthStart,
      scope: 'MONTH',
      title: `Prayer — ${month.theme}`,
      body: month.prayerFocus,
      details: {
        monthlyFocus: month.prayerFocus,
        month: monthName,
        year: 2027,
        theme: month.theme,
      },
    });

    // Bible study topic with its teachings.
    const teachings = [
      `Read and meditate on ${month.bibleReadingGuidance}.`,
      month.prayerFocus,
      `Monthly confession: ${month.monthlyConfession}`,
    ];
    rows.push({
      key: 'bible_study',
      date: monthStart,
      scope: 'MONTH',
      title: month.theme,
      body: [
        `Topic: ${month.theme}`,
        '',
        'Teachings:',
        ...teachings.map((t, i) => `${i + 1}. ${t}`),
      ].join('\n'),
      details: {
        topic: month.theme,
        month: monthName,
        year: 2027,
        teachings,
        books: month.bibleReadingGuidance,
      },
    });

    // Fasting days for the month.
    rows.push({
      key: 'fasting_and_prayer',
      date: monthStart,
      scope: 'MONTH',
      title: `Fasting — ${monthName} ${2027}`,
      body: month.fastingGuidance,
      details: {
        guidance: month.fastingGuidance,
        month: monthName,
        year: 2027,
      },
    });

    // Declarations to make out loud.
    rows.push({
      key: 'declarations',
      date: monthStart,
      scope: 'MONTH',
      title: `Declarations — ${monthName} ${2027}`,
      body: [month.monthlyConfession, PROGRAMME_AFFIRMATION]
        .filter(Boolean)
        .join('\n\n'),
      details: {
        declarations: [
          month.monthlyConfession,
          PROGRAMME_AFFIRMATION,
        ].filter(Boolean),
        month: monthName,
        year: 2027,
      },
    });

    // Literature for the month (the administrator uploads the files).
    rows.push({
      key: 'literature_reading',
      date: monthStart,
      scope: 'MONTH',
      title: `Literature — ${monthName} ${2027}`,
      body: month.literatureList
        .map((book) =>
          book.author ? `${book.title} — ${book.author}` : book.title
        )
        .join('\n'),
      details: {
        books: month.literatureList,
        month: monthName,
        year: 2027,
      },
    });

    // Audio messages for the month.
    rows.push({
      key: 'audio_message',
      date: monthStart,
      scope: 'MONTH',
      title: `Audio messages — ${monthName} ${2027}`,
      body: month.audioMessages.join('\n'),
      details: {
        messages: month.audioMessages,
        month: monthName,
        year: 2027,
      },
    });

    // Weekly / monthly report prompts.
    rows.push({
      key: 'report',
      date: monthStart,
      scope: 'MONTH',
      title: `Weekly & monthly report — ${monthName} ${2027}`,
      body: month.reflectionQuestions.join('\n'),
      details: {
        questions: month.reflectionQuestions,
        month: monthName,
        year: 2027,
      },
    });
  }

  // --- Week-scoped prayer direction --------------------------------------
  // Six weeks per month, each anchored on the Sunday that starts it.
  for (const month of months) {
    const daysInMonth = new Date(Date.UTC(2027, month.month, 0)).getUTCDate();
    for (let week = 1; week <= 5; week += 1) {
      const firstOfWeek = (week - 1) * 7 + 1;
      if (firstOfWeek > daysInMonth) break;
      const anchor = weekAnchor(
        `2027-${String(month.month).padStart(2, '0')}-${String(
          firstOfWeek
        ).padStart(2, '0')}`
      );
      rows.push({
        key: 'prayer',
        date: anchor,
        scope: 'WEEK',
        title: `Prayer — ${MONTH_NAMES[month.month - 1]} (week ${week})`,
        body: month.prayerFocus,
        details: {
          monthlyFocus: month.prayerFocus,
          week,
          month: MONTH_NAMES[month.month - 1],
          year: 2027,
        },
      });
    }
  }

  // --- Daily proverbs -----------------------------------------------------
  // The ministry supplies the proverb text itself; until then each day points
  // the member at the month's Proverbs reading.
  for (const day of scriptureDays) {
    const month = months[day.month - 1];
    rows.push({
      key: 'proverbs_reading',
      date: day.date,
      scope: 'DAY',
      title: 'Daily proverbs',
      body: `Read today's proverb in Proverbs and meditate on it. This month's reading: ${month.bibleReadingGuidance}.`,
      details: {
        books: month.bibleReadingGuidance,
        month: MONTH_NAMES[day.month - 1],
        dayOfMonth: day.day,
        year: 2027,
      },
    });
  }

  return rows;
}

const PROGRAMME_AFFIRMATION =
  'I affirm that goodness and mercy follow me all the days of my life. I am healed, favored, protected, provided for, promoted, and divinely guided. Angels guard my path, and God is working all things together for my good.';

export { DEFAULT_DAILY_DIET_SECTIONS };
