/// Compile-time (build-time) application configuration.
///
/// Only public, client-safe values live here. No secrets ever ship in the
/// Flutter bundle; everything sensitive stays on the backend.
class AppConfig {
  AppConfig._();

  static const String appName = 'MyGrowth Diet App';
  static const String ministryName = 'Healings Erhuvwuigho Azuike Ministry';
  static const String programmeName = 'Growth Diet Plan 2027';
  static const String tagline =
      'Growing in the Word. Consistent in Prayer. Accountable in Purpose.';

  /// Default time zone label used for display; the backend stores UTC and
  /// each user has a configurable time zone (default Africa/Lagos).
  static const String defaultTimeZone = 'Africa/Lagos';

  /// API base URL defaults to the deployed backend so mobile release builds
  /// work without extra flags. Override for local development with:
  /// `flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mygrowth-diet-app.onrender.com/api/v1',
  );

  /// Public, cacheable Bible translations loaded when a member selects one
  /// other than the bundled WEB translation.
  static const String bibleContentBaseUrl = String.fromEnvironment(
    'BIBLE_CONTENT_BASE_URL',
    defaultValue: 'https://mygrowth-diet-app.onrender.com/bibles',
  );

  /// When true, a tiny in-memory demo dataset is used only if the backend is
  /// unreachable, purely so the UI can be previewed. Never enabled by default.
  static const bool allowOfflinePreview = bool.fromEnvironment(
    'ALLOW_OFFLINE_PREVIEW',
    defaultValue: false,
  );

  /// Turn a backend-relative media path (e.g. `/api/v1/avatars/<id>`) into an
  /// absolute URL the current platform can load.
  static String resolveUrl(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) return path;

    final base = Uri.parse(apiBaseUrl);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    var relative = path;
    if (basePath.isNotEmpty && relative.startsWith('$basePath/')) {
      relative = relative.substring(basePath.length);
    } else if (relative.startsWith('/api/v1/')) {
      relative = relative.substring('/api/v1'.length);
    }
    final normalized = relative.startsWith('/') ? relative : '/$relative';
    return base.replace(path: '$basePath$normalized').toString();
  }
}
