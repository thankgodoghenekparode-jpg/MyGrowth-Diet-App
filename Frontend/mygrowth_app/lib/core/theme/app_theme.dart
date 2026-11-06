import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';

/// Central Material themes for MyGrowth Diet App.
///
/// Two moods are built from the same structure so switching between them
/// never changes layout — only colour. [light] paints a white canvas with
/// the dark-blue brand; [dark] paints a navy canvas with a black app bar.
class AppTheme {
  AppTheme._();

  /// The light mood.
  static final ThemeData light = _build(AppPalette.light, Brightness.light);

  /// The dark mood.
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.brand,
        brightness: brightness,
        primary: p.primaryAction,
        onPrimary: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onDark,
        surface: p.surface,
        onSurface: p.ink,
        error: p.danger,
        onError: p.onDark,
        outline: p.border,
      ),
      scaffoldBackgroundColor: p.background,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBarBg,
        foregroundColor: p.onDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(base.textTheme, p).titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: p.onDark,
            ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.cardRadius,
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primaryAction,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          elevation: 0,
          shadowColor: p.primaryAction.withValues(alpha: 0.28),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: p.fieldBg,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: p.borderStrong),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.linkText,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.fieldBg,
        hintStyle: TextStyle(color: p.inkMuted, fontSize: 15),
        labelStyle: TextStyle(color: p.inkSecondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.controlRadius,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.controlRadius,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.controlRadius,
          borderSide: BorderSide(color: p.focusAccent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.controlRadius,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.controlRadius,
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.highlight,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: p.inkSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          color: p.inkSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.deepest,
        contentTextStyle: TextStyle(
          color: p.onDark,
          fontSize: 14,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.linkText,
        unselectedLabelColor: p.inkMuted,
        indicatorColor: p.accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primaryAction,
        linearTrackColor: p.tintStrong,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onPrimary
              : p.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.primaryAction
              : p.surfaceMuted,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      extensions: const [],
    ).copyWith(
      focusColor: p.tint,
    );
  }

  /// Heading font (elegant serif) and body font (clean sans) per the brand
  /// typography guidance.
  static const String headingFont = 'PlayfairDisplay';
  static const String bodyFont = 'Inter';

  static TextTheme _textTheme(TextTheme base, AppPalette p) {
    final colors = base.apply(
      bodyColor: p.ink,
      displayColor: p.ink,
      fontFamily: bodyFont,
    );
    return colors.copyWith(
      displayLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: p.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: p.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: headingFont,
        fontSize: 23,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: p.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: p.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: p.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: p.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        height: 1.55,
        color: p.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14.5,
        height: 1.55,
        color: p.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13,
        height: 1.45,
        color: p.inkSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: p.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: p.inkSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: p.inkMuted,
      ),
    );
  }

  /// The emphasized motion duration used for subtle transitions.
  static const Duration motionDuration = Duration(milliseconds: 250);
  static const Curve motionCurve = Curves.easeOutCubic;
}
