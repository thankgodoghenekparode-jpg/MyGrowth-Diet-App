/**
 * Canonical structured fields for each accountability report type.
 * The Flutter app renders forms from these definitions (GET /api/v1/me/report-fields),
 * so questions can evolve without hardcoding them in components.
 * All values are stored as text in ReportAnswer (one row per field key).
 */
export const REPORT_FIELDS = {
  WEEKLY: [
    { key: 'planned_activity_summary', label: 'Planned activity summary for the week', multiline: true },
    { key: 'bible_reading_progress', label: 'Bible-reading progress', multiline: true },
    { key: 'prayer_participation', label: 'Prayer participation / duration (self-reported)', multiline: true },
    { key: 'literature_progress', label: 'Literature-reading progress', multiline: true },
    { key: 'bible_study_participation', label: 'Bible-study participation', multiline: true },
    { key: 'fasting_participation', label: 'Fasting participation, where scheduled', multiline: true },
    { key: 'audio_participation', label: 'Audio-message participation', multiline: true },
    { key: 'goals_status', label: 'Goals and their status', multiline: true },
    { key: 'learnings', label: 'What did I learn this week?', multiline: true },
    { key: 'impactful_scripture', label: 'Which Scripture impacted me most?', multiline: true },
    { key: 'progress', label: 'What progress did I make?', multiline: true },
    { key: 'challenges', label: 'What challenges did I encounter?', multiline: true },
    { key: 'improvements_next_week', label: 'What will I improve next week?', multiline: true },
    { key: 'testimony', label: 'Testimony (optional)', multiline: true, optional: true },
  ],
  MONTHLY: [
    { key: 'monthly_goals', label: 'Monthly goals (three or more) and their status', multiline: true },
    { key: 'bible_reading_progress', label: 'Bible-reading progress', multiline: true },
    { key: 'prayer_summary', label: 'Prayer activity summary (self-reported)', multiline: true },
    { key: 'literature_progress', label: 'Literature-reading progress', multiline: true },
    { key: 'fasting_participation', label: 'Fasting participation, where scheduled', multiline: true },
    { key: 'study_audio_participation', label: 'Study / audio-message participation', multiline: true },
    { key: 'lessons_learned', label: 'Lessons learned', multiline: true },
    { key: 'challenges', label: 'Challenges', multiline: true },
    { key: 'improvements_next_month', label: 'Improvements for next month', multiline: true },
    { key: 'testimony', label: 'Testimony (optional)', multiline: true, optional: true },
    { key: 'reflection_q1', label: 'Reflection question 1', multiline: true, dynamic: true },
    { key: 'reflection_q2', label: 'Reflection question 2', multiline: true, dynamic: true },
    { key: 'reflection_q3', label: 'Reflection question 3', multiline: true, dynamic: true },
    { key: 'reflection_q4', label: 'Reflection question 4', multiline: true, dynamic: true },
    { key: 'reflection_q5', label: 'Reflection question 5', multiline: true, dynamic: true },
    { key: 'reflection_q6', label: 'Reflection question 6', multiline: true, dynamic: true },
  ],
  QUARTERLY: [
    { key: 'bible_reading', label: 'Bible reading', multiline: true },
    { key: 'prayer_life', label: 'Prayer life', multiline: true },
    { key: 'stewardship', label: 'Stewardship', multiline: true },
    { key: 'service', label: 'Service', multiline: true },
    { key: 'relationships', label: 'Relationships', multiline: true },
    { key: 'character_growth', label: 'Character growth', multiline: true },
    { key: 'progress_challenges', label: 'Progress and challenges', multiline: true },
    { key: 'lessons_learned', label: 'Lessons learned', multiline: true },
    { key: 'goals_next_quarter', label: 'Goals for next quarter', multiline: true },
    { key: 'testimony', label: 'Testimony (optional)', multiline: true, optional: true },
  ],
  ANNUAL: [
    { key: 'victories', label: 'Victories', multiline: true },
    { key: 'lessons_learned', label: 'Lessons learned', multiline: true },
    { key: 'answered_prayers', label: 'Answered prayers', multiline: true },
    { key: 'relationships', label: 'Relationships', multiline: true },
    { key: 'growth_areas', label: 'Growth areas', multiline: true },
    { key: 'personal_goals', label: 'Personal goals for the following year', multiline: true },
    { key: 'testimonies', label: 'Testimonies', multiline: true },
    { key: 'letter_to_self', label: 'Letter to oneself for the next year', multiline: true, optional: true },
  ],
};

