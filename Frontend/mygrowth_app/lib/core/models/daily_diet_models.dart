/// Models for the Daily Diet.
///
/// The Daily Diet is the per-day devotional structure an administrator
/// configures (which sections exist, their order, their labels and how each
/// one behaves). A member picks a date, reads that day's content and ticks
/// each section off.
///
/// The backend resolves content by scope — day content wins over week content,
/// which wins over month content — so every section carries the scope of the
/// content that was found for it.
library;

/// How a Daily Diet section behaves for the member.
enum DailyDietBehaviour {
  text,
  material,
  timer,
  tick,
  report,
  partner;

  static DailyDietBehaviour fromJson(String? raw) =>
      switch (raw?.trim().toUpperCase()) {
        'MATERIAL' => DailyDietBehaviour.material,
        'TIMER' => DailyDietBehaviour.timer,
        'TICK' => DailyDietBehaviour.tick,
        'REPORT' => DailyDietBehaviour.report,
        'PARTNER' => DailyDietBehaviour.partner,
        _ => DailyDietBehaviour.text,
      };

  String get label => switch (this) {
        DailyDietBehaviour.text => 'Reading',
        DailyDietBehaviour.material => 'Files',
        DailyDietBehaviour.timer => 'Stopwatch',
        DailyDietBehaviour.tick => 'Tick',
        DailyDietBehaviour.report => 'Report',
        DailyDietBehaviour.partner => 'Prayer room',
      };

  /// The verb used on the "mark as done" button.
  String get doneLabel => switch (this) {
        DailyDietBehaviour.text => 'Mark as read',
        DailyDietBehaviour.material => 'Mark as opened',
        DailyDietBehaviour.timer => 'Record prayer time',
        DailyDietBehaviour.tick => 'Mark as fasted',
        DailyDietBehaviour.report => 'Mark report as done',
        DailyDietBehaviour.partner => 'Mark as done',
      };

  /// The value the API expects on the wire.
  String get wire => switch (this) {
        DailyDietBehaviour.text => 'TEXT',
        DailyDietBehaviour.material => 'MATERIAL',
        DailyDietBehaviour.timer => 'TIMER',
        DailyDietBehaviour.tick => 'TICK',
        DailyDietBehaviour.report => 'REPORT',
        DailyDietBehaviour.partner => 'PARTNER',
      };
}

/// How far a piece of Daily Diet content reaches.
enum DailyDietScope {
  day,
  week,
  month;

  static DailyDietScope fromJson(String? raw) =>
      switch (raw?.trim().toUpperCase()) {
        'WEEK' => DailyDietScope.week,
        'MONTH' => DailyDietScope.month,
        _ => DailyDietScope.day,
      };

  String get label => switch (this) {
        DailyDietScope.day => 'This day',
        DailyDietScope.week => 'This week',
        DailyDietScope.month => 'This month',
      };

  /// The value the API expects on the wire.
  String get wire => switch (this) {
        DailyDietScope.day => 'DAY',
        DailyDietScope.week => 'WEEK',
        DailyDietScope.month => 'MONTH',
      };
}

/// Completion status of a member's tick-off.
enum DailyDietStatus {
  notStarted,
  inProgress,
  completed,
  skipped,
  notApplicable;

  static DailyDietStatus fromJson(String? raw) =>
      switch (raw?.trim().toUpperCase()) {
        'IN_PROGRESS' => DailyDietStatus.inProgress,
        'COMPLETED' => DailyDietStatus.completed,
        'SKIPPED' => DailyDietStatus.skipped,
        'NOT_APPLICABLE' => DailyDietStatus.notApplicable,
        _ => DailyDietStatus.notStarted,
      };

  String get label => switch (this) {
        DailyDietStatus.notStarted => 'Not started',
        DailyDietStatus.inProgress => 'In progress',
        DailyDietStatus.completed => 'Completed',
        DailyDietStatus.skipped => 'Skipped',
        DailyDietStatus.notApplicable => 'Not applicable',
      };

  /// The value the API expects on the wire.
  String get wire => switch (this) {
        DailyDietStatus.notStarted => 'NOT_STARTED',
        DailyDietStatus.inProgress => 'IN_PROGRESS',
        DailyDietStatus.completed => 'COMPLETED',
        DailyDietStatus.skipped => 'SKIPPED',
        DailyDietStatus.notApplicable => 'NOT_APPLICABLE',
      };
}

