import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/material_models.dart';
import '../../core/models/notification_models.dart';
import '../../core/models/programme_models.dart';
import '../../core/models/report_models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/pagination.dart';
import 'admin_member_model.dart';
import 'admin_models.dart';
import 'admin_shared.dart';

// ---------------------------------------------------------------- summary

/// Admin dashboard metrics, derived from `GET /admin/analytics/overview`.
///
/// [period] scopes the "active during period" count (`week` | `month` |
/// `year`). The overview response is flattened into the flat keys the
/// dashboard tiles expect — and it stays aggregate-only: no private
/// reflections or journal text ever appear here.
final adminSummaryProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, period) async {
    final client = ref.watch(apiClientProvider);
    final now = DateTime.now();
    final query = <String, String>{
      if (period == 'year') 'year': '${now.year}',
      if (period == 'month') 'year': '${now.year}',
      if (period == 'month') 'month': '${now.month}',
    };
    try {
      final data = await client.get(
        '/admin/analytics/overview',
        query: query,
      );
      return _flattenOverview(asJsonMap(data));
    } on ApiException catch (e) {
      if (e.isNotFound) return const {};
      rethrow;
    }
  },
);

/// Turns the nested overview payload into the flat metric keys used by the
/// dashboard tiles.
Map<String, dynamic> _flattenOverview(Map<String, dynamic> o) {
  if (o.isEmpty) return const {};
  final members = asJsonMap(o['members']);
  final reports = asJsonMap(o['reports']);
  final completion = asJsonMap(o['activityCompletion']);
  final prayer = asJsonMap(o['prayerSessions']);
  final byStatus = asJsonMap(completion['byStatus']);
  final totalRecords = pickNum(completion, const ['totalRecords']) ?? 0;
  final completed = pickNum(byStatus, const ['COMPLETED']) ?? 0;
  final rate = totalRecords == 0 ? null : completed / totalRecords;

  return {
    'totalMembers': members['total'],
    'activeMembers': members['activeDuringPeriod'] ?? members['active'],
    'pendingMemberApprovals': members['pending'],
    'reportsSubmitted': reports['totalNonDraft'],
    'reportsAwaitingReview': reports['awaitingReview'],
    'activityCompletionRate': rate,
    'prayerSessionsScheduled':
        (pickNum(prayer, const ['PROPOSED']) ?? 0) +
            (pickNum(prayer, const ['ACCEPTED']) ?? 0),
    'prayerSessionsCompleted': prayer['COMPLETED'],
    'unresolvedSafetyReports': o['openSafetyReports'],
    'recentSignUps': o['recentSignups'] ?? o['recentSignUps'] ?? const [],
  };
}

// ---------------------------------------------------------------- members

typedef AdminMembersQuery = ({
  int page,
  String search,
  String status,
  String role,
});

final adminMembersProvider = FutureProvider.autoDispose
    .family<PagedResult<AdminMember>, AdminMembersQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/users', query: {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.search.isNotEmpty) 'search': q.search,
      if (q.status.isNotEmpty) 'status': q.status,
      if (q.role.isNotEmpty) 'role': q.role,
    });
    return pagedFrom(data, AdminMember.fromJson);
  },
);

/// Single member profile; null when the server no longer knows the id.
///
/// The endpoint wraps the payload as `{ user: {...}, stats: {...} }`.
final adminMemberProvider =
    FutureProvider.autoDispose.family<AdminMember?, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/admin/users/$id');
      final map = asJsonMap(data);
      return AdminMember.fromJson(asJsonMap(map['user'] ?? map));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  },
);

/// Activity/report completion summary derived from `GET /admin/users/:id`.
///
/// The detail endpoint embeds `stats`; this flattens the report status counts
/// into the keys the member detail screen expects. Degrades to `{}` when the
/// server has nothing to report.
final adminMemberSummaryProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/admin/users/$id');
      final stats = asJsonMap(asJsonMap(data)['stats']);
      if (stats.isEmpty) return const {};
      final reports = asJsonMap(stats['reports']);
      final submitted = reports.values
          .whereType<num>()
          .fold<num>(0, (sum, value) => sum + value);
      return {
        ...stats,
        'reportsSubmitted': submitted,
        'reportsAwaitingReview': reports['SUBMITTED'],
      };
    } on ApiException catch (e) {
      if (e.isNotFound || e.isForbidden) return const {};
      rethrow;
    }
  },
);

