import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/models/activity_models.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/models/programme_models.dart';
import '../../../core/network/api_client.dart';

/// The published programme for the current (or selected) year.
final currentProgrammeProvider = FutureProvider.autoDispose<AnnualProgramme?>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final year = DateTime.now().year;
    final data = await client.get('/programmes', query: {'year': '$year'});
    final list = _asJsonList(data);
    if (list.isEmpty) {
      // Fall back to the most recent published programme.
      final any = await client.get('/programmes');
      final anyList = _asJsonList(any);
      if (anyList.isEmpty) return null;
      return AnnualProgramme.fromJson(anyList.first);
    }
    return AnnualProgramme.fromJson(list.first);
  },
);

/// All published programme years (for year switching).
final programmeYearsProvider = FutureProvider.autoDispose<List<AnnualProgramme>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/programmes');
    return _asJsonList(data).map(AnnualProgramme.fromJson).toList();
  },
);

/// Monthly plans for a programme year.
///
/// Falls back to the active programme's year when the requested calendar year
/// has no published programme (e.g. the clock reads 2026 while the published
/// programme is 2027). Without this, callers passing `DateTime.now().year`
/// would get a spurious 404.
final monthlyPlansProvider =
    FutureProvider.autoDispose.family<List<MonthlyPlan>, int>(
  (ref, year) async {
    final client = ref.watch(apiClientProvider);
    Future<List<MonthlyPlan>> fetch(int y) async {
      final data = await client.get('/programmes/$y/monthly-plans');
      return _asJsonList(data).map(MonthlyPlan.fromJson).toList();
    }

    try {
      return await fetch(year);
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
      final programme = await ref.watch(currentProgrammeProvider.future);
      if (programme == null || programme.year == year) rethrow;
      return fetch(programme.year);
    }
  },
);

/// The plan for a specific month (1-12) of a year.
final monthlyPlanProvider =
    FutureProvider.autoDispose.family<MonthlyPlan?, ({int year, int month})>(
  (ref, key) async {
    final plans = await ref.watch(monthlyPlansProvider(key.year).future);
    for (final plan in plans) {
      if (plan.month == key.month) return plan;
    }
    return null;
  },
);

/// Weekly plans for a month.
final weeklyPlansProvider = FutureProvider.autoDispose
    .family<List<WeeklyPlan>, ({int year, int month})>(
  (ref, key) async {
    final client = ref.watch(apiClientProvider);
    final data = await client
        .get('/programmes/weekly-plans', query: {
      'year': '${key.year}',
      'month': '${key.month}',
    });
    return _asJsonList(data).map(WeeklyPlan.fromJson).toList();
  },
);

/// The member's daily checklist for a given date (plan + own records).
final dailyChecklistProvider = FutureProvider.autoDispose
    .family<List<PlannedActivity>, DateTime>(
  (ref, date) async {
    final client = ref.watch(apiClientProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    final data = await client.get('/me/activities', query: {'date': key});
    return _asJsonList(data).map(PlannedActivity.fromJson).toList();
  },
);

/// Announcements visible to the current member.
final announcementsProvider = FutureProvider.autoDispose<List<Announcement>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/announcements');
    return _asJsonList(data).map(Announcement.fromJson).toList();
  },
);

/// Notification list for the current user.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/me/notifications');
    return _asJsonList(data).map(AppNotification.fromJson).toList();
  },
);

final unreadNotificationCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.read).length,
        orElse: () => 0,
      ),
);

List<Map<String, dynamic>> _asJsonList(dynamic data) {
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  if (data is Map<String, dynamic>) {
    final items = data['data'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

/// Exposed for features that need the same tolerant list parsing.
List<Map<String, dynamic>> asJsonList(dynamic data) => _asJsonList(data);
