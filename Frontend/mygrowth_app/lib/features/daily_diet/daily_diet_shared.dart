import 'package:flutter/material.dart';

import '../../core/models/daily_diet_models.dart';
import '../../core/theme/app_colors.dart';

/// Icons for the canonical Daily Diet section keys.
///
/// Administrators may rename or add sections, so the key is only a hint:
/// unknown keys fall back to a neutral star.
IconData dailyDietIconFor(String key) => switch (key) {
      'prayer' => Icons.self_improvement_rounded,
      'scripture_reading' => Icons.menu_book_rounded,
      'bible_study' => Icons.history_edu_rounded,
      'literature_reading' => Icons.auto_stories_rounded,
      'proverbs_reading' => Icons.format_quote_rounded,
      'fasting_and_prayer' => Icons.wb_sunny_rounded,
      'report' => Icons.assignment_rounded,
      'declarations' => Icons.record_voice_over_rounded,
      'audio_message' => Icons.headphones_rounded,
      'prayer_partner_session' => Icons.handshake_rounded,
      'music' => Icons.music_note_rounded,
      _ => Icons.star_rounded,
    };

/// The icon for a section, derived from its key.
IconData dailyDietSectionIcon(DailyDietSection section) =>
    dailyDietIconFor(section.key);

/// A stable soft tint so each section keeps its colour across the app.
Color dailyDietTint(String key) {
  final tints = AppColors.categoryTints;
  if (tints.isEmpty) return AppColors.surfaceMuted;
  return tints[key.hashCode.abs() % tints.length];
}

/// The badge text for the scope a section's content was written for.
String dailyDietScopeLabel(DailyDietScope scope) => scope.label;

/// Human-friendly byte size.
String dailyDietFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final rounded = value >= 10 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}

/// A short, human label for the file type of a material.
String dailyDietFileTypeLabel(String? mimeType, String? fileName) {
  final name = (fileName ?? '').toLowerCase();
  if (name.endsWith('.pdf')) return 'PDF';
  if (name.endsWith('.mp3') || name.endsWith('.m4a') || name.endsWith('.wav')) {
    return 'Audio';
  }
  if (name.endsWith('.mp4')) return 'Video';
  if (name.endsWith('.doc') || name.endsWith('.docx')) return 'Document';
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.startsWith('audio/')) return 'Audio';
  if (mime.startsWith('video/')) return 'Video';
  if (mime.startsWith('image/')) return 'Image';
  if (mime.contains('pdf')) return 'PDF';
  return 'File';
}
