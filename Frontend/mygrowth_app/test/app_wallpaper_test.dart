import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/core/theme/app_colors.dart';
import 'package:mygrowth_app/core/theme/app_palette.dart';
import 'package:mygrowth_app/core/theme/app_theme.dart';
import 'package:mygrowth_app/core/widgets/app_wallpaper.dart';

void main() {
  setUp(() => AppColors.palette = AppPalette.light);
  tearDown(() => AppColors.palette = AppPalette.light);

  testWidgets('chrome paints the wallpaper behind transparent scaffolds', (
    tester,
  ) async {
    late Color scaffoldColor;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) =>
            AppChrome(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(find.byType(AppWallpaper), findsOneWidget);
    // Scaffolds are transparent so the shared wallpaper shows on every page.
    expect(scaffoldColor, Colors.transparent);
  });

  testWidgets('wallpaper uses the photo in the light mood only', (
    tester,
  ) async {
    late DecorationImage? lightImage;
    late DecorationImage? darkImage;

    Widget probe(
      ThemeData theme,
      void Function(DecorationImage?) capture,
    ) => MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          capture(AppWallpaper.image(context));
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(
      probe(AppTheme.light, (image) => lightImage = image),
    );
    await tester.pumpWidget(probe(AppTheme.dark, (image) => darkImage = image));
    // The app animates between moods, so let the theme settle before reading.
    await tester.pumpAndSettle();

    expect(lightImage, isNotNull);
    expect(
      (lightImage!.image as AssetImage).assetName,
      AppWallpaper.asset,
    );
    // The dark mood keeps its flat navy canvas.
    expect(darkImage, isNull);
  });
}
