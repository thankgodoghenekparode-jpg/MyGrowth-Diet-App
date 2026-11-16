import 'package:flutter/material.dart';
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
}
