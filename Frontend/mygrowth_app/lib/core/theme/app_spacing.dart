import 'package:flutter/widgets.dart';

/// Consistent spacing scale used across the app.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets pagePaddingMobile = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(10));
}

/// Responsive breakpoints for phone / tablet / desktop layouts.
class Breakpoints {
  Breakpoints._();

  static const double compact = 600;
  static const double medium = 1024;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compact && w < medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;
}
