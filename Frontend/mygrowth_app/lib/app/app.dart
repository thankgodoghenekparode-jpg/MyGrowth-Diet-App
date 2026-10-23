import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/appearance_controller.dart';
import 'router.dart';

/// Root application widget: theme, localisation and routing live here.
///
/// The app ships two moods — a white light mood and a navy dark mood — and
/// the saved appearance preference decides which one is painted. The global
/// [AppColors.palette] is switched here, before the widget tree rebuilds, so
/// every screen follows the mood without any extra plumbing.
class MyGrowthApp extends ConsumerStatefulWidget {
  const MyGrowthApp({super.key});

  @override
  ConsumerState<MyGrowthApp> createState() => _MyGrowthAppState();
}

class _MyGrowthAppState extends ConsumerState<MyGrowthApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rebuilds when the operating system flips between light and dark so
  /// "system" mode stays in step with the device.
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final appearance = ref.watch(appearanceProvider);

    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final isDark = switch (appearance) {
      AppearanceMode.dark => true,
      AppearanceMode.light => false,
      AppearanceMode.system => systemDark,
    };

    // Keep the global colour tokens in step with the resolved mood before
    // any widget below reads them.
    AppColors.palette = isDark ? AppPalette.dark : AppPalette.light;

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appearance.themeMode,
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
