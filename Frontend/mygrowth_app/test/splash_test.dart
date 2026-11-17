import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/app/router.dart';
import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:mygrowth_app/core/models/app_user.dart';
import 'package:mygrowth_app/core/theme/app_theme.dart';

/// Settles the session immediately, like a warm cache would.
class _SettledAuth extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<AppUser?> bootstrapSession() async => null;
}

/// Never settles, to exercise the splash safety net.
class _StuckAuth extends AuthController {
  @override
  AuthState build() => const AuthState();

  @override
  Future<AppUser?> bootstrapSession() async {
    state = const AuthState(status: AuthStatus.loading);
    return null;
  }
}

Widget _harness(AuthController Function() auth) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(auth)],
    child: MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
  );
}

void main() {
  testWidgets(
    'splash holds the animation, then leaves once the session is ready',
    (tester) async {
      await tester.pumpWidget(_harness(_SettledAuth.new));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SplashScreen)),
      );

      // The artwork plays for 2.25 s, so it must not be cut short.
      await tester.pump(const Duration(milliseconds: 2000));
      expect(container.read(splashAnimationProvider), isFalse);

      await tester.pump(const Duration(milliseconds: 600));
      expect(container.read(splashAnimationProvider), isTrue);
    },
  );

  testWidgets('splash leaves at the five second cap when the session stalls', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_StuckAuth.new));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SplashScreen)),
    );

    await tester.pump(const Duration(milliseconds: 4800));
    expect(container.read(splashAnimationProvider), isFalse);

    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(splashAnimationProvider), isTrue);
  });

  testWidgets('splash artwork has no background of its own', (tester) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/images/splash_anim.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      expect(codec.frameCount, 9);

      // Every frame must be a clean cut-out. A leaky key leaves a translucent
      // film across the frame, which reads as a bright box over the dark
      // wallpaper once the splash applies its dark-mood brightness lift.
      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 438);
        expect(frame.image.height, 388);

        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final rgba = bytes!.buffer.asUint8List();
        var transparent = 0;
        var film = 0;
        for (var p = 3; p < rgba.length; p += 4) {
          final alpha = rgba[p];
          if (alpha == 0) {
            transparent++;
          } else if (alpha != 255) {
            film++;
          }
        }
        final total = rgba.length ~/ 4;
        expect(
          transparent / total,
          greaterThan(0.8),
          reason: 'frame $i is not mostly transparent',
        );
        expect(
          film / total,
          lessThan(0.02),
          reason: 'frame $i keeps a translucent background film',
        );
      }
    });
  });
}
