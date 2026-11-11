import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps an auto-dispose provider's value briefly after its last listener leaves.
/// Invalidating the provider still refreshes it immediately.
void keepProviderAliveFor(
  Ref ref, {
  Duration ttl = const Duration(seconds: 30),
}) {
  final link = ref.keepAlive();
  final timer = Timer(ttl, link.close);
  ref.onDispose(timer.cancel);
}