/// Formats a date as the API expects it (`yyyy-MM-dd`).
String dailyDietDateISO(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Midnight on the given day.
DateTime dailyDietDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// The content a section carries on a date.
class DailyDietContent {
  const DailyDietContent({
    required this.id,
    required this.sectionId,
    required this.date,
    required this.scope,
    required this.title,
    this.body,
    this.details,
    this.materialIds = const [],
    this.externalUrl,
    this.durationTargetMinutes,
    this.status = 'PUBLISHED',
  });

  final String id;
  final String sectionId;
  final String date;
  final DailyDietScope scope;
  final String title;
  final String? body;
  final Map<String, dynamic>? details;
  final List<String> materialIds;
  final String? externalUrl;
  final int? durationTargetMinutes;
  final String status;

  bool get hasBody =>
      body != null && body!.trim().isNotEmpty && body != title;

  String? _string(String key) {
    final value = details?[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  List<String> _stringList(String key) {
    final value = details?[key];
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    // A single value stored on its own still reads as a one-item list.
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  /// Reads a detail that may arrive as a list of objects, a single object, a
  /// list of strings or a plain string.
  List<Map<String, dynamic>> _mapList(String key) {
    final value = details?[key];
    if (value is List) {
      return value
          .map((entry) {
            if (entry is Map<String, dynamic>) return entry;
            if (entry is Map) return Map<String, dynamic>.from(entry);
            return <String, dynamic>{'title': entry.toString()};
          })
          .toList();
    }
    if (value is Map) return [Map<String, dynamic>.from(value)];
    if (value is String && value.trim().isNotEmpty) {
      return [
        <String, dynamic>{'title': value.trim()},
      ];
    }
    return const [];
  }

  /// The assigned reading (Scriptures reading).
  String? get reading => _string('reading');

  /// The book the month is working through.
  String? get heading => _string('heading');

  /// The focus of the month's reading.
  String? get focus => _string('focus');

  /// A note that comes with the reading.
  String? get readingNote => _string('note');

  /// The month's Bible study topic.
  String? get topic => _string('topic');

  /// The teachings written under the Bible study topic.
  List<String> get teachings => _stringList('teachings');

  /// Declarations to make out loud.
  List<String> get declarations => _stringList('declarations');

  /// Audio messages for the period.
  List<String> get messages => _stringList('messages');

  /// Report prompts for the period.
  List<String> get questions => _stringList('questions');

  /// The literature list for the period.
  List<Map<String, dynamic>> get books => _mapList('books');

  /// The songs for the period.
  List<String> get songs => _stringList('songs');

  /// The prayer focus for the week or month.
  String? get monthlyFocus => _string('monthlyFocus');

  /// The fasting guidance for the period.
  String? get guidance => _string('guidance');

  factory DailyDietContent.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return DailyDietContent(
      id: (json['id'] ?? '') as String,
      sectionId: (json['sectionId'] ?? '') as String,
      date: (json['date'] ?? '') as String,
      scope: DailyDietScope.fromJson(json['scope'] as String?),
      title: (json['title'] ?? '') as String,
      body: json['body'] as String?,
      details: rawDetails is Map<String, dynamic> ? rawDetails : null,
      materialIds: _stringListFrom(json['materialIds']),
      externalUrl: json['externalUrl'] as String?,
      durationTargetMinutes: (json['durationTargetMinutes'] as num?)?.toInt(),
      status: (json['status'] ?? 'PUBLISHED') as String,
    );
  }

  static List<String> _stringListFrom(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}

/// A study material attached to a Daily Diet section.
class DailyDietMaterial {
  const DailyDietMaterial({
    required this.id,
    required this.title,
    this.description,
    this.category = 'OTHER',
    this.author,
    this.externalUrl,
    this.fileId,
    this.fileType,
    this.fileName,
    this.sizeBytes,
    this.url,
    this.month,
    this.year,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final String? author;
  final String? externalUrl;
  final String? fileId;
  final String? fileType;
  final String? fileName;
  final int? sizeBytes;
  final String? url;
  final int? month;
  final int? year;

  bool get isAudio =>
      category == 'AUDIO' || (fileType?.startsWith('audio') ?? false);

  bool get isFile => fileId != null;

  factory DailyDietMaterial.fromJson(Map<String, dynamic> json) {
    return DailyDietMaterial(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      category: (json['category'] ?? 'OTHER') as String,
      author: (json['author'] ?? json['authorSpeaker']) as String?,
      externalUrl: json['externalUrl'] as String?,
      fileId: json['fileId'] as String?,
      fileType: json['fileType'] as String?,
      fileName: json['fileName'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      url: json['url'] as String?,
      month: (json['month'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
    );
  }
}

/// A file a member attached to their report.
class DailyDietAttachment {
  const DailyDietAttachment({
    required this.id,
    this.originalName,
    this.mimeType,
    this.sizeBytes,
    this.url,
  });

  final String id;
  final String? originalName;
  final String? mimeType;
  final int? sizeBytes;
  final String? url;

  factory DailyDietAttachment.fromJson(Map<String, dynamic> json) {
    return DailyDietAttachment(
      id: (json['id'] ?? '') as String,
      originalName: json['originalName'] as String?,
      mimeType: json['mimeType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      url: json['url'] as String?,
    );
  }
}

/// A member's tick-off of one section on one day.
class DailyDietCompletion {
  const DailyDietCompletion({
    required this.id,
    required this.sectionId,
    required this.date,
    required this.status,
    this.note,
    this.actualDurationMinutes,
    this.actualQuantity,
    this.attachmentFileId,
    this.attachment,
    this.completedAt,
  });

  final String id;
  final String sectionId;
  final String date;
  final DailyDietStatus status;
  final String? note;
  final int? actualDurationMinutes;
  final int? actualQuantity;
  final String? attachmentFileId;
  final DailyDietAttachment? attachment;
  final DateTime? completedAt;

  bool get isCompleted => status == DailyDietStatus.completed;

  factory DailyDietCompletion.fromJson(Map<String, dynamic> json) {
    final rawAttachment = json['attachment'];
    return DailyDietCompletion(
      id: (json['id'] ?? '') as String,
      sectionId: (json['sectionId'] ?? '') as String,
      date: (json['date'] ?? '') as String,
      status: DailyDietStatus.fromJson(json['status'] as String?),
      note: json['note'] as String?,
      actualDurationMinutes: (json['actualDurationMinutes'] as num?)?.toInt(),
      actualQuantity: (json['actualQuantity'] as num?)?.toInt(),
      attachmentFileId: json['attachmentFileId'] as String?,
      attachment: rawAttachment is Map<String, dynamic>
          ? DailyDietAttachment.fromJson(rawAttachment)
          : null,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
    );
  }
}

/// One section of the Daily Diet as the member sees it.
class DailyDietSection {
  const DailyDietSection({
    required this.id,
    required this.key,
    required this.label,
    this.description,
    required this.behaviour,
    required this.sortOrder,
    required this.required,
    required this.allowNote,
    required this.trackCompletion,
    this.content,
    this.materials = const [],
    this.completion,
    this.status = DailyDietStatus.notStarted,
  });

  final String id;
  final String key;
  final String label;
  final String? description;
  final DailyDietBehaviour behaviour;
  final int sortOrder;
  final bool required;
  final bool allowNote;
  final bool trackCompletion;
  final DailyDietContent? content;
  final List<DailyDietMaterial> materials;
  final DailyDietCompletion? completion;
  final DailyDietStatus status;

  bool get isCompleted => completion?.isCompleted ?? false;

  /// A one-line summary shown on the hub tile.
  String get preview {
    if (content != null && content!.title.trim().isNotEmpty) {
      return content!.title;
    }
    if (materials.isNotEmpty) {
      return materials.length == 1
          ? materials.first.title
          : '${materials.length} files attached';
    }
    return description ?? '';
  }

  factory DailyDietSection.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final rawCompletion = json['completion'];
    final rawMaterials = json['materials'];
    return DailyDietSection(
      id: (json['id'] ?? '') as String,
      key: (json['key'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      description: json['description'] as String?,
      behaviour: DailyDietBehaviour.fromJson(json['behaviour'] as String?),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      required: json['required'] as bool? ?? true,
      allowNote: json['allowNote'] as bool? ?? true,
      trackCompletion: json['trackCompletion'] as bool? ?? true,
      content: rawContent is Map<String, dynamic>
          ? DailyDietContent.fromJson(rawContent)
          : null,
      materials: rawMaterials is List
          ? rawMaterials
              .whereType<Map<String, dynamic>>()
              .map(DailyDietMaterial.fromJson)
              .toList()
          : const [],
      completion: rawCompletion is Map<String, dynamic>
          ? DailyDietCompletion.fromJson(rawCompletion)
          : null,
      status: DailyDietStatus.fromJson(json['status'] as String?),
    );
  }
}

/// The programme the Daily Diet belongs to.
class DailyDietProgramme {
  const DailyDietProgramme({
    required this.id,
    required this.title,
    required this.year,
    this.ministry,
    this.annualPrayerFocus,
    this.dailyAffirmation,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String title;
  final int year;
  final String? ministry;
  final String? annualPrayerFocus;
  final String? dailyAffirmation;
  final DateTime? startDate;
  final DateTime? endDate;

  factory DailyDietProgramme.fromJson(Map<String, dynamic> json) {
    return DailyDietProgramme(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      year: (json['year'] as num?)?.toInt() ?? 0,
      ministry: json['ministry'] as String?,
      annualPrayerFocus: json['annualPrayerFocus'] as String?,
      dailyAffirmation: json['dailyAffirmation'] as String?,
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
    );
  }
}

/// The monthly plan context for the selected day.
class DailyDietMonthlyPlan {
  const DailyDietMonthlyPlan({
    required this.id,
    required this.month,
    required this.year,
    this.theme,
    this.prayerFocus,
    this.bibleReadingGuidance,
    this.fastingGuidance,
    this.monthlyConfession,
  });

  final String id;
  final int month;
  final int year;
  final String? theme;
  final String? prayerFocus;
  final String? bibleReadingGuidance;
  final String? fastingGuidance;
  final String? monthlyConfession;

  factory DailyDietMonthlyPlan.fromJson(Map<String, dynamic> json) {
    return DailyDietMonthlyPlan(
      id: (json['id'] ?? '') as String,
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      theme: json['theme'] as String?,
      prayerFocus: json['prayerFocus'] as String?,
      bibleReadingGuidance: json['bibleReadingGuidance'] as String?,
      fastingGuidance: json['fastingGuidance'] as String?,
      monthlyConfession: json['monthlyConfession'] as String?,
    );
  }
}

/// The weekly plan context for the selected day.
class DailyDietWeeklyPlan {
  const DailyDietWeeklyPlan({
    required this.id,
    required this.weekNumber,
    this.startDate,
    this.endDate,
    this.bibleReading,
    this.prayerDurationTargetMinutes,
    this.fastingSchedule,
    this.keyLessonPrompt,
    this.memoryVerse,
  });

  final String id;
  final int weekNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? bibleReading;
  final int? prayerDurationTargetMinutes;
  final String? fastingSchedule;
  final String? keyLessonPrompt;
  final String? memoryVerse;

  factory DailyDietWeeklyPlan.fromJson(Map<String, dynamic> json) {
    return DailyDietWeeklyPlan(
      id: (json['id'] ?? '') as String,
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 0,
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      bibleReading: json['bibleReading'] as String?,
      prayerDurationTargetMinutes:
          (json['prayerDurationTargetMinutes'] as num?)?.toInt(),
      fastingSchedule: json['fastingSchedule'] as String?,
      keyLessonPrompt: json['keyLessonPrompt'] as String?,
      memoryVerse: json['memoryVerse'] as String?,
    );
  }
}

/// Completion counts for the selected day.
class DailyDietProgress {
  const DailyDietProgress({
    required this.completed,
    required this.total,
    required this.ratio,
  });

  final int completed;
  final int total;
  final double ratio;

  factory DailyDietProgress.fromJson(Map<String, dynamic> json) {
    return DailyDietProgress(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Everything the member needs for one day of the Daily Diet.
class DailyDietBundle {
  const DailyDietBundle({
    required this.date,
    required this.dateInProgramme,
    this.programme,
    this.monthlyPlan,
    this.weeklyPlan,
    this.sections = const [],
    required this.progress,
  });

  final String date;
  final bool dateInProgramme;
  final DailyDietProgramme? programme;
  final DailyDietMonthlyPlan? monthlyPlan;
  final DailyDietWeeklyPlan? weeklyPlan;
  final List<DailyDietSection> sections;
  final DailyDietProgress progress;

  factory DailyDietBundle.fromJson(Map<String, dynamic> json) {
    final rawProgramme = json['programme'];
    final rawMonthly = json['monthlyPlan'];
    final rawWeekly = json['weeklyPlan'];
    final rawSections = json['sections'];
    final rawProgress = json['progress'];
    return DailyDietBundle(
      date: (json['date'] ?? '') as String,
      dateInProgramme: json['dateInProgramme'] as bool? ?? true,
      programme: rawProgramme is Map<String, dynamic>
          ? DailyDietProgramme.fromJson(rawProgramme)
          : null,
      monthlyPlan: rawMonthly is Map<String, dynamic>
          ? DailyDietMonthlyPlan.fromJson(rawMonthly)
          : null,
      weeklyPlan: rawWeekly is Map<String, dynamic>
          ? DailyDietWeeklyPlan.fromJson(rawWeekly)
          : null,
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(DailyDietSection.fromJson)
              .toList()
          : const [],
      progress: rawProgress is Map<String, dynamic>
          ? DailyDietProgress.fromJson(rawProgress)
          : const DailyDietProgress(completed: 0, total: 0, ratio: 0),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin-side models
// ---------------------------------------------------------------------------

/// A Daily Diet section as the administrator sees it.
class AdminDailyDietSection {
  const AdminDailyDietSection({
    required this.id,
    required this.programmeId,
    required this.key,
    required this.label,
    this.description,
    required this.behaviour,
    required this.sortOrder,
    required this.enabled,
    required this.required,
    required this.allowNote,
    required this.trackCompletion,
    required this.status,
    this.contentCount = 0,
    this.completionCount = 0,
  });

  final String id;
  final String programmeId;
  final String key;
  final String label;
  final String? description;
  final DailyDietBehaviour behaviour;
  final int sortOrder;
  final bool enabled;
  final bool required;
  final bool allowNote;
  final bool trackCompletion;
  final String status;
  final int contentCount;
  final int completionCount;

  bool get isPublished => status == 'PUBLISHED';

  factory AdminDailyDietSection.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return AdminDailyDietSection(
      id: (json['id'] ?? '') as String,
      programmeId: (json['programmeId'] ?? '') as String,
      key: (json['key'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      description: json['description'] as String?,
      behaviour: DailyDietBehaviour.fromJson(json['behaviour'] as String?),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      required: json['required'] as bool? ?? true,
      allowNote: json['allowNote'] as bool? ?? true,
      trackCompletion: json['trackCompletion'] as bool? ?? true,
      status: (json['status'] ?? 'DRAFT') as String,
      contentCount:
          count is Map<String, dynamic>
              ? (count['contents'] as num?)?.toInt() ?? 0
              : 0,
      completionCount:
          count is Map<String, dynamic>
              ? (count['completions'] as num?)?.toInt() ?? 0
              : 0,
    );
  }
}

/// A Daily Diet content row as the administrator sees it.
class AdminDailyDietContent {
  const AdminDailyDietContent({
    required this.id,
    required this.sectionId,
    this.sectionKey,
    this.sectionLabel,
    required this.date,
    required this.scope,
    required this.title,
    this.body,
    this.details,
    this.materialIds = const [],
    this.externalUrl,
    this.durationTargetMinutes,
    required this.status,
    this.publishedAt,
  });

  final String id;
  final String sectionId;
  final String? sectionKey;
  final String? sectionLabel;
  final String date;
  final DailyDietScope scope;
  final String title;
  final String? body;
  final Map<String, dynamic>? details;
  final List<String> materialIds;
  final String? externalUrl;
  final int? durationTargetMinutes;
  final String status;
  final DateTime? publishedAt;

  bool get isPublished => status == 'PUBLISHED';

  factory AdminDailyDietContent.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    final rawIds = json['materialIds'];
    return AdminDailyDietContent(
      id: (json['id'] ?? '') as String,
      sectionId: (json['sectionId'] ?? '') as String,
      sectionKey: json['sectionKey'] as String?,
      sectionLabel: json['sectionLabel'] as String?,
      date: (json['date'] ?? '') as String,
      scope: DailyDietScope.fromJson(json['scope'] as String?),
      title: (json['title'] ?? '') as String,
      body: json['body'] as String?,
      details: rawDetails is Map<String, dynamic> ? rawDetails : null,
      materialIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [],
      externalUrl: json['externalUrl'] as String?,
      durationTargetMinutes: (json['durationTargetMinutes'] as num?)?.toInt(),
      status: (json['status'] ?? 'DRAFT') as String,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'] as String),
    );
  }
}
