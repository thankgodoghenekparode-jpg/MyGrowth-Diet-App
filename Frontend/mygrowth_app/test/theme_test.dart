import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/core/theme/app_colors.dart';
import 'package:mygrowth_app/core/theme/app_palette.dart';
import 'package:mygrowth_app/core/theme/app_theme.dart';
import 'package:mygrowth_app/core/theme/appearance_controller.dart';
import 'package:mygrowth_app/core/theme/appearance_section.dart';
import 'package:mygrowth_app/core/widgets/app_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four brand colours the whole app is built from.
const Color brandNavy = Color(0xFF09162A);
const Color brandBlack = Color(0xFF000000);
const Color brandGreyBrown = Color(0xFF815E22);
const Color brandWhite = Color(0xFFFFFFFF);

void main() {
  setUp(() => AppColors.palette = AppPalette.light);
  tearDown(() => AppColors.palette = AppPalette.light);

  group('light mood', () {
    test('paints a white canvas with the navy brand', () {
      final theme = AppTheme.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, brandWhite);
      expect(theme.colorScheme.surface, brandWhite);
      expect(theme.colorScheme.primary, brandNavy);
      expect(theme.colorScheme.onPrimary, brandWhite);
      expect(theme.textTheme.bodyMedium?.color, brandBlack);
      expect(theme.appBarTheme.backgroundColor, brandNavy);
    });
  });

  group('dark mood', () {
    test('paints a navy canvas with a black app bar', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, brandNavy);
      expect(theme.colorScheme.surface, brandNavy);
      expect(theme.colorScheme.primary, brandGreyBrown);
      expect(theme.colorScheme.onPrimary, brandWhite);
      expect(theme.textTheme.bodyMedium?.color, brandWhite);
      expect(theme.appBarTheme.backgroundColor, brandBlack);
    });

    test('keeps cards on navy and separates them with a lighter border', () {
      final theme = AppTheme.dark;

      expect(theme.cardTheme.color, brandNavy);
      expect(
        theme.cardTheme.shape,
        isA<RoundedRectangleBorder>()
            .having((s) => s.side.color, 'side', const Color(0xFF1E3357)),
      );
    });
  });

  group('global colour tokens', () {
    test('follow the active palette', () {
      AppColors.palette = AppPalette.light;
      expect(AppColors.background, brandWhite);
      expect(AppColors.ink, brandBlack);
      expect(AppColors.primaryAction, brandNavy);
      expect(AppColors.accent, brandGreyBrown);

      AppColors.palette = AppPalette.dark;
      expect(AppColors.background, brandNavy);
      expect(AppColors.ink, brandWhite);
      expect(AppColors.primaryAction, brandGreyBrown);
      expect(AppColors.accent, brandGreyBrown);
      expect(AppColors.avatarBg, brandGreyBrown);
      expect(AppColors.iconAccent, brandGreyBrown);
      expect(AppColors.appBarBg, brandBlack);
    });
  });

  group('rendered widgets', () {
    Widget harness(ThemeData theme) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('MyGrowth Diet App')),
          body: Column(
            children: [
              const AppCard(child: Text('Card body')),
              FilledButton(onPressed: () {}, child: const Text('Action')),
            ],
          ),
        ),
      );
    }

    testWidgets('light mood renders white surfaces on a white canvas',
        (tester) async {
      AppColors.palette = AppPalette.light;
      await tester.pumpWidget(harness(AppTheme.light));

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.scaffoldBackgroundColor, brandWhite);
      expect(theme.appBarTheme.backgroundColor, brandNavy);

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, brandWhite);
      expect(
        card.shape,
        isA<RoundedRectangleBorder>()
            .having((s) => s.side.color, 'side', const Color(0xFFDDE3EC)),
      );

      final buttonStyle = theme.filledButtonTheme.style!;
      expect(buttonStyle.backgroundColor!.resolve({}), brandNavy);
      expect(buttonStyle.foregroundColor!.resolve({}), brandWhite);
    });

    testWidgets('dark mood renders navy surfaces on a navy canvas',
        (tester) async {
      AppColors.palette = AppPalette.dark;
      await tester.pumpWidget(harness(AppTheme.dark));

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.scaffoldBackgroundColor, brandNavy);
      expect(theme.appBarTheme.backgroundColor, brandBlack);

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, brandNavy);
      expect(
        card.shape,
        isA<RoundedRectangleBorder>()
            .having((s) => s.side.color, 'side', const Color(0xFF1E3357)),
      );

      final buttonStyle = theme.filledButtonTheme.style!;
      expect(buttonStyle.backgroundColor!.resolve({}), brandGreyBrown);
      expect(buttonStyle.foregroundColor!.resolve({}), brandWhite);
    });
  });

  group('appearance preference', () {
    testWidgets('restores the saved mood', (tester) async {
      SharedPreferences.setMockInitialValues({'mgdp.appearance': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appearanceProvider), AppearanceMode.system);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });

    testWidgets('saves the chosen mood', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appearanceProvider.notifier).setMode(
            AppearanceMode.dark,
          );
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppearanceController.storageKey), 'dark');
      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });

    testWidgets('the header button flips between light and dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AppearanceToggleButton()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AppearanceToggleButton));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppearanceToggleButton)),
      );
      expect(container.read(appearanceProvider), AppearanceMode.dark);
    });
  });
}
