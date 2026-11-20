import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'core/performance/app_performance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppPerformance.start();

  // Keeps music playing when the app is backgrounded and exposes lock-screen /
  // notification controls on mobile. On web this is a harmless no-op.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mygrowth.mygrowth_app.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
  );

  runApp(const ProviderScope(child: MyGrowthApp()));
  AppPerformance.markFirstFrame();
}