/// Reports submitted by one member.
final adminMemberReportsProvider =
    FutureProvider.autoDispose.family<PagedResult<Report>, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/reports', query: {
      'userId': id,
      'pageSize': '$adminPageSize',
    });
    return pagedFrom(data, Report.fromJson);
  },
);

// ---------------------------------------------------------------- reports

typedef AdminReportsQuery = ({
  int page,
  String type,
  String status,
  String search,
  String year,
});

final adminReportsProvider =
    FutureProvider.autoDispose.family<PagedResult<Report>, AdminReportsQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/reports', query: {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.type.isNotEmpty) 'type': q.type,
      if (q.status.isNotEmpty) 'status': q.status,
      if (q.search.isNotEmpty) 'search': q.search,
      if (q.year.isNotEmpty) 'programmeYear': q.year,
    });
    return pagedFrom(data, Report.fromJson);
  },
);

final adminReportDetailProvider =
    FutureProvider.autoDispose.family<Report, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/reports/$id');
    // The endpoint wraps the payload as `{ report: {...} }`.
    final map = asJsonMap(data);
    return Report.fromJson(asJsonMap(map['report'] ?? map));
  },
);

// ------------------------------------------------------------- programmes

/// All programme years, including archived ones.
final adminProgrammesProvider =
    FutureProvider.autoDispose<List<AnnualProgramme>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data =
        await client.get('/programmes', query: {'includeArchived': 'true'});
    return safeMapList(data, AnnualProgramme.fromJson);
  },
);

/// One programme for the edit form; null when not found.
final adminProgrammeProvider =
    FutureProvider.autoDispose.family<AnnualProgramme?, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/programmes/$id');
      return AnnualProgramme.fromJson(asJsonMap(data));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  },
);

/// Monthly plans for a year (admin endpoint first, member endpoint fallback).
final adminMonthlyPlansProvider =
    FutureProvider.autoDispose.family<List<MonthlyPlan>, int>(
  (ref, year) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data =
          await client.get('/admin/monthly-plans', query: {'year': '$year'});
      return safeMapList(data, MonthlyPlan.fromJson);
    } on ApiException catch (e) {
      if (e.isNotFound || e.isForbidden) {
        final data = await client.get('/programmes/$year/monthly-plans');
        return safeMapList(data, MonthlyPlan.fromJson);
      }
      rethrow;
    }
  },
);

typedef AdminYearMonth = ({int year, int month});

final adminWeeklyPlansProvider =
    FutureProvider.autoDispose.family<List<WeeklyPlan>, AdminYearMonth>(
  (ref, key) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/weekly-plans', query: {
      'year': '${key.year}',
      'month': '${key.month}',
    });
    return safeMapList(data, WeeklyPlan.fromJson);
  },
);

final adminDailyActivitiesProvider =
    FutureProvider.autoDispose.family<List<AdminDailyActivity>, AdminYearMonth>(
  (ref, key) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/daily-activities', query: {
      'year': '${key.year}',
      'month': '${key.month}',
    });
    return safeMapList(data, AdminDailyActivity.fromJson);
  },
);

// -------------------------------------------------------------- materials

typedef AdminMaterialsQuery = ({
  int page,
  String search,
  String status,
  String category,
});

final adminMaterialsProvider = FutureProvider.autoDispose
    .family<PagedResult<MaterialItem>, AdminMaterialsQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/materials', query: {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.search.isNotEmpty) 'search': q.search,
      if (q.status.isNotEmpty) 'status': q.status,
      if (q.category.isNotEmpty) 'category': q.category,
    });
    return pagedFrom(data, MaterialItem.fromJson);
  },
);

// ------------------------------------------------------------- activities

typedef AdminActivityDefsQuery = ({int page, String search, String status});

/// Activity definitions; falls back to `/admin/activities` when the
/// primary endpoint isn't available.
final adminActivityDefinitionsProvider = FutureProvider.autoDispose
    .family<PagedResult<AdminActivityDefinition>, AdminActivityDefsQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final query = {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.search.isNotEmpty) 'search': q.search,
      if (q.status.isNotEmpty) 'status': q.status,
    };
    dynamic data;
    try {
      data = await client.get('/admin/activity-definitions', query: query);
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
      data = await client.get('/admin/activities', query: query);
    }
    return pagedFrom(data, AdminActivityDefinition.fromJson);
  },
);

