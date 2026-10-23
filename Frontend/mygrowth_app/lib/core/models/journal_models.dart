/// Private reflections/journals and testimonies.
class ReflectionEntry {
  const ReflectionEntry({
    required this.id,
    required this.title,
    required this.body,
    this.entryDate,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? entryDate;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory ReflectionEntry.fromJson(Map<String, dynamic> json) {
    return ReflectionEntry(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? json['content'] ?? '') as String,
      entryDate: json['entryDate'] == null
          ? (json['date'] == null
              ? null
              : DateTime.tryParse(json['date'] as String))
          : DateTime.tryParse(json['entryDate'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

class Testimony {
  const Testimony({
    required this.id,
    required this.title,
    required this.body,
    this.entryDate,
    this.tags = const [],
    this.visibility = 'PRIVATE',
    this.consentToShare = false,
    this.approvalStatus,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? entryDate;
  final List<String> tags;
  final String visibility; // PRIVATE | MINISTRY_ADMINS | COMMUNITY
  final bool consentToShare;
  final String? approvalStatus; // PENDING | APPROVED | REJECTED
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? json['content'] ?? '') as String,
      entryDate: json['entryDate'] == null
          ? (json['date'] == null
              ? null
              : DateTime.tryParse(json['date'] as String))
          : DateTime.tryParse(json['entryDate'] as String),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      visibility: (json['visibility'] ?? 'PRIVATE') as String,
      consentToShare: (json['consentToShare'] ?? false) as bool,
      approvalStatus: json['approvalStatus'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
