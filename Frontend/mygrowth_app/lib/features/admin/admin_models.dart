import 'admin_shared.dart';

/// Activity definition managed under `/admin/activity-definitions`
/// (with an `/admin/activities` fallback endpoint).
class AdminActivityDefinition {
  const AdminActivityDefinition({
    required this.id,
    required this.title,
    this.description,
    this.categoryKey = 'custom',
    this.type,
    this.targetDuration,
    this.trackingEnabled = true,
    this.noteAllowed = true,
    this.sortOrder = 0,
    this.enabled = true,
    this.status,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String categoryKey;
  final String? type;
  final String? targetDuration;
  final bool trackingEnabled;
  final bool noteAllowed;
  final int sortOrder;
  final bool enabled;
  final String? status;
  final DateTime? createdAt;

  factory AdminActivityDefinition.fromJson(Map<String, dynamic> json) {
    return AdminActivityDefinition(
      id: strOf(json['id'] ?? json['activityId']),
      title: strOf(json['title'] ?? json['name']),
      description: strOf(json['description'], '').isEmpty
          ? null
          : strOf(json['description']),
      categoryKey: strOf(
        json['categoryKey'] ?? json['category'] ?? json['categoryName'],
        'custom',
      ),
      type: strOf(json['type'], '').isEmpty ? null : strOf(json['type']),
      targetDuration: strOf(
        json['targetDuration'] ?? json['defaultDuration'] ?? json['duration'],
        '',
      ).isEmpty
          ? null
          : strOf(json['targetDuration'] ??
              json['defaultDuration'] ??
              json['duration']),
      trackingEnabled: json['trackingEnabled'] is bool
          ? json['trackingEnabled'] as bool
          : true,
      noteAllowed: json['noteAllowed'] is bool
          ? json['noteAllowed'] as bool
          : true,
      sortOrder: (json['sortOrder'] ?? json['order'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : strOf(json['status'], 'ACTIVE') != 'DISABLED',
      status: strOf(json['status'], '').isEmpty ? null : strOf(json['status']),
      createdAt: dateOf(json['createdAt']),
    );
  }
}

/// A programme daily-activity definition (`/admin/daily-activities`).
class AdminDailyActivity {
  const AdminDailyActivity({
    required this.id,
    required this.title,
    this.description,
    this.categoryKey = 'custom',
    this.type,
    this.date,
    this.recurrence,
    this.startTime,
    this.targetDuration,
    this.trackingEnabled = true,
    this.sortOrder = 0,
    this.status,
  });

  final String id;
  final String title;
  final String? description;
  final String categoryKey;
  final String? type;
  final DateTime? date;
  final String? recurrence;
  final String? startTime;
  final String? targetDuration;
  final bool trackingEnabled;
  final int sortOrder;
  final String? status;

  String get scheduleLabel {
    if (date != null) return fmtDate(date);
    if (recurrence != null && recurrence!.isNotEmpty) {
      return humanizeKey(recurrence!);
    }
    return '—';
  }

  factory AdminDailyActivity.fromJson(Map<String, dynamic> json) {
    return AdminDailyActivity(
      id: strOf(json['id'] ?? json['activityId']),
      title: strOf(json['title'] ?? json['name']),
      description: strOf(json['description'], '').isEmpty
          ? null
          : strOf(json['description']),
      categoryKey: strOf(
        json['categoryKey'] ?? json['category'] ?? json['type'],
        'custom',
      ),
      type: strOf(json['type'], '').isEmpty ? null : strOf(json['type']),
      date: dateOf(json['date']),
      recurrence: strOf(json['recurrence'] ?? json['repeatRule'], '').isEmpty
          ? null
          : strOf(json['recurrence'] ?? json['repeatRule']),
      startTime:
          strOf(json['startTime'] ?? json['time'], '').isEmpty
              ? null
              : strOf(json['startTime'] ?? json['time']),
      targetDuration: strOf(
        json['targetDuration'] ?? json['duration'] ?? json['durationMinutes'],
        '',
      ).isEmpty
          ? null
          : strOf(json['targetDuration'] ??
              json['duration'] ??
              json['durationMinutes']),
      trackingEnabled: json['trackingEnabled'] is bool
          ? json['trackingEnabled'] as bool
          : true,
      sortOrder: (json['sortOrder'] ?? json['order'] as num?)?.toInt() ?? 0,
      status: strOf(json['status'], '').isEmpty ? null : strOf(json['status']),
    );
  }
}

/// A configurable activity category (`/admin/activity-categories`).
class AdminActivityCategory {
  const AdminActivityCategory({
    required this.key,
    required this.label,
    this.description,
    this.sortOrder = 0,
    this.enabled = true,
  });

  final String key;
  final String label;
  final String? description;
  final int sortOrder;
  final bool enabled;

  /// Human label, falling back to the built-in label for the standard keys.
  String get displayLabel => label.trim().isEmpty
      ? activityCategoryLabel(key)
      : label;

  factory AdminActivityCategory.fromJson(Map<String, dynamic> json) {
    return AdminActivityCategory(
      key: strOf(json['key'] ?? json['categoryKey'] ?? json['id']),
      label: strOf(json['label'] ?? json['name'], ''),
      description: strOf(json['description'], '').isEmpty
          ? null
          : strOf(json['description']),
      sortOrder: pickNum(json, const ['sortOrder', 'order'])?.toInt() ?? 0,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}

/// One row of the admin audit trail.
class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.action,
    this.actorName,
    this.targetDescription,
    this.outcome,
    this.createdAt,
    this.details = const {},
  });

  final String id;
  final String action;
  final String? actorName;
  final String? targetDescription;
  final String? outcome; // SUCCESS | FAILURE | DENIED …
  final DateTime? createdAt;
  final Map<String, dynamic> details;

  bool get isAdminAccessAction =>
      action.toUpperCase().startsWith('ADMIN');

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'] ?? json['metadata'] ?? json['context'];
    return AdminAuditEntry(
      id: strOf(json['id']),
      action: strOf(json['action'] ?? json['type'], 'UNKNOWN'),
      actorName: strOf(
        json['actorName'] ?? json['actor']?['name'] ?? json['performedBy'],
        '',
      ).isEmpty
          ? null
          : strOf(json['actorName'] ??
              json['actor']?['name'] ??
              json['performedBy']),
      targetDescription: strOf(
        json['targetDescription'] ??
            json['target'] ??
            json['description'] ??
            json['resource'],
        '',
      ).isEmpty
          ? null
          : strOf(json['targetDescription'] ??
              json['target'] ??
              json['description'] ??
              json['resource']),
      outcome: strOf(json['outcome'] ?? json['status'] ?? json['result'], '')
              .isEmpty
          ? null
          : strOf(json['outcome'] ?? json['status'] ?? json['result']),
      createdAt: dateOf(json['createdAt'] ?? json['timestamp'] ?? json['at']),
      details: rawDetails is Map<String, dynamic> ? rawDetails : const {},
    );
  }
}

/// Administrator account row (`GET /admin/admins`).
///
/// [status] is the *administrative-access* state (`PENDING_GRANT`, `ACTIVE`,
/// `SUSPENDED`, `REVOKED`) — not the account status — because that is what the
/// grant/suspend/reactivate/revoke actions act on.
class AdminAdministrator {
  const AdminAdministrator({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'ADMIN',
    this.status = 'PENDING_GRANT',
    this.createdAt,
    this.createdByName,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String status; // ACTIVE | SUSPENDED | PENDING_GRANT | REVOKED
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? lastActivityAt;

  bool get isProtectedMainAdmin => role == 'MAIN_ADMIN';
  bool get isPendingGrant => status == 'PENDING_GRANT';
  bool get isRevoked => status == 'REVOKED';
  bool get isAccessActive => status == 'ACTIVE';
  bool get isSuspended => status == 'SUSPENDED';

  bool get canGrant => isPendingGrant || isRevoked;
  bool get canSuspend => isAccessActive;
  bool get canReactivate => isSuspended;
  bool get canRevoke => isAccessActive || isSuspended;

  factory AdminAdministrator.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdByAdmin'];
    final first = strOf(json['firstName'], '');
    final last = strOf(json['lastName'], '');
    final combined = '$first $last'.trim();
    return AdminAdministrator(
      id: strOf(json['id'] ?? json['userId']),
      name: strOf(
        json['name'] ??
            json['fullName'] ??
            (combined.isEmpty ? null : combined),
      ),
      email: strOf(json['email']),
      phone: strOf(json['phone'], '').isEmpty ? null : strOf(json['phone']),
      role: strOf(json['role'] ?? 'ADMIN', 'ADMIN'),
      status: _accessStatusOf(json),
      createdAt: dateOf(json['createdAt']),
      createdByName: _personNameOf(
        json['createdByName'] ?? createdBy,
      ),
      lastActivityAt: dateOf(
        json['lastActivityAt'] ?? json['lastActiveAt'] ?? json['lastLoginAt'],
      ),
    );
  }
}

/// Normalises the administrative-access state into the values the UI reasons
/// about (`PENDING_GRANT` | `ACTIVE` | `SUSPENDED` | `REVOKED`).
String _accessStatusOf(Map<String, dynamic> json) {
  final raw = strOf(json['adminAccess'] ?? json['accessStatus'] ?? json['status']);
  return switch (raw) {
    'PENDING' => 'PENDING_GRANT',
    'NONE' => 'REVOKED',
    '' => 'PENDING_GRANT',
    _ => raw,
  };
}

/// Builds a display name from either a plain string or a `{firstName,lastName}`
/// object.
String? _personNameOf(dynamic value) {
  if (value is Map<String, dynamic>) {
    final first = strOf(value['firstName'] ?? value['name'], '');
    final last = strOf(value['lastName'], '');
    final combined = '$first $last'.trim();
    return combined.isEmpty ? null : combined;
  }
  final text = strOf(value, '');
  return text.isEmpty ? null : text;
}

/// Admin view of a prayer partnership (two members, safety controls only).
class AdminPartnership {
  const AdminPartnership({
    required this.id,
    required this.memberAName,
    required this.memberBName,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String memberAName;
  final String memberBName;
  final String status; // ACTIVE | PAUSED | ENDED
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory AdminPartnership.fromJson(Map<String, dynamic> json) {
    final members = json['members'];
    final names = <String>[
      if (members is List)
        ...members
            .whereType<Map<String, dynamic>>()
            .map((m) => strOf(m['name'] ?? m['fullName']))
            .where((n) => n.isNotEmpty),
    ];
    return AdminPartnership(
      id: strOf(json['id'] ?? json['partnershipId']),
      memberAName: strOf(
        json['memberAName'] ??
            json['userA']?['name'] ??
            json['partnerA']?['name'] ??
            (names.isNotEmpty ? names.first : null),
        'Member',
      ),
      memberBName: strOf(
        json['memberBName'] ??
            json['userB']?['name'] ??
            json['partnerB']?['name'] ??
            (names.length > 1 ? names[1] : null),
        'Member',
      ),
      status: strOf(json['status'] ?? 'ACTIVE', 'ACTIVE'),
      startedAt: dateOf(json['startedAt'] ?? json['createdAt']),
      endedAt: dateOf(json['endedAt']),
    );
  }
}

/// Admin view of a prayer-partner request.
class AdminPartnerRequest {
  const AdminPartnerRequest({
    required this.id,
    required this.senderName,
    required this.recipientName,
    required this.status,
    this.message,
    this.createdAt,
  });

  final String id;
  final String senderName;
  final String recipientName;
  final String status; // PENDING | ACCEPTED | DECLINED | CANCELLED
  final String? message;
  final DateTime? createdAt;

  factory AdminPartnerRequest.fromJson(Map<String, dynamic> json) {
    return AdminPartnerRequest(
      id: strOf(json['id']),
      senderName: strOf(
        json['senderName'] ?? json['sender']?['name'] ?? json['fromName'],
        'Member',
      ),
      recipientName: strOf(
        json['recipientName'] ?? json['recipient']?['name'] ?? json['toName'],
        'Member',
      ),
      status: strOf(json['status'] ?? 'PENDING', 'PENDING'),
      message: strOf(json['message'], '').isEmpty
          ? null
          : strOf(json['message']),
      createdAt: dateOf(json['createdAt'] ?? json['sentAt']),
    );
  }
}

/// Admin view of a prayer-partner safety report.
///
/// The reporter is shown anonymised (first name only) in the UI.
class AdminPartnerReport {
  const AdminPartnerReport({
    required this.id,
    required this.reporterName,
    required this.reason,
    required this.status,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String reporterName;
  final String reason;
  final String status; // OPEN | ACKNOWLEDGED | RESOLVED | DISMISSED
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// First name only — this view is for safety, not identity.
  String get anonymisedReporter {
    final first = reporterName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'A member' : first;
  }

  factory AdminPartnerReport.fromJson(Map<String, dynamic> json) {
    return AdminPartnerReport(
      id: strOf(json['id'] ?? json['reportId']),
      reporterName: _personNameOf(
            json['reporterName'] ??
                json['reportedBy'] ??
                json['reporter'],
          ) ??
          'Member',
      reason: strOf(
        json['reason'] ?? json['message'] ?? json['description'],
        'No reason provided.',
      ),
      status: strOf(json['status'] ?? 'OPEN', 'OPEN'),
      createdAt: dateOf(json['createdAt'] ?? json['reportedAt']),
      resolvedAt: dateOf(json['resolvedAt']),
    );
  }
}