// --------------------------------------------------------- prayer partners

typedef AdminPartnershipsQuery = ({int page, String status});

final adminPrayerPartnershipsProvider =
    FutureProvider.autoDispose.family<PagedResult<AdminPartnership>, AdminPartnershipsQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/prayer-partnerships', query: {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.status.isNotEmpty) 'status': q.status,
    });
    return pagedFrom(data, AdminPartnership.fromJson);
  },
);

final adminPrayerRequestsProvider =
    FutureProvider.autoDispose<List<AdminPartnerRequest>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/prayer-partner-requests');
    return safeMapList(data, AdminPartnerRequest.fromJson);
  },
);

final adminPrayerReportsProvider =
    FutureProvider.autoDispose<List<AdminPartnerReport>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/admin/safety-reports',
      query: {'pageSize': '50'},
    );
    return safeMapList(data, AdminPartnerReport.fromJson);
  },
);

// ------------------------------------------------- activity categories

/// The 12 configurable activity categories (`GET /admin/activity-categories`).
final adminActivityCategoriesProvider =
    FutureProvider.autoDispose<List<AdminActivityCategory>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/activity-categories');
    return safeMapList(data, AdminActivityCategory.fromJson);
  },
);

// ----------------------------------------------------------- announcements

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/announcements');
    return safeMapList(data, Announcement.fromJson);
  },
);

// -------------------------------------------------------------- analytics

typedef AdminAnalyticsQuery = ({int year, int month, String period});

/// Aggregated analytics overview; degrades to `{}` when unavailable so
/// each section can show its own empty state.
final adminAnalyticsOverviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, AdminAnalyticsQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/admin/analytics/overview', query: {
        if (q.year > 0) 'year': '${q.year}',
        if (q.month > 0) 'month': '${q.month}',
        'period': q.period,
      });
      return asJsonMap(data);
    } on ApiException catch (e) {
      if (e.isNotFound) return const {};
      rethrow;
    }
  },
);

// ------------------------------------------------------------ audit logs

typedef AdminAuditQuery = ({
  int page,
  String action,
  String search,
  String from,
  String to,
});

final adminAuditLogsProvider =
    FutureProvider.autoDispose.family<PagedResult<AdminAuditEntry>, AdminAuditQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/audit-logs', query: {
      'page': '${q.page}',
      'pageSize': '$adminPageSize',
      if (q.action.isNotEmpty || q.search.isNotEmpty)
        'action': q.action.isNotEmpty ? q.action : q.search,
      if (q.from.isNotEmpty) 'from': q.from,
      if (q.to.isNotEmpty) 'to': q.to,
    });
    return pagedFrom(data, AdminAuditEntry.fromJson);
  },
);

/// Recent administrator-access events for the Admin Access screen.
///
/// Tries a server-side action filter first, then falls back to filtering
/// recent entries client-side so the feed still works with stricter APIs.
final adminAccessEventsProvider =
    FutureProvider.autoDispose<List<AdminAuditEntry>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/admin/audit-logs', query: {
        'action': 'ADMIN',
        'pageSize': '50',
      });
      final filtered =
          pagedFrom(data, AdminAuditEntry.fromJson).items.where(
                (e) => e.isAdminAccessAction,
              );
      if (filtered.isNotEmpty) return filtered.toList();
    } on ApiException catch (e) {
      if (!e.isNotFound && !e.isForbidden) rethrow;
    }
    final data = await client.get('/admin/audit-logs', query: {
      'pageSize': '100',
    });
    return pagedFrom(data, AdminAuditEntry.fromJson)
        .items
        .where((e) => e.isAdminAccessAction)
        .toList();
  },
);

// --------------------------------------------------------------- settings

final adminSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/admin/settings');
      return asJsonMap(data);
    } on ApiException catch (e) {
      if (e.isNotFound) return const {};
      rethrow;
    }
  },
);

// ----------------------------------------------------------------- access

final adminAdministratorsProvider =
    FutureProvider.autoDispose<PagedResult<AdminAdministrator>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/admin/admins',
      query: {'pageSize': '50'},
    );
    return pagedFrom(data, AdminAdministrator.fromJson);
  },
);
