import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/core/models/app_user.dart';
import 'package:mygrowth_app/core/models/goal_models.dart';
import 'package:mygrowth_app/core/widgets/app_badge.dart';
import 'package:mygrowth_app/core/widgets/pagination.dart';

void main() {
  group('AppUser', () {
    test('parses a member payload', () {
      final user = AppUser.fromJson({
        'id': 'u1',
        'name': 'Ada Obi',
        'email': 'ada@example.com',
        'role': 'MEMBER',
        'status': 'ACTIVE',
      });
      expect(user.isMember, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.canUseAdminArea, isFalse);
      expect(user.initials, 'AO');
      expect(user.timeZone, 'Africa/Lagos');
    });

    test('admin access requires grant for ADMIN role', () {
      final pending = AppUser.fromJson({
        'id': 'u2',
        'name': 'Sam Eze',
        'email': 'sam@example.com',
        'role': 'ADMIN',
        'status': 'ACTIVE',
        'adminAccessActive': false,
      });
      expect(pending.isAdmin, isTrue);
      expect(pending.canUseAdminArea, isFalse);

      final granted = AppUser.fromJson({
        'id': 'u2',
        'name': 'Sam Eze',
        'email': 'sam@example.com',
        'role': 'ADMIN',
        'status': 'ACTIVE',
        'adminAccessActive': true,
      });
      expect(granted.canUseAdminArea, isTrue);
    });

    test('main admin always has admin area access', () {
      final main = AppUser.fromJson({
        'id': 'u3',
        'name': 'Pastor Azuike',
        'email': 'pastor@example.com',
        'role': 'MAIN_ADMIN',
        'status': 'ACTIVE',
      });
      expect(main.isMainAdmin, isTrue);
      expect(main.canUseAdminArea, isTrue);
    });
  });

  group('Goal', () {
    test('progress fraction is clamped and handles missing targets', () {
      final withTarget = Goal.fromJson({
        'id': 'g1',
        'title': 'Read Proverbs',
        'periodType': 'MONTHLY',
        'status': 'ACTIVE',
        'targetQuantity': 30,
        'currentProgress': 45,
      });
      expect(withTarget.progressFraction, 1.0);

      final noTarget = Goal.fromJson({
        'id': 'g2',
        'title': 'Pray daily',
        'periodType': 'WEEKLY',
        'status': 'COMPLETED',
      });
      expect(noTarget.progressFraction, 1.0);

      final activeNoTarget = Goal.fromJson({
        'id': 'g3',
        'title': 'Pray daily',
        'periodType': 'WEEKLY',
        'status': 'ACTIVE',
      });
      expect(activeNoTarget.progressFraction, 0.0);
    });
  });

  group('PagedResult', () {
    test('parses the standard envelope', () {
      final result = PagedResult<Map<String, dynamic>>.fromJson(
        {
          'data': [
            {'id': '1', 'title': 'A'},
            {'id': '2', 'title': 'B'},
          ],
          'meta': {'page': 2, 'pageSize': 2, 'total': 5, 'totalPages': 3},
        },
        (json) => json,
      );
      expect(result.items.length, 2);
      expect(result.page, 2);
      expect(result.total, 5);
      expect(result.totalPages, 3);
    });
  });

  group('status helpers', () {
    test('badgeToneFor maps lifecycle statuses', () {
      expect(badgeToneFor('COMPLETED'), AppBadgeTone.success);
      expect(badgeToneFor('REVIEWED'), AppBadgeTone.success);
      expect(badgeToneFor('SUBMITTED'), AppBadgeTone.warning);
      expect(badgeToneFor('SUSPENDED'), AppBadgeTone.danger);
      expect(badgeToneFor('DRAFT'), AppBadgeTone.neutral);
    });

    test('humanizeStatus produces readable labels', () {
      expect(humanizeStatus('REQUIRES_FOLLOW_UP'), 'Requires Follow Up');
      expect(humanizeStatus('active'), 'Active');
    });
  });

  group('NotificationPrefs', () {
    test('round-trips through json', () {
      const prefs = NotificationPrefs(
        emailEnabled: false,
        dailyReminderTime: '05:30',
        sessionReminderMinutes: 45,
      );
      final restored = NotificationPrefs.fromJson(prefs.toJson());
      expect(restored.emailEnabled, isFalse);
      expect(restored.dailyReminderTime, '05:30');
      expect(restored.sessionReminderMinutes, 45);
    });
  });
}
