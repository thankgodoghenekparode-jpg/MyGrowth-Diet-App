import { isoDate } from './dates.js';

/**
 * Canonical JSON shapes for programme content.
 *
 * The storage column names (from the Prisma schema / spec) are the source of
 * truth and are always present. A small number of display aliases are also
 * emitted so the provided Flutter client — which reads `ministryName`,
 * `confession`, `goalsGuidance`, `audioMessageList`, `prayerDurationTarget`,
 * etc. — renders content without any client changes.
 *
 * Json columns may hold either a structured array (as authored via the admin
 * API and the seed) or a free-text string (as authored from the mobile admin
 * editor). `textList` renders both into one display string while the raw value
 * is preserved under a sibling `*Items` key.
 */

function textList(value) {
  if (value == null) return null;
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) {
    const parts = value
      .map((entry) => {
        if (entry == null) return '';
        if (typeof entry === 'string') return entry;
        return entry.title || entry.name || '';
      })
      .filter((s) => s && s.trim().length > 0);
    return parts.length ? parts.join('; ') : null;
  }
  try {
    return JSON.stringify(value);
  } catch {
    return null;
  }
}

export const programmeShape = (p) => ({
  id: p.id,
  title: p.title,
  year: p.year,
  ministry: p.ministry,
  ministryName: p.ministry,
  description: p.description,
  annualPrayerFocus: p.annualPrayerFocus,
  prayerFocus: p.annualPrayerFocus,
  dailyAffirmation: p.dailyAffirmation,
  startDate: p.startDate ? isoDate(p.startDate) : null,
  endDate: p.endDate ? isoDate(p.endDate) : null,
  status: p.status,
  publishedAt: p.publishedAt,
  updatedAt: p.updatedAt,
});

export const monthShape = (m) => ({
  id: m.id,
  programmeId: m.programmeId,
  month: m.month,
  year: m.year,
  theme: m.theme,
  prayerFocus: m.prayerFocus,
  bibleReadingGuidance: m.bibleReadingGuidance,
  // Structured value preserved; display string for the mobile client.
  literatureItems: m.literatureList ?? null,
  literatureList: textList(m.literatureList),
  audioMessages: m.audioMessages ?? null,
  audioMessageList: textList(m.audioMessages),
  fastingGuidance: m.fastingGuidance,
  monthlyConfession: m.monthlyConfession,
  confession: m.monthlyConfession,
  monthlyGoalsGuidance: m.monthlyGoalsGuidance,
  goalsGuidance: m.monthlyGoalsGuidance,
  reflectionQuestions: m.reflectionQuestions,
  status: m.status,
});

export const weeklyShape = (w) => ({
  id: w.id,
  programmeId: w.programmeId,
  monthlyPlanId: w.monthlyPlanId,
  weekNumber: w.weekNumber,
  startDate: w.startDate ? isoDate(w.startDate) : null,
  endDate: w.endDate ? isoDate(w.endDate) : null,
  bibleReading: w.bibleReading,
  prayerDurationTargetMinutes: w.prayerDurationTargetMinutes,
  prayerDurationTarget:
    w.prayerDurationTargetMinutes != null ? String(w.prayerDurationTargetMinutes) : null,
  bookReading: w.bookReading,
  fastingSchedule: w.fastingSchedule,
  keyLessonPrompt: w.keyLessonPrompt,
  memoryVerse: w.memoryVerse,
  studyMaterialIds: w.studyMaterialIds,
  audioMaterialIds: w.audioMaterialIds,
  extraActivitiesItems: w.extraActivities ?? null,
  extraActivities: textList(w.extraActivities),
  status: w.status,
});

export { textList };
