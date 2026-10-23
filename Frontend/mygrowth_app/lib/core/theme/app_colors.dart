import 'package:flutter/material.dart';

import 'app_palette.dart';

/// MyGrowth Diet App colour tokens.
///
/// The tokens are thin accessors over the active [AppPalette], so a single
/// [AppColors.palette] swap re-skins the entire application. The light and
/// dark moods share the same four brand colours (dark blue `#09162A`, black
/// `#000000`, grey brown `#815E22`, white `#FFFFFF`) but assign them to
/// different roles — see [AppPalette] for the full breakdown.
class AppColors {
  AppColors._();

  static AppPalette _active = AppPalette.light;

  /// The palette currently in use. Swap this when the mood changes.
  // ignore: unnecessary_getters_setters
  static AppPalette get palette => _active;

  /// Sets the active palette. Called by the app when the mood resolves.
  static set palette(AppPalette value) => _active = value;

  // ------------------------------------------------- Primary brand blue
  /// Dark blue. Primary brand colour: headers, brand bands, buttons.
  static Color get forestGreen => _active.brand;
  /// Black. Deepest surfaces and the dark end of gradients.
  static Color get darkEmerald => _active.deepest;
  /// Muted blue-grey for progress bars and secondary accents.
  static Color get sageGreen => _active.info;
  /// Decorative lines and quiet accents.
  static Color get botanicalGreen => _active.mutedOutline;
  /// Completed / positive indicators.
  static Color get leafGreen => _active.success;

  /// Soft icon-circle fill.
  static Color get green50 => _active.tint;
  /// Slightly stronger tint fill.
  static Color get green100 => _active.tintStrong;

  // ------------------------------------------------------- Grey brown
  /// Grey brown. Icons, highlights, CTA pills and streak rings.
  static Color get champagneGold => _active.accent;
  /// Softer grey brown for rings and emphasised accents.
  static Color get softGold => _active.accentSoft;
  /// Accent used as text.
  static Color get goldText => _active.accentText;
  /// Accent icons.
  static Color get goldIcon => _active.accent;

  // ------------------------------------------- Backgrounds and surfaces
  /// Main screen background.
  static Color get ivory => _active.background;
  /// Cards and modal backgrounds.
  static Color get cream => _active.surface;
  /// Recessed / secondary surfaces.
  static Color get beige => _active.surfaceMuted;
  /// Borders and dividers.
  static Color get sand => _active.border;
  /// Highlighted panels and tinted chips.
  static Color get paleChampagne => _active.highlight;
  /// Input fields and light buttons.
  static Color get warmWhite => _active.fieldBg;
  /// Subtle outlines and inactive elements.
  static Color get taupe => _active.mutedOutline;
  /// Stronger borders.
  static Color get sandStrong => _active.borderStrong;

  // ------------------------------------------------------------- Text
  /// Primary text.
  static Color get ink => _active.ink;
  /// Secondary text.
  static Color get inkSecondary => _active.inkSecondary;
  /// Muted text and captions.
  static Color get inkMuted => _active.inkMuted;
  /// Text on dark surfaces.
  static Color get inkOnDark => _active.onDark;
  /// Disabled text.
  static Color get inkDisabled => _active.inkDisabled;

  // ---------------------------------------------- Semantic / canonical
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceMuted => _active.surfaceMuted;
  static Color get border => _active.border;
  static Color get borderStrong => _active.borderStrong;

  /// The most important action colour (primary buttons and CTAs).
  static Color get primary => _active.primaryAction;
  /// The darkest surface.
  static Color get primaryDark => _active.deepest;
  /// The accent colour.
  static Color get accent => _active.accent;
  /// Accent used as text on tinted surfaces.
  static Color get accentText => _active.accentText;
  /// Softer accent used for rings and decorative highlights.
  static Color get accentSoft => _active.accentSoft;

  // ----------------------------------------------------------- Status
  static Color get success => _active.success;
  static Color get successSurface => _active.successSurface;
  static Color get warning => _active.warning;
  static Color get warningSurface => _active.warningSurface;
  static Color get danger => _active.danger;
  static Color get dangerSurface => _active.dangerSurface;
  static Color get info => _active.info;
  static Color get infoSurface => _active.infoSurface;

  /// Soft per-category tints used for activity icons/badges.
  static List<Color> get categoryTints => _active.categoryTints;

  // --------------------------------------------------- Role-specific
  /// Brand colour used as text on a tinted surface.
  static Color get brandText => _active.brandText;
  /// Brand-coloured panel.
  static Color get brandSurface => _active.brandSurface;
  /// Accent used for icons sitting on the current surface.
  static Color get iconAccent => _active.iconAccent;
  /// Background of the primary call to action.
  static Color get primaryAction => _active.primaryAction;
  /// Foreground of the primary call to action.
  static Color get onPrimary => _active.onPrimary;
  /// Avatar / initials disc.
  static Color get avatarBg => _active.avatarBg;
  /// Avatar initials.
  static Color get avatarFg => _active.avatarFg;
  /// App bar surface.
  static Color get appBarBg => _active.appBarBg;
  /// Colour for links and text buttons.
  static Color get linkText => _active.linkText;
  /// Focus ring colour.
  static Color get focusAccent => _active.focusAccent;

  // --------------------------------------------------------------------
  // Legacy aliases. The identity moved from forest green/champagne gold to
  // the navy / grey-brown brand; these names are retained so existing call
  // sites keep compiling.
  // --------------------------------------------------------------------

  /// @deprecated Use [darkEmerald] / [forestGreen].
  static Color get navy900 => _active.deepest;
  /// @deprecated Use [brandText] for text or [brandSurface] for fills.
  static Color get navy800 => _active.brandText;
  /// @deprecated Use [iconAccent].
  static Color get navy700 => _active.iconAccent;
  /// @deprecated Use [iconAccent].
  static Color get navy600 => _active.iconAccent;
  /// @deprecated Use [tintStrong].
  static Color get navy100 => _active.tintStrong;
  /// @deprecated Use [tint].
  static Color get navy50 => _active.tint;

  /// @deprecated Use [accentText].
  static Color get gold600 => _active.accentText;
  /// @deprecated Use [accent].
  static Color get gold500 => _active.accentText;
  /// @deprecated Use [accentSoft].
  static Color get gold400 => _active.accentSoft;
  /// @deprecated Use [highlight].
  static Color get gold100 => _active.highlight;
}
