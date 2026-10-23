/// Activity categories, planned daily activities and member activity records.
class ActivityCategory {
  const ActivityCategory({required this.key, required this.label, this.icon});

  final String key;
  final String label;
  final String? icon;

  static const List<String> knownKeys = [
    'prayer',
    'scripture_reading',
    'bible_study',
    'literature_reading',
    'proverbs_reading',
    'fasting_and_prayer',
    'prayer_and_affirmations',
    'confessions_declarations',
    'audio_message',
    'prayer_partner_session',
    'personal_reflection',
    'custom',
  ];

  factory ActivityCategory.fromJson(Map<String, dynamic> json) {
    return ActivityCategory(
      key: (json['key'] ?? json['id'] ?? 'custom') as String,
      label: (json['label'] ?? json['name'] ?? 'Activity') as String,
      icon: json['icon'] as String?,
    );
  }
}

/// A single item in the member's daily checklist.
class PlannedActivity {
  const PlannedActivity({
    required this.id,
    required this.title,
    required this.categoryKey,
    this.description,
    this.categoryLabel,
    this.date,
    this.startTime,
    this.targetDuration,
    this.instructions,
    this.trackingEnabled = true,
    this.noteAllowed = true,
    this.sortOrder = 0,
    this.source = 'PROGRAMME', // PROGRAMME | PERSONAL | PARTNER_SESSION
    this.record,
    this.materialId,
  });

  final String id;
  final String title;
  final String categoryKey;
  final String? description;
  final String? categoryLabel;
  final DateTime? date;
  final String? startTime;
  final String? targetDuration;
  final String? instructions;
  final bool trackingEnabled;
  final bool noteAllowed;
  final int sortOrder;
  final String source;
  final ActivityRecord? record;
  final String? materialId;

  String get status => record?.status ?? 'NOT_STARTED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';

  PlannedActivity copyWith({ActivityRecord? record}) => PlannedActivity(
        id: id,
        title: title,
        categoryKey: categoryKey,
        description: description,
        categoryLabel: categoryLabel,
        date: date,
        startTime: startTime,
        targetDuration: targetDuration,
        instructions: instructions,
        trackingEnabled: trackingEnabled,
        noteAllowed: noteAllowed,
        sortOrder: sortOrder,
        source: source,
        record: record,
        materialId: materialId,
      );

  factory PlannedActivity.fromJson(Map<String, dynamic> json) {
    return PlannedActivity(
      id: (json['id'] ?? json['activityId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      categoryKey: (json['categoryKey'] ?? json['category'] ?? 'custom') as String,
      description: json['description'] as String?,
      categoryLabel: json['categoryLabel'] as String?,
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'] as String),
      startTime: json['startTime'] as String?,
      targetDuration: json['targetDuration'] as String?,
      instructions: json['instructions'] as String?,
      trackingEnabled: (json['trackingEnabled'] ?? true) as bool,
      noteAllowed: (json['noteAllowed'] ?? true) as bool,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      source: (json['source'] ?? 'PROGRAMME') as String,
      materialId: json['materialId'] as String?,
      record: json['record'] == null
          ? null
          : ActivityRecord.fromJson(json['record'] as Map<String, dynamic>),
    );
  }
}

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.activityId,
    required this.status,
    this.note,
    this.actualDuration,
    this.actualQuantity,
    this.completedAt,
    this.plannedDate,
    this.title,
    this.categoryKey,
  });

  final String id;
  final String activityId;
  final String status; // NOT_STARTED | IN_PROGRESS | COMPLETED | SKIPPED | NOT_APPLICABLE
  final String? note;
  final String? actualDuration;
  final String? actualQuantity;
  final DateTime? completedAt;
  final DateTime? plannedDate;
  final String? title;
  final String? categoryKey;

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      id: (json['id'] ?? '') as String,
      activityId: (json['activityId'] ?? '') as String,
      status: (json['status'] ?? 'NOT_STARTED') as String,
      note: json['note'] as String?,
      actualDuration: json['actualDuration']?.toString(),
      actualQuantity: json['actualQuantity']?.toString(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
      plannedDate: json['plannedDate'] == null
          ? null
          : DateTime.tryParse(json['plannedDate'] as String),
      title: json['title'] as String?,
      categoryKey: json['categoryKey'] as String?,
    );
  }
}

/// Aggregated member progress summary (self-reported).
class ProgressSummary {
  const ProgressSummary({
    this.totalActivities = 0,
    this.completedActivities = 0,
    this.inProgressActivities = 0,
    this.skippedActivities = 0,
    this.totalMinutesRecorded = 0,
    this.reportsSubmitted = 0,
    this.sessionsCompleted = 0,
    this.currentStreakDays = 0,
    this.byCategory = const {},
    this.byMonth = const [],
  });

  final int totalActivities;
  final int completedActivities;
  final int inProgressActivities;
  final int skippedActivities;
  final int totalMinutesRecorded;
  final int reportsSubmitted;
  final int sessionsCompleted;
  final int currentStreakDays;
  final Map<String, int> byCategory;
  final List<MonthTally> byMonth;

  double get completionRate =>
      totalActivities == 0 ? 0 : completedActivities / totalActivities;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalActivities: (json['totalActivities'] as num?)?.toInt() ?? 0,
      completedActivities: (json['completedActivities'] as num?)?.toInt() ?? 0,
      inProgressActivities: (json['inProgressActivities'] as num?)?.toInt() ?? 0,
      skippedActivities: (json['skippedActivities'] as num?)?.toInt() ?? 0,
      totalMinutesRecorded: (json['totalMinutesRecorded'] as num?)?.toInt() ?? 0,
      reportsSubmitted: (json['reportsSubmitted'] as num?)?.toInt() ?? 0,
      sessionsCompleted: (json['sessionsCompleted'] as num?)?.toInt() ?? 0,
      currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
      byCategory: (json['byCategory'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      byMonth: (json['byMonth'] as List<dynamic>? ?? [])
          .map((e) => MonthTally.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthTally {
  const MonthTally({required this.month, required this.year, required this.completed, required this.total});

  final int month;
  final int year;
  final int completed;
  final int total;

  factory MonthTally.fromJson(Map<String, dynamic> json) => MonthTally(
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}
