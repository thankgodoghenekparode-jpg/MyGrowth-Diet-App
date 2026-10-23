/// Accountability reports: weekly / monthly / quarterly / annual.
class Report {
  const Report({
    required this.id,
    required this.type, // WEEKLY | MONTHLY | QUARTERLY | ANNUAL
    required this.status, // DRAFT | SUBMITTED | REVIEWED | REQUIRES_FOLLOW_UP
    required this.periodKey,
    this.programmeYear,
    this.answers = const {},
    this.memberName,
    this.memberId,
    this.submittedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    this.reviews = const [],
    this.revisionCount = 0,
  });

  final String id;
  final String type;
  final String status;
  final String periodKey;
  final int? programmeYear;
  final Map<String, dynamic> answers;
  final String? memberName;
  final String? memberId;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ReportReview> reviews;
  final int revisionCount;

  bool get isDraft => status == 'DRAFT';
  bool get canEdit => status == 'DRAFT';
  bool get needsAttention => status == 'REQUIRES_FOLLOW_UP';

  String answerFor(String key) {
    final value = answers[key];
    if (value == null) return '';
    if (value is List) return value.map((e) => e.toString()).join('\n');
    return value.toString();
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: (json['id'] ?? '') as String,
      type: (json['reportType'] ?? json['type'] ?? 'WEEKLY') as String,
      status: (json['status'] ?? 'DRAFT') as String,
      periodKey: (json['periodKey'] ?? json['period'] ?? '') as String,
      programmeYear: (json['programmeYear'] as num?)?.toInt(),
      answers: (json['answers'] as Map<String, dynamic>? ??
              json['reportAnswers'] as Map<String, dynamic>? ??
              const {}) ,
      memberName: json['memberName'] as String? ?? _nameOf(json['user']),
      memberId: json['memberId'] as String? ??
          json['userId'] as String? ??
          (json['user'] is Map ? json['user']['id'] as String? : null),
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.tryParse(json['submittedAt'] as String),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.tryParse(json['reviewedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      reviews: (json['reviews'] as List<dynamic>? ?? [])
          .map((e) => ReportReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      revisionCount:
          ((json['revisionCount'] ?? json['revision']) as num?)?.toInt() ?? 0,
    );
  }
}

/// Display name from either a plain string or a `{firstName,lastName}` object.
String? _nameOf(dynamic value) {
  if (value is Map) {
    final first = value['firstName']?.toString() ?? value['name']?.toString() ?? '';
    final last = value['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    return combined.isEmpty ? null : combined;
  }
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

class ReportReview {
  const ReportReview({
    required this.id,
    required this.reportId,
    this.reviewerName,
    this.comment,
    required this.kind, // COMMENT | FOLLOW_UP | REVIEWED
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String? reviewerName;
  final String? comment;
  final String kind;
  final DateTime? createdAt;

  factory ReportReview.fromJson(Map<String, dynamic> json) {
    return ReportReview(
      id: (json['id'] ?? '') as String,
      reportId: (json['reportId'] ?? '') as String,
      reviewerName: json['reviewerName'] as String? ?? _nameOf(json['reviewer']),
      comment: json['comment'] as String?,
      kind: _reviewKindOf(json['kind'] ?? json['action'] ?? json['type']),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

/// Maps the backend review `action` enum onto the UI kind enum.
String _reviewKindOf(dynamic value) {
  switch (value?.toString()) {
    case 'REQUEST_FOLLOW_UP':
    case 'FOLLOW_UP':
      return 'FOLLOW_UP';
    case 'MARK_REVIEWED':
    case 'REVIEWED':
      return 'REVIEWED';
    case 'COMMENT':
    case null:
      return 'COMMENT';
    default:
      return value.toString();
  }
}