export const REPORT_VISIBILITY_NOTICE =
  'Submitted reports are visible to authorised ministry administrators for accountability and review. Your private reflections and journals are never included.';

/**
 * Additional answer keys accepted for storage but not part of the canonical
 * form definitions above.
 *
 * The Flutter client renders its forms from a local spec that uses camelCase
 * keys (e.g. `weeklyActivitySummary`) and 0-based reflection keys
 * (`reflection_0`); the e2e smoke test posts a handful of shorthand keys
 * (`learned`, `scripture`, …). Every report may additionally carry the member's
 * `followUpReply`. These are all persisted verbatim as ReportAnswer rows so no
 * answer is ever lost — they simply are not advertised as canonical fields.
 */
const CLIENT_ANSWER_ALIASES = {
  WEEKLY: [
    // e2e smoke shorthand
    'learned',
    'scripture',
    'improvement',
    // Flutter form keys
    'weeklyActivitySummary',
    'bibleReadingProgress',
    'prayerParticipation',
    'literatureProgress',
    'bibleStudyParticipation',
    'fastingParticipation',
    'audioParticipation',
    'goalsAndStatus',
    'impactedScripture',
    'progressMade',
    'improvements',
  ],
  MONTHLY: [
    // Flutter goal rows
    'goal1Title',
    'goal1Status',
    'goal2Title',
    'goal2Status',
    'goal3Title',
    'goal3Status',
    // Flutter form keys
    'bibleReadingProgress',
    'prayerSummary',
    'literatureProgress',
    'fastingParticipation',
    'studyAudioParticipation',
    'lessonsLearned',
    'challenges',
    'improvements',
    'testimony',
  ],
  QUARTERLY: [
    // Flutter rating + comment pairs
    'bibleReadingRating',
    'bibleReadingComment',
    'prayerLifeRating',
    'prayerLifeComment',
    'stewardshipRating',
    'stewardshipComment',
    'serviceRating',
    'serviceComment',
    'relationshipsRating',
    'relationshipsComment',
    'characterGrowthRating',
    'characterGrowthComment',
    // Flutter form keys
    'progress',
    'challenges',
    'lessons',
    'nextQuarterGoals',
  ],
  ANNUAL: [
    'lessonsLearned',
    'answeredPrayers',
    'growthAreas',
    'personalGoals',
    'letterToSelf',
  ],
};

/** Members can always add a free-text reply to an admin follow-up request. */
export const FOLLOW_UP_REPLY_KEY = 'followUpReply';

export function allowedFieldKeys(reportType) {
  const fields = REPORT_FIELDS[reportType] || [];
  const keys = fields.map((f) => f.key);
  // Monthly reflection answers follow the monthly plan's question count. The
  // canonical keys are 1-based (`reflection_q1`); the Flutter form emits
  // 0-based (`reflection_0`) keys, so accept both.
  if (reportType === 'MONTHLY') {
    for (let i = 1; i <= 12; i += 1) keys.push(`reflection_q${i}`);
    for (let i = 0; i < 20; i += 1) keys.push(`reflection_${i}`);
  }
  keys.push(...(CLIENT_ANSWER_ALIASES[reportType] || []));
  keys.push(FOLLOW_UP_REPLY_KEY);
  return keys;
}

export function requiredFieldKeys(reportType) {
  return (REPORT_FIELDS[reportType] || []).filter((f) => !f.optional && !f.dynamic).map((f) => f.key);
}
