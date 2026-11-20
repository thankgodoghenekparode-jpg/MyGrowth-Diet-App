import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:mygrowth_app/core/models/app_user.dart';
import 'package:mygrowth_app/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AppUser(
  id: 'u1',
  name: 'Grace Member',
  email: 'grace@example.com',
  role: 'MEMBER',
  status: 'ACTIVE',
);

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.meError}) : super();

  final Object? meError;
  int meCalls = 0;
  bool sessionCleared = false;

  @override
  bool get hasSession => true;

  @override
  Future<void> loadSession() async {}

  @override
  Future<void> clearSession() async {
    sessionCleared = true;
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    int maxRetries = 1,
    Duration? timeout,
  }) async {
    if (path != '/me') return null;
    meCalls++;
    if (meError != null) throw meError!;
    return _user.toJson();
  }
}

void _seedCachedUser() {
  SharedPreferences.setMockInitialValues({
    'mgdp.cachedUser': jsonEncode(_user.toJson()),
    'mgdp.cachedProfileCompletion': false,
  });
}

Future<void> _waitForBootstrap(ProviderContainer container) async {
  // AuthController.build schedules the restore in a microtask; wait for that
  // single restore to settle instead of starting a second one here.
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
    final state = container.read(authControllerProvider);
    if (state.status != AuthStatus.initial && !state.restoring) return;
  }
  fail('session bootstrap did not settle');
}

void main() {
  test('cached user stays signed in when session restore fails', () async {
    _seedCachedUser();
    final client = _FakeApiClient(
      meError: ApiException(
        0,
        'network',
        'Unable to reach the server.',
        isNetworkError: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await _waitForBootstrap(container);

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.id, _user.id);
    expect(state.offlineMode, isTrue);
    expect(state.restoring, isFalse);
    expect(client.meCalls, 1);
  });

  test('failed refresh keeps the cached user instead of signing out', () async {
    _seedCachedUser();
    final client = _FakeApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await _waitForBootstrap(container);
    await client.onSessionExpired!.call();

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.id, _user.id);
    expect(state.offlineMode, isTrue);
    expect(client.sessionCleared, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mgdp.cachedUser'), isNotNull);
  });

  test('unauthorized response does not trigger session revalidation', () async {
    var restored = 0;
    final client = ApiClient(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(client.close);
    client.onConnectionRestored = () => restored++;

    await expectLater(
      client.get('/me', maxRetries: 0),
      throwsA(isA<ApiException>()),
    );
    expect(restored, 0);
  });

  test('session user check does not retry a failed GET', () async {
    var requests = 0;
    final client = ApiClient(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('offline');
      }),
    );
    addTearDown(client.close);

    await expectLater(
      client.get(
        '/me',
        maxRetries: 0,
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(requests, 1);
  });
}
