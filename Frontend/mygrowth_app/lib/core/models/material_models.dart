/// Study materials library items (files or external links).
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.author,
    this.externalUrl,
    this.fileId,
    this.fileType,
    this.coverUrl,
    this.month,
    this.year,
    this.status = 'PUBLISHED',
    this.trackCompletion = false,
    this.isCompleted = false,
    this.savedToReadingList = false,
    this.publishedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String category; // PDF, AUDIO, VIDEO, STUDY_NOTES, LITERATURE, PRAYER_GUIDE, SCRIPTURE_LINK, CONFESSION, ANNOUNCEMENT, OTHER
  final String? description;
  final String? author;
  final String? externalUrl;
  final String? fileId;
  final String? fileType;
  final String? coverUrl;
  final int? month;
  final int? year;
  final String status;
  final bool trackCompletion;
  final bool isCompleted;
  final bool savedToReadingList;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  bool get isAudio => category == 'AUDIO' ||
      (fileType?.startsWith('audio') ?? false);
  bool get isVideo => category == 'VIDEO' ||
      (fileType?.startsWith('video') ?? false);
  bool get isLink => externalUrl != null && fileId == null;
  bool get isFile => fileId != null;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      category: (json['category'] ?? 'OTHER') as String,
      description: json['description'] as String?,
      author: (json['author'] ?? json['authorSpeaker']) as String?,
      externalUrl: json['externalUrl'] as String?,
      fileId: json['fileId'] as String?,
      fileType: (json['fileType'] ?? json['file']?['mimeType']) as String?,
      coverUrl: json['coverUrl'] as String?,
      month: (json['month'] as num?)?.toInt(),
      year: (json['year'] ?? json['programmeYear'] as num?)?.toInt(),
      status: (json['status'] ?? 'PUBLISHED') as String,
      trackCompletion: (json['trackCompletion'] ?? false) as bool,
      isCompleted: (json['isCompleted'] ?? false) as bool,
      savedToReadingList: (json['savedToReadingList'] ?? false) as bool,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
