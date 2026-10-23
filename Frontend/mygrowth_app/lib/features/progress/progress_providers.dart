import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';

/// The member's aggregated (self-reported) progress summary.
final progressSummaryProvider =
    FutureProvider.autoDispose<ProgressSummary>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/me/progress');
  if (data is Map<String, dynamic>) {
    return ProgressSummary.fromJson(data);
  }
  return const ProgressSummary();
});
