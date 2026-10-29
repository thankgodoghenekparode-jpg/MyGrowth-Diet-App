/// Core user identity + role model shared by auth, routing and RBAC UI rules.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.timeZone = 'Africa/Lagos',
    this.emailVerified = false,
    this.adminAccessActive = false,
    this.bio,
    this.avatarUrl,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String email;
  final String role; // MAIN_ADMIN | ADMIN | MEMBER
  final String status; // PENDING | ACTIVE | SUSPENDED | DEACTIVATED
  final String? phone;
  final String timeZone;
  final bool emailVerified;

  /// For ADMIN accounts: whether the Main Admin has granted active access.
  final bool adminAccessActive;
  final String? bio;
  final String? avatarUrl;
  final DateTime? joinedAt;

  bool get isMainAdmin => role == 'MAIN_ADMIN';
  bool get isAdmin => role == 'ADMIN' || role == 'MAIN_ADMIN';
  bool get isMember => role == 'MEMBER';
  bool get isPendingApproval => status == 'PENDING';
  bool get isActive => status == 'ACTIVE';

  /// Whether administrative UI should be reachable for this account.
  /// Backend enforcement is the real security boundary; this only shapes UI.
  bool get canUseAdminArea => isAdmin && (isMainAdmin || adminAccessActive);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'status': status,
        'phone': phone,
        'timeZone': timeZone,
        'emailVerified': emailVerified,
        'adminAccessActive': adminAccessActive,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'createdAt': joinedAt?.toIso8601String(),
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return AppUser(
      id: json['id'] as String,
      name: (json['name'] ?? profile?['fullName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? 'MEMBER') as String,
      status: (json['status'] ?? 'ACTIVE') as String,
      phone: (json['phone'] ?? profile?['phone']) as String?,
      timeZone:
          (json['timeZone'] ?? profile?['timeZone'] ?? 'Africa/Lagos') as String,
      emailVerified: (json['emailVerified'] ?? false) as bool,
      adminAccessActive: (json['adminAccessActive'] ?? false) as bool,
      bio: (json['bio'] ?? profile?['bio']) as String?,
      avatarUrl: (json['avatarUrl'] ?? profile?['avatarUrl']) as String?,
      joinedAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

/// Notification preferences for the current user.
class NotificationPrefs {
  const NotificationPrefs({
    this.emailEnabled = true,
    this.dailyReminderEnabled = true,
    this.dailyReminderTime = '06:00',
    this.weeklyReportReminder = true,
    this.monthlyReportReminder = true,
    this.sessionReminders = true,
    this.sessionReminderMinutes = 30,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.timeZone = 'Africa/Lagos',
    this.summaryFrequency = 'DAILY',
  });

  final bool emailEnabled;
  final bool dailyReminderEnabled;
  final String dailyReminderTime;
  final bool weeklyReportReminder;
  final bool monthlyReportReminder;
  final bool sessionReminders;
  final int sessionReminderMinutes;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final String timeZone;
  final String summaryFrequency; // DAILY | WEEKLY | OFF

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      emailEnabled: (json['emailEnabled'] ?? true) as bool,
      dailyReminderEnabled: (json['dailyReminderEnabled'] ?? true) as bool,
      dailyReminderTime: (json['dailyReminderTime'] ?? '06:00') as String,
      weeklyReportReminder: (json['weeklyReportReminder'] ?? true) as bool,
      monthlyReportReminder: (json['monthlyReportReminder'] ?? true) as bool,
      sessionReminders: (json['sessionReminders'] ?? true) as bool,
      sessionReminderMinutes: (json['sessionReminderMinutes'] ?? 30) as int,
      quietHoursStart: json['quietHoursStart'] as String?,
      quietHoursEnd: json['quietHoursEnd'] as String?,
      timeZone: (json['timeZone'] ?? 'Africa/Lagos') as String,
      summaryFrequency: (json['summaryFrequency'] ?? 'DAILY') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'emailEnabled': emailEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
        'dailyReminderTime': dailyReminderTime,
        'weeklyReportReminder': weeklyReportReminder,
        'monthlyReportReminder': monthlyReportReminder,
        'sessionReminders': sessionReminders,
        'sessionReminderMinutes': sessionReminderMinutes,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'timeZone': timeZone,
        'summaryFrequency': summaryFrequency,
      };
}
