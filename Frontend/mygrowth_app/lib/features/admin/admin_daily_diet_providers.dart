import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/daily_diet_models.dart';
import '../../core/network/api_client.dart';
import 'admin_shared.dart';

/// The Daily Diet structure for a programme year.
///
/// This is the list of sections members follow: their labels, order and
/// behaviour.
final adminDailyDietSectionsProvider = FutureProvider.autoDispose
    .family<List<AdminDailyDietSection>, int>((ref, year) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get(
    '/admin/daily-diet/sections',
    query: {'year': '$year'},
  );
  return safeMapList(data, AdminDailyDietSection.fromJson);
});

/// The Daily Diet content rows for a year, a month or a single day.
typedef AdminDailyDietContentQuery = ({int year, int? month, String? date});

final adminDailyDietContentProvider = FutureProvider.autoDispose
    .family<List<AdminDailyDietContent>, AdminDailyDietContentQuery>(
  (ref, q) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/admin/daily-diet/content', query: {
      'year': '${q.year}',
      if (q.month != null) 'month': '${q.month}',
      if (q.date != null) 'date': q.date!,
    });
    return safeMapList(data, AdminDailyDietContent.fromJson);
  },
);

/// Writes to the Daily Diet structure and content.
final adminDailyDietControllerProvider =
    Provider<AdminDailyDietController>((ref) {
  return AdminDailyDietController(ref);
});

/// Every admin write for the Daily Diet.
class AdminDailyDietController {
  AdminDailyDietController(this._ref);

  final Ref _ref;

  ApiClient get _client => _ref.read(apiClientProvider);

  void _refresh(int year) {
    _ref.invalidate(adminDailyDietSectionsProvider(year));
    _ref.invalidate(adminDailyDietContentProvider);
  }

  /// Creates or updates a section.
  Future<void> saveSection({
    required int year,
    String? id,
    required String key,
    required String label,
    String? description,
    required DailyDietBehaviour behaviour,
    int? sortOrder,
    bool? enabled,
    bool? required,
    bool? allowNote,
    bool? trackCompletion,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'year': year,
      'key': key,
      'label': label,
      'behaviour': behaviour.wire,
      'description': ?description,
      'sortOrder': ?sortOrder,
      'enabled': ?enabled,
      'required': ?required,
      'allowNote': ?allowNote,
      'trackCompletion': ?trackCompletion,
      'status': ?status,
    };
    if (id == null) {
      await _client.post('/admin/daily-diet/sections', body: body);
    } else {
      await _client.patch('/admin/daily-diet/sections/$id', body: body);
    }
    _refresh(year);
  }

  /// Publishes a section so members can see it.
  Future<void> publishSection(String id, int year) async {
    await _client.post('/admin/daily-diet/sections/$id/publish');
    _refresh(year);
  }

  /// Archives a section and takes it out of the member's Daily Diet.
  Future<void> archiveSection(String id, int year) async {
    await _client.post('/admin/daily-diet/sections/$id/archive');
    _refresh(year);
  }

  /// Deletes a section and everything published under it.
  Future<void> deleteSection(String id, int year) async {
    await _client.delete('/admin/daily-diet/sections/$id');
    _refresh(year);
  }

  /// Sets the order of every section in one call.
  Future<void> reorder({
    required String programmeId,
    required List<String> order,
    required int year,
  }) async {
    await _client.post('/admin/daily-diet/sections/reorder', body: {
      'programmeId': programmeId,
      'order': order,
    });
    _refresh(year);
  }

  /// Creates or replaces the content a section carries on a date.
  Future<void> saveContent({
    required int year,
    required String sectionId,
    required String date,
    required DailyDietScope scope,
    required String title,
    String? body,
    Map<String, dynamic>? details,
    List<String> materialIds = const [],
    String? externalUrl,
    int? durationTargetMinutes,
    String status = 'PUBLISHED',
  }) async {
    await _client.put('/admin/daily-diet/content', body: {
      'sectionId': sectionId,
      'date': date,
      'scope': scope.wire,
      'title': title,
      'body': body,
      'details': details,
      'materialIds': materialIds,
      'externalUrl': externalUrl,
      'durationTargetMinutes': durationTargetMinutes,
      'status': status,
    });
    _refresh(year);
  }

  /// Publishes a single content row.
  Future<void> publishContent(String id, int year) async {
    await _client.post('/admin/daily-diet/content/$id/publish');
    _refresh(year);
  }

  /// Publishes every content row written for one date.
  Future<int> publishDay(String date, int year) async {
    final response = await _client.post(
      '/admin/daily-diet/content/publish-day',
      body: {'date': date},
    );
    _refresh(year);
    if (response is Map<String, dynamic>) {
      final count = response['published'];
      if (count is num) return count.toInt();
    }
    return 0;
  }

  /// Removes a content row.
  Future<void> deleteContent(String id, int year) async {
    await _client.delete('/admin/daily-diet/content/$id');
    _refresh(year);
  }
}
