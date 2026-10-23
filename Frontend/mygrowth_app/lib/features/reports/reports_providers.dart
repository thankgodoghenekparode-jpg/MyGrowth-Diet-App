import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/report_models.dart';

/// Reports of one type (WEEKLY | MONTHLY | QUARTERLY | ANNUAL).
final reportsListProvider =
    FutureProvider.autoDispose.family<List<Report>, String>(
  (ref, type) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/me/reports', query: {'type': type});
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Report.fromJson)
          .toList();
    }
    return const [];
  },
);

/// A single report for the detail screen.
final reportDetailProvider =
    FutureProvider.autoDispose.family<Report?, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/me/reports/$id');
    if (data is Map<String, dynamic>) return Report.fromJson(data);
    return null;
  },
);

// ---------------------------------------------------------------- fields

enum ReportFieldKind { text, rating, goal }

/// One dynamic field in a report form.
class ReportFieldSpec {
  const ReportFieldSpec._(this.key, this.label, this.kind, {this.maxLines});

  /// A plain text area. Stored under [key].
  const ReportFieldSpec.text(
    String key,
    String label, {
    int maxLines = 4,
  }) : this._(key, label, ReportFieldKind.text, maxLines: maxLines);

  /// A rating dropdown (`${key}Rating`) plus comment (`${key}Comment`).
  const ReportFieldSpec.rating(String key, String label)
      : this._(key, label, ReportFieldKind.rating);

  /// A goal row: title (`${key}Title`) + status (`${key}Status`).
  const ReportFieldSpec.goal(String key, String label)
      : this._(key, label, ReportFieldKind.goal);

  final String key;
  final String label;
  final ReportFieldKind kind;
  final int? maxLines;
}

const ratingOptions = <(String, String)>[
  ('COMPLETED', 'Completed'),
  ('PARTIAL', 'Partial'),
  ('NOT_COMPLETED', 'Not completed'),
];

const goalStatusOptions = <(String, String)>[
  ('NOT_STARTED', 'Not started'),
  ('IN_PROGRESS', 'In progress'),
  ('COMPLETED', 'Completed'),
  ('ABANDONED', 'Dropped'),
];

/// The dynamic field set per report type (spec-driven).
List<ReportFieldSpec> reportFieldsFor(String type) {
  switch (type.toUpperCase()) {
    case 'WEEKLY':
      return const [
        ReportFieldSpec.text('weeklyActivitySummary', 'Planned activity summary'),
        ReportFieldSpec.text('bibleReadingProgress', 'Bible-reading progress'),
        ReportFieldSpec.text(
            'prayerParticipation', 'Prayer participation & duration'),
        ReportFieldSpec.text('literatureProgress', 'Literature progress'),
        ReportFieldSpec.text('bibleStudyParticipation', 'Bible-study participation'),
        ReportFieldSpec.text('fastingParticipation', 'Fasting participation'),
        ReportFieldSpec.text(
            'audioParticipation', 'Audio-message participation'),
        ReportFieldSpec.text('goalsAndStatus', 'Goals and their status'),
        ReportFieldSpec.text('learnings', 'What did I learn this week?'),
        ReportFieldSpec.text(
            'impactedScripture', 'Which Scripture impacted me most?'),
        ReportFieldSpec.text('progressMade', 'What progress did I make?'),
        ReportFieldSpec.text(
            'challenges', 'What challenges did I encounter?'),
        ReportFieldSpec.text(
            'improvements', 'What will I improve next week?'),
        ReportFieldSpec.text('testimony', 'Testimony (optional)', maxLines: 3),
      ];
    case 'MONTHLY':
      return const [
        ReportFieldSpec.goal('goal1', 'Goal 1'),
        ReportFieldSpec.goal('goal2', 'Goal 2'),
        ReportFieldSpec.goal('goal3', 'Goal 3'),
        ReportFieldSpec.text('bibleReadingProgress', 'Bible-reading progress'),
        ReportFieldSpec.text('prayerSummary', 'Prayer summary'),
        ReportFieldSpec.text('literatureProgress', 'Literature progress'),
        ReportFieldSpec.text('fastingParticipation', 'Fasting participation'),
        ReportFieldSpec.text(
            'studyAudioParticipation', 'Bible-study & audio-message participation'),
        ReportFieldSpec.text('lessonsLearned', 'Lessons learned'),
        ReportFieldSpec.text('challenges', 'Challenges encountered'),
        ReportFieldSpec.text('improvements', 'Improvements for next month'),
        ReportFieldSpec.text('testimony', 'Testimony (optional)', maxLines: 3),
      ];
    case 'QUARTERLY':
      return const [
        ReportFieldSpec.rating('bibleReading', 'Bible reading review'),
        ReportFieldSpec.rating('prayerLife', 'Prayer life review'),
        ReportFieldSpec.rating('stewardship', 'Stewardship review'),
        ReportFieldSpec.rating('service', 'Service review'),
        ReportFieldSpec.rating('relationships', 'Relationships review'),
        ReportFieldSpec.rating('characterGrowth', 'Character growth review'),
        ReportFieldSpec.text('progress', 'Overall progress this quarter'),
        ReportFieldSpec.text('challenges', 'Challenges'),
        ReportFieldSpec.text('lessons', 'Lessons learned'),
        ReportFieldSpec.text('nextQuarterGoals', 'Goals for next quarter'),
        ReportFieldSpec.text('testimony', 'Testimony (optional)', maxLines: 3),
      ];
    case 'ANNUAL':
      return const [
        ReportFieldSpec.text('victories', 'Victories this year'),
        ReportFieldSpec.text('lessonsLearned', 'Lessons learned'),
        ReportFieldSpec.text('answeredPrayers', 'Answered prayers'),
        ReportFieldSpec.text('relationships', 'Relationships'),
        ReportFieldSpec.text('growthAreas', 'Growth areas'),
        ReportFieldSpec.text('personalGoals', 'Personal goals'),
        ReportFieldSpec.text('testimonies', 'Testimonies'),
        ReportFieldSpec.text(
            'letterToSelf',
            'Letter to yourself (written now, read next year)',
            maxLines: 10),
      ];
    default:
      return const [];
  }
}

