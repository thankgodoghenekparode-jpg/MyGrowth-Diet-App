import 'package:flutter/material.dart';

/// A complete colour set for one appearance (light or dark).
///
/// The two palettes share the same four brand colours — dark blue `#09162A`,
/// black `#000000`, grey brown `#815E22` and white `#FFFFFF` — but assign them
/// to different roles:
///
/// Light mood
///   * Dark blue  — headers, brand bands, buttons, Home greeting block.
///   * Black      — deepest surfaces, gradient dark end, primary text.
///   * Grey brown — accent: icons, highlights, CTA pills, streak rings.
///   * White      — page background, cards, text on dark.
///
/// Dark mood
///   * Dark blue  — page background and cards (bordered with lighter navy).
///   * Black      — app bar and deepest surfaces.
///   * Grey brown — accent: buttons, CTA pills, icons, avatars.
///   * White      — all text.
class AppPalette {
  const AppPalette({
    required this.brand,
    required this.deepest,
    required this.accent,
    required this.onDark,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.fieldBg,
    required this.border,
    required this.borderStrong,
    required this.highlight,
    required this.tint,
    required this.tintStrong,
    required this.mutedOutline,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.inkDisabled,
    required this.accentText,
    required this.accentSoft,
    required this.brandText,
    required this.brandSurface,
    required this.iconAccent,
    required this.primaryAction,
    required this.onPrimary,
    required this.avatarBg,
    required this.avatarFg,
    required this.appBarBg,
    required this.linkText,
    required this.focusAccent,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.info,
    required this.infoSurface,
    required this.categoryTints,
  });

  // ----------------------------------------------------------- brand
  /// Dark blue — primary brand colour.
  final Color brand;
  /// Black — deepest surfaces and gradient dark end.
  final Color deepest;
  /// Grey brown — the accent colour.
  final Color accent;
  /// White — text on dark surfaces.
  final Color onDark;

  // -------------------------------------------------------- surfaces
  /// Page background.
  final Color background;
  /// Cards, sheets and modal surfaces.
  final Color surface;
  /// Recessed surfaces (sidebars, disabled fills).
  final Color surfaceMuted;
  /// Input fields.
  final Color fieldBg;
  /// Borders and dividers.
  final Color border;
  /// Stronger borders.
  final Color borderStrong;
  /// Highlighted panels and tinted chips.
  final Color highlight;
  /// Soft icon-circle fill.
  final Color tint;
  /// Slightly stronger tint fill.
  final Color tintStrong;
  /// Subtle outlines and inactive elements.
  final Color mutedOutline;

  // ------------------------------------------------------------ text
  /// Primary text.
  final Color ink;
  /// Secondary text.
  final Color inkSecondary;
  /// Muted text and captions.
  final Color inkMuted;
  /// Disabled text.
  final Color inkDisabled;

  // --------------------------------------------------- accents / UI
  /// Accent used as text (readable on tinted surfaces).
  final Color accentText;
  /// Softer accent used for rings and decorative highlights.
  final Color accentSoft;
  /// Brand colour used as text on a tinted surface.
  final Color brandText;
  /// Brand-coloured panel (slightly lifted in the dark mood).
  final Color brandSurface;
  /// Accent used for icons sitting on the current surface.
  final Color iconAccent;
  /// Background of the primary call to action.
  final Color primaryAction;
  /// Foreground of the primary call to action.
  final Color onPrimary;
  /// Avatar / initials disc.
  final Color avatarBg;
  /// Avatar initials.
  final Color avatarFg;
  /// App bar surface.
  final Color appBarBg;
  /// Colour for links and text buttons.
  final Color linkText;
  /// Focus ring colour.
  final Color focusAccent;

  // ---------------------------------------------------------- status
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;
  final Color info;
  final Color infoSurface;

  /// Soft per-category tints used for activity icons and badges.
  final List<Color> categoryTints;

