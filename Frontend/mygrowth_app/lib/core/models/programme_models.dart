/// Programme content model: Annual Programme → Month → Week → Day/Activity.
class AnnualProgramme {
  const AnnualProgramme({
    required this.id,
    required this.title,
    required this.year,
    required this.ministryName,
    this.description,
    this.prayerFocus,
    this.dailyAffirmation,
    this.startDate,
    this.endDate,
    required this.status,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int year;
  final String ministryName;
  final String? description;
  final String? prayerFocus;
  final String? dailyAffirmation;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // DRAFT | PUBLISHED | ARCHIVED
  final DateTime? updatedAt;

  bool get isPublished => status == 'PUBLISHED';

  factory AnnualProgramme.fromJson(Map<String, dynamic> json) {
    return AnnualProgramme(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      year: (json['year'] as num?)?.toInt() ?? 0,
      ministryName: (json['ministryName'] ?? '') as String,
      description: json['description'] as String?,
      prayerFocus: json['prayerFocus'] as String?,
      dailyAffirmation: json['dailyAffirmation'] as String?,
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      status: (json['status'] ?? 'DRAFT') as String,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}

class MonthlyPlan {
  const MonthlyPlan({
    required this.id,
    required this.month,
    required this.year,
    this.theme,
    this.prayerFocus,
    this.bibleReadingGuidance,
    this.literatureList,
    this.audioMessageList,
    this.fastingGuidance,
    this.confession,
    this.goalsGuidance,
    this.reflectionQuestions = const [],
    required this.status,
    this.programmeId,
  });

  final String id;
  final int month; // 1-12
  final int year;
  final String? theme;
  final String? prayerFocus;
  final String? bibleReadingGuidance;
  final String? literatureList;
  final String? audioMessageList;
  final String? fastingGuidance;
  final String? confession;
  final String? goalsGuidance;
  final List<String> reflectionQuestions;
  final String status;
  final String? programmeId;

  factory MonthlyPlan.fromJson(Map<String, dynamic> json) {
    return MonthlyPlan(
      id: json['id'] as String,
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      theme: _str(json['theme']),
      prayerFocus: _str(json['prayerFocus']),
      bibleReadingGuidance: _str(json['bibleReadingGuidance']),
      literatureList: _joinList(json['literatureList']),
      audioMessageList:
          _joinList(json['audioMessages'] ?? json['audioMessageList']),
      fastingGuidance: _str(json['fastingGuidance']),
      confession: _str(json['monthlyConfession'] ?? json['confession']),
      goalsGuidance:
          _str(json['monthlyGoalsGuidance'] ?? json['goalsGuidance']),
      reflectionQuestions: (json['reflectionQuestions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      status: (json['status'] ?? 'PUBLISHED') as String,
      programmeId: json['programmeId'] as String?,
    );
  }
}

/// Null-safe string coercion for optional text fields.
String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

/// Joins a list of materials (`{title, author?}` / `{title, speaker?}` / plain
/// strings) into a single newline-separated string for display.
String? _joinList(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is List) {
    final lines = <String>[];
    for (final item in value) {
      if (item is Map) {
        final title = item['title'] ?? item['name'] ?? '';
        final by = item['author'] ?? item['speaker'] ?? '';
        final line = by.toString().trim().isEmpty
            ? title.toString().trim()
            : '${title.toString().trim()} — ${by.toString().trim()}';
        if (line.isNotEmpty) lines.add(line);
      } else if (item.toString().trim().isNotEmpty) {
        lines.add(item.toString().trim());
      }
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
  return value.toString();
}

class WeeklyPlan {
  const WeeklyPlan({
    required this.id,
    required this.weekNumber,
    this.startDate,
    this.endDate,
    this.bibleReading,
    this.prayerDurationTarget,
    this.bookReading,
    this.fastingSchedule,
    this.keyLessonPrompt,
    this.memoryVerse,
    this.extraActivities,
    required this.status,
    this.monthlyPlanId,
    this.materialsJson,
  });

  final String id;
  final int weekNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? bibleReading;
  final String? prayerDurationTarget;
  final String? bookReading;
  final String? fastingSchedule;
  final String? keyLessonPrompt;
  final String? memoryVerse;
  final String? extraActivities;
  final String status;
  final String? monthlyPlanId;
  final String? materialsJson;

  bool get isEmptyPlan =>
      bibleReading == null &&
      prayerDurationTarget == null &&
      bookReading == null &&
      memoryVerse == null;

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    return WeeklyPlan(
      id: json['id'] as String,
      weekNumber: (json['weekNumber'] as num).toInt(),
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      bibleReading: json['bibleReading'] as String?,
      prayerDurationTarget: json['prayerDurationTarget'] as String?,
      bookReading: json['bookReading'] as String?,
      fastingSchedule: json['fastingSchedule'] as String?,
      keyLessonPrompt: json['keyLessonPrompt'] as String?,
      memoryVerse: json['memoryVerse'] as String?,
      extraActivities: json['extraActivities'] as String?,
      status: (json['status'] ?? 'PUBLISHED') as String,
      monthlyPlanId: json['monthlyPlanId'] as String?,
      materialsJson: json['materials'] is String
          ? json['materials'] as String
          : (json['materials'] == null
              ? null
              : (json['materials'] as List<dynamic>).length.toString()),
    );
  }
}
