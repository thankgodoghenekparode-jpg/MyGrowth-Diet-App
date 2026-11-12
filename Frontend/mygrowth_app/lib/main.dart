import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/performance/app_performance.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppPerformance.start();
  runApp(const ProviderScope(child: MyGrowthApp()));
  AppPerformance.markFirstFrame();
}
