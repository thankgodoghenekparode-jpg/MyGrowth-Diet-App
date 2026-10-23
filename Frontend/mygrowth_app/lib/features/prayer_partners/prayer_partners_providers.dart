import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/prayer_models.dart';
import '../../core/network/api_client.dart';
import '../programme/programme_providers.dart';

/// The member's current prayer-partner availability.
final prayerAvailabilityProvider =
    FutureProvider.autoDispose<PrayerAvailability>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/prayer-partners/availability');
    if (data is Map<String, dynamic>) {
      return PrayerAvailability.fromJson(data);
    }
    return const PrayerAvailability();
  },
);

/// Prayer sessions filtered by status, e.g. 'upcoming'.
final prayerSessionsProvider =
    FutureProvider.autoDispose.family<List<PrayerSession>, String>(
  (ref, status) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/prayer-partners/sessions',
      query: {'status': status},
    );
    return asJsonList(data).map(PrayerSession.fromJson).toList();
  },
);

/// Privacy-safe partner suggestions from the directory.
final prayerPartnerSuggestionsProvider =
    FutureProvider.autoDispose<List<PartnerSuggestion>>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/prayer-partners/discover');
    return asJsonList(data).map(PartnerSuggestion.fromJson).toList();
  },
);

/// Prayer requests by direction: 'incoming' | 'outgoing'.
final prayerRequestsProvider =
    FutureProvider.autoDispose.family<List<PrayerRequest>, String>(
  (ref, direction) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get(
      '/prayer-partners/requests',
      query: {'direction': direction},
    );
    return asJsonList(data).map(PrayerRequest.fromJson).toList();
  },
);

/// The member's current (or most recent) partnership, if any.
final currentPartnershipProvider =
    FutureProvider.autoDispose<Partnership?>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/prayer-partners/partnerships');
      final list = asJsonList(data).map(Partnership.fromJson).toList();
      if (list.isEmpty) return null;
      for (final p in list) {
        if (p.status == 'ACTIVE' || p.status == 'PAUSED') return p;
      }
      return list.first;
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  },
);
