import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The shared MyGrowth wallpaper.
///
/// The same photo sits behind the member home page and the navigation rail.
/// [AppChrome] paints it behind every route, and [AreaShell] paints it behind
/// the pages inside the navigation shell, so the whole app shares one
/// backdrop. In the dark mood the photo is replaced by the flat page colour.
class AppWallpaper extends StatelessWidget {
  const AppWallpaper({super.key, required this.child});

  /// Bundled photo used by the home page, the navigation and every screen.
  static const String asset = 'assets/images/app_background.jpg';

  /// How strongly the page colour is washed over the photo. This matches the
  /// treatment used on the home page so body text stays easy to read.
  static const double washOpacity = 0.76;

  final Widget child;

  /// The photo treatment for a page background, or `null` in the dark mood.
  ///
  /// Pass [wash] as `null` for the full-strength version used behind the
  /// navigation rail and drawer.
  static DecorationImage? image(
    BuildContext context, {
    double? wash = washOpacity,
  }) {
    if (Theme.of(context).brightness == Brightness.dark) return null;
    return DecorationImage(
      image: const AssetImage(asset),
      fit: BoxFit.cover,
      colorFilter: wash == null
          ? null
          : ColorFilter.mode(
              AppColors.background.withValues(alpha: wash),
              BlendMode.srcATop,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: image(context),
      ),
      child: child,
    );
  }
}

/// App-wide chrome: paints the shared wallpaper behind every route and makes
/// Material scaffolds transparent so the photo is visible on every page.
///
/// Cards, sheets, dialogs and the app bar keep their own opaque surfaces, so
/// only the page canvas lets the wallpaper through.
class AppChrome extends StatelessWidget {
  const AppChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppWallpaper(
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(scaffoldBackgroundColor: Colors.transparent),
        child: child,
      ),
    );
  }
}
