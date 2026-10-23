import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/daily_diet_models.dart';
import '../../core/network/api_client.dart';

/// Tolerant map parse — the API always answers with JSON objects here.
Map<String, dynamic> _asMap(dynamic data) =>
    data is Map<String, dynamic> ? data : const {};

/// The Daily Diet for a single day.
///
/// The whole day arrives in one call: the sections the administrator
/// configured, the content each section carries for that date, the files
/// attached to it and the member's own tick-offs.
final dailyDietProvider =
    FutureProvider.autoDispose.family<DailyDietBundle, String>((ref, date) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/daily-diet', query: {'date': date});
  return DailyDietBundle.fromJson(_asMap(data));
});

/// Per-day completion counts for the member, used by the calendar strip.
final dailyDietProgressProvider = FutureProvider.autoDispose
    .family<List<DailyDietDayProgress>, DailyDietProgressRange>(
  (ref, range) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/daily-diet/progress', query: {
      'from': range.from,
      'to': range.to,
    });
    // The API answers `{data: [...]}` and the client unwraps that envelope.
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DailyDietDayProgress.fromJson)
        .toList();
  },
);

/// The window of dates the progress strip covers.
class DailyDietProgressRange {
  const DailyDietProgressRange({required this.from, required this.to});

  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is DailyDietProgressRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Completion counts for one date.
class DailyDietDayProgress {
  const DailyDietDayProgress({
    required this.date,
    required this.completed,
    required this.recorded,
  });

  final String date;
  final int completed;
  final int recorded;

  factory DailyDietDayProgress.fromJson(Map<String, dynamic> json) {
    return DailyDietDayProgress(
      date: (json['date'] ?? '') as String,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      recorded: (json['recorded'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Writes a member's tick-offs and refreshes the day bundle.
final dailyDietCompletionWriterProvider =
    Provider<DailyDietCompletionWriter>((ref) {
  return DailyDietCompletionWriter(ref);
});

/// Records (or clears) the member's tick-off for one section on one day.
class DailyDietCompletionWriter {
  DailyDietCompletionWriter(this._ref);

  final Ref _ref;

  ApiClient get _client => _ref.read(apiClientProvider);

  /// Saves the tick-off. Passing [DailyDietStatus.notStarted] clears it.
  Future<DailyDietCompletion?> save({
    required String sectionId,
    required String date,
    DailyDietStatus status = DailyDietStatus.completed,
    String? note,
    int? actualDurationMinutes,
    int? actualQuantity,
    String? attachmentFileId,
  }) async {
    final response = await _client.post('/daily-diet/completions', body: {
      'sectionId': sectionId,
      'date': date,
      'status': status.wire,
      'note': ?note,
      'actualDurationMinutes': ?actualDurationMinutes,
      'actualQuantity': ?actualQuantity,
      'attachmentFileId': ?attachmentFileId,
    });
    _ref.invalidate(dailyDietProvider(date));
    final completion = _asMap(response)['completion'];
    if (completion is Map<String, dynamic>) {
      return DailyDietCompletion.fromJson(completion);
    }
    return null;
  }

  /// Removes a tick-off entirely.
  Future<void> clear({
    required String completionId,
    required String date,
  }) async {
    await _client.delete('/daily-diet/completions/$completionId');
    _ref.invalidate(dailyDietProvider(date));
  }

  /// Uploads a member file and returns its id.
  Future<String?> uploadFile({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final response = await _client.upload(
      '/files',
      bytes: bytes,
      fieldName: 'file',
      filename: filename,
      contentType: contentType,
    );
    final file = _asMap(response)['file'];
    if (file is Map<String, dynamic>) return file['id'] as String?;
    return null;
  }
}
