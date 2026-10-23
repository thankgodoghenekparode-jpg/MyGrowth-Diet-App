/// Prayer partner availability, requests, partnerships and sessions.
class PrayerAvailability {
  const PrayerAvailability({
    this.status = 'UNAVAILABLE',
    this.availableDays = const [],
    this.timeStart,
    this.timeEnd,
    this.timeZone = 'Africa/Lagos',
    this.preferredDurationMinutes = 30,
    this.language,
    this.acceptingRequests = false,
    this.updatedAt,
  });

  final String status; // AVAILABLE | UNAVAILABLE | TEMPORARILY_UNAVAILABLE
  final List<int> availableDays; // 1=Monday … 7=Sunday
  final String? timeStart; // "18:00"
  final String? timeEnd; // "19:00"
  final String timeZone;
  final int preferredDurationMinutes;
  final String? language;
  final bool acceptingRequests;
  final DateTime? updatedAt;

  factory PrayerAvailability.fromJson(Map<String, dynamic> json) {
    return PrayerAvailability(
      status: (json['status'] ?? 'UNAVAILABLE') as String,
      availableDays: (json['availableDays'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      timeStart: json['timeStart'] as String?,
      timeEnd: json['timeEnd'] as String?,
      timeZone: (json['timeZone'] ?? 'Africa/Lagos') as String,
      preferredDurationMinutes:
          (json['preferredDurationMinutes'] as num?)?.toInt() ?? 30,
      language: json['language'] as String?,
      acceptingRequests: (json['acceptingRequests'] ?? false) as bool,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'availableDays': availableDays,
        'timeStart': timeStart,
        'timeEnd': timeEnd,
        'timeZone': timeZone,
        'preferredDurationMinutes': preferredDurationMinutes,
        'language': language,
        'acceptingRequests': acceptingRequests,
      };
}

/// A privacy-safe suggestion from the "find a partner" directory.
class PartnerSuggestion {
  const PartnerSuggestion({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.timeZone = 'Africa/Lagos',
    this.availableDays = const [],
    this.timeStart,
    this.timeEnd,
    this.preferredDurationMinutes = 30,
    this.language,
    this.hasPendingRequest = false,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String timeZone;
  final List<int> availableDays;
  final String? timeStart;
  final String? timeEnd;
  final int preferredDurationMinutes;
  final String? language;
  final bool hasPendingRequest;

  factory PartnerSuggestion.fromJson(Map<String, dynamic> json) {
    return PartnerSuggestion(
      userId: (json['userId'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      avatarUrl: json['avatarUrl'] as String?,
      timeZone: (json['timeZone'] ?? 'Africa/Lagos') as String,
      availableDays: (json['availableDays'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      timeStart: json['timeStart'] as String?,
      timeEnd: json['timeEnd'] as String?,
      preferredDurationMinutes:
          (json['preferredDurationMinutes'] as num?)?.toInt() ?? 30,
      language: json['language'] as String?,
      hasPendingRequest: (json['hasPendingRequest'] ?? false) as bool,
    );
  }
}

class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.recipientId,
    required this.status,
    this.message,
    this.recipientName,
    this.senderName,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String status; // PENDING | ACCEPTED | DECLINED | BLOCKED | CANCELLED
  final String? message;
  final String? recipientName;
  final String? senderName;
  final DateTime? createdAt;

  bool get isPending => status == 'PENDING';

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      id: (json['id'] ?? '') as String,
      recipientId: (json['recipientId'] ?? '') as String,
      status: (json['status'] ?? 'PENDING') as String,
      message: json['message'] as String?,
      recipientName: json['recipientName'] as String?,
      senderName: json['senderName'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

class Partnership {
  const Partnership({
    required this.id,
    required this.status,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String status; // ACTIVE | PAUSED | ENDED
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isActive => status == 'ACTIVE';

  factory Partnership.fromJson(Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>?;
    final partnerA = json['partnerA'] as Map<String, dynamic>?;
    final partnerB = json['partnerB'] as Map<String, dynamic>?;
    return Partnership(
      id: (json['id'] ?? '') as String,
      status: (json['status'] ?? 'ACTIVE') as String,
      partnerId: (json['partnerId'] ??
              partner?['id'] ??
              partnerA?['id'] ??
              partnerB?['id'] ??
              '') as String,
      partnerName: (json['partnerName'] ??
              partner?['name'] ??
              partnerA?['name'] ??
              partnerB?['name'] ??
              'Prayer partner') as String,
      partnerAvatarUrl:
          (json['partnerAvatarUrl'] ?? partner?['avatarUrl']) as String?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.tryParse(json['endedAt'] as String),
    );
  }
}

class PrayerSession {
  const PrayerSession({
    required this.id,
    required this.partnershipId,
    required this.status,
    this.proposedById,
    this.startsAt,
    this.durationMinutes = 30,
    this.timeZone = 'Africa/Lagos',
    this.prayerFocus,
    this.meetingLink,
    this.partnerName,
    this.partnerId,
    this.myAttendanceRecorded = false,
    this.partnerAttendanceRecorded = false,
  });

  final String id;
  final String partnershipId;
  final String status; // PROPOSED | ACCEPTED | COMPLETED | RESCHEDULED | CANCELLED | MISSED
  final String? proposedById;
  final DateTime? startsAt;
  final int durationMinutes;
  final String timeZone;
  final String? prayerFocus;
  final String? meetingLink;
  final String? partnerName;
  final String? partnerId;
  final bool myAttendanceRecorded;
  final bool partnerAttendanceRecorded;

  bool get isUpcoming =>
      startsAt != null &&
      startsAt!.isAfter(DateTime.now()) &&
      (status == 'PROPOSED' || status == 'ACCEPTED');

  factory PrayerSession.fromJson(Map<String, dynamic> json) {
    final partnership = json['partnership'] as Map<String, dynamic>?;
    return PrayerSession(
      id: (json['id'] ?? '') as String,
      partnershipId: (json['partnershipId'] ?? partnership?['id'] ?? '') as String,
      status: (json['status'] ?? 'PROPOSED') as String,
      proposedById: json['proposedById'] as String?,
      startsAt: json['startsAt'] == null
          ? null
          : DateTime.tryParse(json['startsAt'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      timeZone: (json['timeZone'] ?? 'Africa/Lagos') as String,
      prayerFocus: json['prayerFocus'] as String?,
      meetingLink: json['meetingLink'] as String?,
      partnerName: (json['partnerName'] ??
              partnership?['partner']?['name'] ??
              partnership?['partnerName']) as String?,
      partnerId: (json['partnerId'] ??
              partnership?['partnerId'] ??
              partnership?['partner']?['id']) as String?,
      myAttendanceRecorded: (json['myAttendanceRecorded'] ?? false) as bool,
      partnerAttendanceRecorded:
          (json['partnerAttendanceRecorded'] ?? false) as bool,
    );
  }
}
