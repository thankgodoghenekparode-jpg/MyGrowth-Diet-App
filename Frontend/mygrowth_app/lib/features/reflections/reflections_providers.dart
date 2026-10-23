import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/journal_models.dart';
import '../../core/network/api_client.dart';

/// The member's private journal entries.
final reflectionsProvider =
    FutureProvider.autoDispose<List<ReflectionEntry>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/me/reflections');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ReflectionEntry.fromJson)
          .toList();
    }
    return const [];
  },
);

/// The member's testimonies (private or pending consent-gated sharing).
final testimoniesProvider = FutureProvider.autoDispose<List<Testimony>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/me/testimonies');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Testimony.fromJson)
          .toList();
    }
    return const [];
  },
);

/// Annual letter state: [available] is false when the backend endpoint
/// isn't configured yet (404/501) — the editor stays usable locally.
class AnnualLetterState {
  const AnnualLetterState({this.content = '', this.available = true});

  final String content;
  final bool available;
}

final annualLetterProvider = FutureProvider.autoDispose<AnnualLetterState>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/me/annual-letter');
      if (data is Map<String, dynamic>) {
        final content = (data['content'] ??
                data['body'] ??
                data['text'] ??
                data['letter'])
            ?.toString();
        return AnnualLetterState(content: content ?? '');
      }
      return const AnnualLetterState();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        return const AnnualLetterState(available: false);
      }
      rethrow;
    }
  },
);
