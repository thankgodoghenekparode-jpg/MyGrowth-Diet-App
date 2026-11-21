import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<Map<String, String>>? _affirmations;

Future<String?> dailyAffirmationForDate(String date) async {
  if (!date.startsWith('2027-')) return null;
  _affirmations ??= _loadAffirmations();
  return (await _affirmations!)[date];
}

Future<Map<String, String>> _loadAffirmations() async {
  final data = jsonDecode(
    await rootBundle.loadString('assets/daily_affirmations_2027.json'),
  ) as Map<String, dynamic>;
  final affirmations = <String, String>{};
  for (final raw in data['affirmations'] as List<dynamic>) {
    if (raw is! Map<String, dynamic>) continue;
    final date = raw['date'];
    final text = raw['text'];
    if (date is String && text is String && text.trim().isNotEmpty) {
      affirmations[date] = text;
    }
  }
  return affirmations;
}

final dailyAffirmationProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, date) => dailyAffirmationForDate(date));
