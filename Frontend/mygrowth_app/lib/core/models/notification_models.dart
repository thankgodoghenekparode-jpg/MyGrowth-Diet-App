/// In-app notifications and ministry announcements.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.link,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String type;
  final String? link;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: json['body'] as String?,
      type: (json['type'] ?? 'GENERAL') as String,
      link: json['link'] as String?,
      read: (json['read'] ?? json['isRead'] ?? false) as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.link,
    this.attachmentMaterialId,
    this.audience = 'ALL',
    this.status = 'PUBLISHED',
    this.startsAt,
    this.endsAt,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? link;
  final String? attachmentMaterialId;
  final String audience;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? createdByName;
  final DateTime? createdAt;

  bool get isActiveNow {
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      link: json['link'] as String?,
      attachmentMaterialId: json['attachmentMaterialId'] as String?,
      audience: (json['audience'] ?? 'ALL') as String,
      status: (json['status'] ?? 'PUBLISHED') as String,
      startsAt: json['startsAt'] == null
          ? null
          : DateTime.tryParse(json['startsAt'] as String),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.tryParse(json['endsAt'] as String),
      createdByName: json['createdByName'] as String? ?? json['createdBy']?['name'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