/// Human label for an answers key (also used for extra keys the form
/// doesn't know about, e.g. reflection questions).
String reportAnswerLabel(String key) {
  if (key.startsWith('reflection_')) return 'Reflection question';
  final base = key
      .replaceAll('Comment', '')
      .replaceAll('Rating', '')
      .replaceAll('Status', '')
      .replaceAll('Title', '');
  final words = base
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
      .replaceAll('_', ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return words.isEmpty ? key : words;
}

// ----------------------------------------------------------- period keys

/// Builds a period key for "new report" flows, e.g. '2026-W07',
/// '2026-03', '2026-Q1', '2026'.
String periodKeyFor(String type, DateTime date) {
  switch (type.toUpperCase()) {
    case 'WEEKLY':
      final firstJan = DateTime(date.year, 1, 1);
      final dayOffset = date.difference(firstJan).inDays;
      final week = ((dayOffset + firstJan.weekday) / 7).ceil().clamp(1, 53);
      return '${date.year}-W${week.toString().padLeft(2, '0')}';
    case 'MONTHLY':
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    case 'QUARTERLY':
      return '${date.year}-Q${((date.month - 1) ~/ 3) + 1}';
    default:
      return '${date.year}';
  }
}

/// Best-effort start date of the period a report covers (used to fetch the
/// matching monthly plan for reflection questions / confession).
DateTime periodStartDateFor(String type, String periodKey) {
  final now = DateTime.now();
  switch (type.toUpperCase()) {
    case 'MONTHLY':
      final parts = periodKey.split('-');
      if (parts.length >= 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          return DateTime(year, month);
        }
      }
      return DateTime(now.year, now.month);
    case 'QUARTERLY':
      final parts = periodKey.split('-Q');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final quarter = int.tryParse(parts[1]);
        if (year != null && quarter != null && quarter >= 1 && quarter <= 4) {
          return DateTime(year, (quarter - 1) * 3 + 1);
        }
      }
      return DateTime(now.year, (now.month - 1) ~/ 3 * 3 + 1);
    case 'WEEKLY':
      final parts = periodKey.split('-W');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final week = int.tryParse(parts[1]);
        if (year != null && week != null && week >= 1 && week <= 53) {
          final firstJan = DateTime(year, 1, 1);
          return firstJan.add(Duration(days: (week - 1) * 7));
        }
      }
      return now;
    default:
      return DateTime(now.year, 1);
  }
}

/// Fallback confession shown when the API doesn't expose a quarterly one.
const quarterlyConfessionFallback =
    'I am growing daily in faith, love and discipline. God’s Word guides '
    'my steps, prayer anchors my day, and the Holy Spirit shapes my '
    'character. I press on — grace by grace.';

/// Formats a period key for display, e.g. '2026-03' → 'March 2026'.
String humanizePeriodKey(String periodKey) {
  final monthly = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(periodKey);
  if (monthly != null) {
    final year = int.tryParse(monthly.group(1)!);
    final month = int.tryParse(monthly.group(2)!);
    if (year != null && month != null && month >= 1 && month <= 12) {
      return DateFormat('MMMM yyyy').format(DateTime(year, month));
    }
  }
  final quarterly = RegExp(r'^(\d{4})-Q([1-4])$').firstMatch(periodKey);
  if (quarterly != null) {
    return 'Q${quarterly.group(2)} ${quarterly.group(1)}';
  }
  final weekly = RegExp(r'^(\d{4})-W(\d{1,2})$').firstMatch(periodKey);
  if (weekly != null) {
    return 'Week ${weekly.group(2)}, ${weekly.group(1)}';
  }
  return periodKey;
}
