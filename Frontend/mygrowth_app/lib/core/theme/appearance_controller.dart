import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The appearance choices offered to the user.
enum AppearanceMode { system, light, dark }

/// Convenience helpers for [AppearanceMode].
extension AppearanceModeX on AppearanceMode {
  /// Human readable label.
  String get label => switch (this) {
        AppearanceMode.system => 'System',
        AppearanceMode.light => 'Light',
        AppearanceMode.dark => 'Dark',
      };

  /// Icon representing the mode.
  IconData get icon => switch (this) {
        AppearanceMode.system => Icons.brightness_auto_outlined,
        AppearanceMode.light => Icons.light_mode_outlined,
        AppearanceMode.dark => Icons.dark_mode_outlined,
      };

  /// The Material [ThemeMode] this appearance maps to.
  ThemeMode get themeMode => switch (this) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
      };
}

/// Persists the user's light/dark preference on the device.
class AppearanceController extends Notifier<AppearanceMode> {
  /// Shared-preferences key holding the saved choice.
  static const String storageKey = 'mgdp.appearance';

  /// Set once the user picks a mood, so a slow restore cannot undo it.
  bool _userPicked = false;

  @override
  AppearanceMode build() {
    // Restore the saved choice shortly after the first frame.
    Future<void>.microtask(_restore);
    return AppearanceMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    // The user may have chosen a mood before the read finished.
    if (_userPicked) return;
    final mode = switch (raw) {
      'light' => AppearanceMode.light,
      'dark' => AppearanceMode.dark,
      _ => AppearanceMode.system,
    };
    state = mode;
  }

  /// Saves and applies [mode].
  Future<void> setMode(AppearanceMode mode) async {
    _userPicked = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, mode.name);
  }

  /// Flips between light and dark, leaving "system" mode behind.
  Future<void> toggle(Brightness currentBrightness) async {
    final next = currentBrightness == Brightness.dark
        ? AppearanceMode.light
        : AppearanceMode.dark;
    await setMode(next);
  }
}

/// The active appearance preference.
final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceMode>(
  AppearanceController.new,
);