  // ------------------------------------------------------------ light
  /// The light mood: white canvas, dark blue brand, grey brown accent.
  static const AppPalette light = AppPalette(
    brand: Color(0xFF09162A),
    deepest: Color(0xFF000000),
    accent: Color(0xFF815E22),
    onDark: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F4F7),
    fieldBg: Color(0xFFFFFFFF),
    border: Color(0xFFDDE3EC),
    borderStrong: Color(0xFFC7CFDB),
    highlight: Color(0xFFF3EDE1),
    tint: Color(0xFFEDF1F7),
    tintStrong: Color(0xFFDCE4EF),
    mutedOutline: Color(0xFF98A2B3),
    ink: Color(0xFF000000),
    inkSecondary: Color(0xFF4B5563),
    inkMuted: Color(0xFF7A8494),
    inkDisabled: Color(0xFFB3BCC8),
    accentText: Color(0xFF6B4D1C),
    accentSoft: Color(0xFFA98B4E),
    brandText: Color(0xFF09162A),
    brandSurface: Color(0xFF09162A),
    iconAccent: Color(0xFF09162A),
    primaryAction: Color(0xFF09162A),
    onPrimary: Color(0xFFFFFFFF),
    avatarBg: Color(0xFF09162A),
    avatarFg: Color(0xFFFFFFFF),
    appBarBg: Color(0xFF09162A),
    linkText: Color(0xFF09162A),
    focusAccent: Color(0xFF09162A),
    success: Color(0xFF2F6B4F),
    successSurface: Color(0xFFE9F2EC),
    warning: Color(0xFF8A6410),
    warningSurface: Color(0xFFF3EDE1),
    danger: Color(0xFFB3261E),
    dangerSurface: Color(0xFFFBEAE8),
    info: Color(0xFF3E5B7E),
    infoSurface: Color(0xFFEDF1F7),
    categoryTints: [
      Color(0xFFEDF1F7),
      Color(0xFFF3EDE1),
      Color(0xFFE9F2EC),
      Color(0xFFEDF1F7),
      Color(0xFFF3EDE1),
      Color(0xFFF2F4F7),
    ],
  );

  // ------------------------------------------------------------- dark
  /// The dark mood: navy canvas, black app bar, grey brown accent.
  static const AppPalette dark = AppPalette(
    brand: Color(0xFF09162A),
    deepest: Color(0xFF000000),
    accent: Color(0xFF815E22),
    onDark: Color(0xFFFFFFFF),
    background: Color(0xFF09162A),
    surface: Color(0xFF09162A),
    surfaceMuted: Color(0xFF060F1E),
    fieldBg: Color(0xFF0D1B31),
    border: Color(0xFF1E3357),
    borderStrong: Color(0xFF2A4370),
    highlight: Color(0xFF3A2C10),
    tint: Color(0xFF0A1626),
    tintStrong: Color(0xFF132540),
    mutedOutline: Color(0xFF6E86A8),
    ink: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFC7D2E2),
    inkMuted: Color(0xFF8FA0BA),
    inkDisabled: Color(0xFF4E5F7A),
    accentText: Color(0xFFC9A45C),
    accentSoft: Color(0xFFA98B4E),
    brandText: Color(0xFFFFFFFF),
    brandSurface: Color(0xFF14243E),
    iconAccent: Color(0xFF815E22),
    primaryAction: Color(0xFF815E22),
    onPrimary: Color(0xFFFFFFFF),
    avatarBg: Color(0xFF815E22),
    avatarFg: Color(0xFFFFFFFF),
    appBarBg: Color(0xFF000000),
    linkText: Color(0xFFC9A45C),
    focusAccent: Color(0xFFA98B4E),
    success: Color(0xFF6FD3A2),
    successSurface: Color(0xFF123528),
    warning: Color(0xFFE8B65A),
    warningSurface: Color(0xFF3A2C10),
    danger: Color(0xFFFF8A80),
    dangerSurface: Color(0xFF3D1D1B),
    info: Color(0xFF9CC4F0),
    infoSurface: Color(0xFF14294A),
    categoryTints: [
      Color(0xFF0A1626),
      Color(0xFF3A2C10),
      Color(0xFF123528),
      Color(0xFF14294A),
      Color(0xFF3A2C10),
      Color(0xFF060F1E),
    ],
  );
}
