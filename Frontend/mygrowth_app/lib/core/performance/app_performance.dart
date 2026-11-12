import 'package:flutter/widgets.dart';

/// Small, privacy-safe performance markers visible in the browser/app console.
class AppPerformance {
  AppPerformance._();

  static final Stopwatch _sinceStart = Stopwatch();

  static void start() {
    if (!_sinceStart.isRunning) _sinceStart.start();
  }

  static void markFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      log(
        'first_frame',
        Duration(milliseconds: _sinceStart.elapsedMilliseconds),
      );
    });
  }

  static void log(String event, Duration duration, {String? detail}) {
    debugPrint(
      '[perf] $event duration_ms=${duration.inMilliseconds}'
      ' since_start_ms=${_sinceStart.elapsedMilliseconds}'
      '${detail == null ? '' : ' $detail'}',
    );
  }
}
