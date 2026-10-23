import 'admin_shared.dart';

/// Lightweight member shape returned by `GET /admin/users`.
///
/// Parsed inline (tolerantly) because the admin list projection differs from
/// the full [AppUser] profile.
class AdminMember {
  const AdminMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.createdAt,
    this.lastActiveAt,
    this.adminAccessActive = false,
  });

  final String id;
  final String name;
  final String email;
  final String role; // MEMBER | ADMIN | MAIN_ADMIN
  final String status; // PENDING | ACTIVE | SUSPENDED | DEACTIVATED
  final String? phone;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final bool adminAccessActive;

  bool get isAdminAccount => role == 'ADMIN' || role == 'MAIN_ADMIN';
  bool get isMainAdmin => role == 'MAIN_ADMIN';
  bool get isMember => role == 'MEMBER';
  bool get isPending => status == 'PENDING';
  bool get isActive => status == 'ACTIVE';
  bool get isSuspended => status == 'SUSPENDED';

  String get initials => initialsFor(name);

  String get roleLabel => switch (role) {
        'MAIN_ADMIN' => 'Main Admin',
        'ADMIN' => 'Admin',
        _ => 'Member',
      };

  factory AdminMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    final first = strOf(json['firstName'], '');
    final last = strOf(json['lastName'], '');
    final combined = '$first $last'.trim();
    final access = strOf(json['adminAccess'] ?? json['accessStatus']);
    return AdminMember(
      id: strOf(json['id'] ?? json['userId']),
      name: strOf(
        json['name'] ??
            json['fullName'] ??
            profile?['fullName'] ??
            (combined.isEmpty ? null : combined),
      ),
      email: strOf(json['email']),
      role: strOf(json['role'] ?? 'MEMBER', 'MEMBER'),
      status: strOf(json['status'] ?? 'ACTIVE', 'ACTIVE'),
      phone: strOf(json['phone'] ?? profile?['phone'], '').isEmpty
          ? null
          : strOf(json['phone'] ?? profile?['phone']),
      createdAt:
          dateOf(json['createdAt'] ?? json['joinedAt'] ?? json['registeredAt']),
      lastActiveAt: dateOf(
        json['lastActiveAt'] ?? json['lastLoginAt'] ?? json['updatedAt'],
      ),
      adminAccessActive:
          json['adminAccessActive'] == true || access.toUpperCase() == 'ACTIVE',
    );
  }
}
