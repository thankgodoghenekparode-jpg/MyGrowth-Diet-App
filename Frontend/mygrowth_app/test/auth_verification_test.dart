import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:mygrowth_app/core/models/app_user.dart';
import 'package:mygrowth_app/core/network/api_client.dart';
import 'package:mygrowth_app/features/auth/email_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AppUser(
  id: 'verify-user',
  name: 'New Member',
  email: 'new@example.com',
  role: 'MEMBER',
  status: 'ACTIVE',
);

class _VerificationApiClient extends ApiClient {
  final List<String> calls = <String>[];
  final List<Object?> bodies = <Object?>[];
  bool sessionSaved = false;
  bool registrationStartsSession = false;

  @override
  bool get hasSession => false;

  @override
  Future<void> loadSession() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    calls.add(path);
    bodies.add(body);
    switch (path) {
      case '/auth/register':
        if (registrationStartsSession) {
          return {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'profileCompleted': false,
            'user': _user.toJson(),
          };
        }
        return {
          'user': _user.toJson(),
          'verification': {'required': true, 'emailSent': true},
        };
      case '/auth/resend-email-otp':
        return {'ok': true, 'retryAfterSeconds': 45};
      case '/auth/verify-email-otp':
        return {
          'accessToken': 'access-token',
          'refreshToken': 'refresh-token',
          'profileCompleted': false,
          'user': _user.toJson(),
        };
      default:
        return {'ok': true};
    }
  }

  @override
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    sessionSaved = true;
  }
}

Future<void> _waitForBootstrap(ProviderContainer container) async {
  // Build schedules session restore in a microtask; let it settle first so the
  // test does not race the controller with its own bootstrap.
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
    final state = container.read(authControllerProvider);
    if (state.status != AuthStatus.initial && !state.restoring) return;
  }
  fail('session bootstrap did not settle');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('registration does not create a signed-in session', () async {
    final client = _VerificationApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    await _waitForBootstrap(container);

    await container
        .read(authControllerProvider.notifier)
        .register(
          name: _user.name,
          email: _user.email,
          password: 'StrongPass1!',
        );

    expect(client.calls, contains('/auth/register'));
    expect(client.sessionSaved, isFalse);
    expect(container.read(authControllerProvider).user, isNull);
    expect(
      jsonEncode(client.bodies.first),
      contains('"email":"${_user.email}"'),
    );
  });

  test(
    'registration starts a session when email verification is disabled',
    () async {
      final client = _VerificationApiClient()..registrationStartsSession = true;
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      await _waitForBootstrap(container);

      final startedSession = await container
          .read(authControllerProvider.notifier)
          .register(
            name: _user.name,
            email: _user.email,
            password: 'StrongPass1!',
          );

      expect(startedSession, isTrue);
      expect(client.calls, contains('/auth/register'));
      expect(client.sessionSaved, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.id, _user.id);
    },
  );

  test('email OTP verification starts the session', () async {
    final client = _VerificationApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    await _waitForBootstrap(container);

    await container
        .read(authControllerProvider.notifier)
        .verifyEmailOtp(email: _user.email, code: '123456');

    expect(client.calls, contains('/auth/verify-email-otp'));
    expect(client.sessionSaved, isTrue);
    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.id, _user.id);
    expect(state.needsProfileCompletion, isTrue);
  });

  testWidgets('verification screen accepts only a 6-digit code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _VerificationApiClient();
    final router = GoRouter(
      initialLocation: '/verify-email?email=new%40example.com',
      routes: [
        GoRoute(
          path: '/verify-email',
          builder: (context, state) => EmailVerificationScreen(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Verify and continue'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12ab');
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    expect(client.calls, isEmpty);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify and continue'));
    await tester.pump();
    await tester.pump();

    expect(client.calls, contains('/auth/verify-email-otp'));
  });
}
