/// Personal weekly/monthly goals with progress tracking.
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.periodType, // WEEKLY | MONTHLY
    required this.status, // ACTIVE | COMPLETED | PAUSED | ABANDONED
    this.description,
    this.startDate,
    this.targetDate,
    this.targetQuantity,
    this.targetUnit,
    this.currentProgress = 0,
    this.privateNote,
    this.periodKey,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String periodType;
  final String status;
  final String? description;
  final DateTime? startDate;
  final DateTime? targetDate;
  final double? targetQuantity;
  final String? targetUnit;
  final double currentProgress;
  final String? privateNote;
  final String? periodKey;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get progressFraction {
    if (targetQuantity == null || targetQuantity! <= 0) {
      return status == 'COMPLETED' ? 1 : 0;
    }
    return (currentProgress / targetQuantity!).clamp(0.0, 1.0);
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      periodType: (json['periodType'] ?? 'MONTHLY') as String,
      status: (json['status'] ?? 'ACTIVE') as String,
      description: json['description'] as String?,
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      targetDate: json['targetDate'] == null
          ? null
          : DateTime.tryParse(json['targetDate'] as String),
      targetQuantity: (json['targetQuantity'] as num?)?.toDouble(),
      targetUnit: json['targetUnit'] as String?,
      currentProgress: (json['currentProgress'] as num?)?.toDouble() ?? 0,
      privateNote: json['privateNote'] as String?,
      periodKey: json['periodKey'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}
