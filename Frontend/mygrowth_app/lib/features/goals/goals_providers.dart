import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/goal_models.dart';
import '../programme/programme_providers.dart';

/// The member's goals for a period type ('WEEKLY' | 'MONTHLY').
final goalsProvider =
    FutureProvider.autoDispose.family<List<Goal>, String>(
  (ref, periodType) async {
    final client = ref.watch(apiClientProvider);
    final data =
        await client.get('/me/goals', query: {'periodType': periodType});
    return asJsonList(data).map(Goal.fromJson).toList();
  },
);
