import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../performance/app_performance.dart';
import '../network/api_client.dart';

/// Auth lifecycle states.
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.needsProfileCompletion = false,
    this.offlineMode = false,
    this.restoring = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool needsProfileCompletion;
  final bool offlineMode;

  /// True while the cached session is being revalidated in the background.
  /// Cached users can still use the app while this is happening.
  final bool restoring;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => user?.canUseAdminArea ?? false;
  bool get isMainAdmin => user?.isMainAdmin ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool clearUser = false,
    bool? needsProfileCompletion,
    bool? offlineMode,
    bool? restoring,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      needsProfileCompletion:
          needsProfileCompletion ?? this.needsProfileCompletion,
      offlineMode: offlineMode ?? this.offlineMode,
      restoring: restoring ?? this.restoring,
    );
  }
}

/// Owns the session: login, registration, refresh, logout, profile updates.
class AuthController extends Notifier<AuthState> {
  Future<AppUser?>? _bootstrap;

  @override
  AuthState build() {
    final client = ref.read(apiClientProvider);
    // A rejected refresh token is an expired session, not an offline session.
    // Keeping the cached identity in that state leaves the user on protected
    // content routes with no token, so every content request fails.
    client.onSessionExpired = _expireSession;
    client.onConnectionRestored = () {
      if (!state.offlineMode || !_api.hasSession) return;
      state = state.copyWith(offlineMode: false);
      unawaited(bootstrapSession());
    };
    Future.microtask(bootstrapSession);
    return const AuthState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  /// Restores a persisted session on app start. Returns the user if valid.
  ///
  /// Calls are de-duplicated so a reconnect and the initial microtask cannot
  /// start two competing `/me` requests.
  Future<AppUser?> bootstrapSession() {
    final pending = _bootstrap;
    if (pending != null) return pending;
    final future = _bootstrapSession();
    _bootstrap = future;
    return future.whenComplete(() => _bootstrap = null);
  }

  Future<AppUser?> _bootstrapSession() async {
    final stopwatch = Stopwatch()..start();
    try {
      return await _restoreSession();
    } finally {
      AppPerformance.log('session_restore', stopwatch.elapsed);
    }
  }

  Future<AppUser?> _restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading, restoring: true);
    try {
      await _api.loadSession();
    } catch (_) {
      // Token storage failures are handled by the cached-state fallback below.
    }
    final cached = await _cachedOfflineState();
    if (!_api.hasSession) {
      // A cached profile without a token cannot load protected programme
      // content. Keeping it authenticated here creates a permanent broken
      // offline session, so require the user to sign in again.
      if (cached != null) await _clearCachedUser();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        restoring: false,
      );
      return null;
    }

    // Show the cached identity immediately; revalidation runs in the
    // background and must never be allowed to log the user out on a bad
    // network day.
    if (cached != null) state = cached.copyWith(restoring: true);
    try {
      final data = await _api.get(
        '/me',
        maxRetries: 0,
        timeout: const Duration(seconds: 8),
      ) as Map<String, dynamic>;
      final user = AppUser.fromJson(data);
      final needsCompletion =
          (data['profileCompleted'] as bool? ?? true) == false;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        needsProfileCompletion: needsCompletion,
        restoring: false,
      );
      await _cacheUser(user, needsCompletion);
      return user;
    } on ApiException catch (error) {
      // The offline fallback is only useful for temporary connectivity/server
      // failures. A 401/403 means the cached session cannot access the API.
      if (error.isUnauthorized || error.isForbidden) {
        await _clearCachedUser();
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          restoring: false,
        );
        return null;
      }
      final fallback = cached ?? await _cachedOfflineState();
      if (fallback != null) {
        state = fallback.copyWith(restoring: false, offlineMode: true);
        return fallback.user;
      }
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        restoring: false,
      );
      return null;
    } on Object catch (_) {
      final fallback = cached ?? await _cachedOfflineState();
      if (fallback != null) {
        state = fallback.copyWith(restoring: false, offlineMode: true);
        return fallback.user;
      }
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        restoring: false,
      );
      return null;
    }
  }

  Future<void> _cacheUser(AppUser user, bool needsProfileCompletion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mgdp.cachedUser', jsonEncode(user.toJson()));
    await prefs.setBool('mgdp.cachedProfileCompletion', needsProfileCompletion);
  }

  Future<AuthState?> _cachedOfflineState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mgdp.cachedUser');
    if (raw == null) return null;
    try {
      final user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return AuthState(
        status: AuthStatus.authenticated,
        user: user,
        needsProfileCompletion:
            prefs.getBool('mgdp.cachedProfileCompletion') ?? false,
        offlineMode: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Removes a cached identity after the backend rejects its refresh token.
  Future<void> _expireSession() async {
    try {
      await _api.clearSession();
    } catch (_) {}
    await _clearCachedUser();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      restoring: false,
    );
  }

  Future<void> _clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mgdp.cachedUser');
      await prefs.remove('mgdp.cachedProfileCompletion');
    } catch (_) {}
  }

  Future<void> signIn({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;
    await _applyAuthResponse(data);
  }

  /// Creates the account but deliberately does not store a session. The user
  /// must complete the emailed OTP before any app data becomes available.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _api.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
  }

  /// Verifies the emailed 6-digit code and starts the authenticated session.
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      '/auth/verify-email-otp',
      body: {'email': email, 'code': code},
    ) as Map<String, dynamic>;
    await _applyAuthResponse(data);
  }

  /// Requests a replacement code. Returns the cooldown in seconds.
  Future<int> resendEmailOtp(String email) async {
    final data = await _api.post(
      '/auth/resend-email-otp',
      body: {'email': email},
    ) as Map<String, dynamic>;
    return data['retryAfterSeconds'] as int? ?? 60;
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null) {
      throw ApiException(
        500,
        'invalid_response',
        'Login response was malformed.',
      );
    }
    await _api.saveSession(accessToken: access, refreshToken: refresh);
    final userJson = data['user'] as Map<String, dynamic>?;
    AppUser user;
    if (userJson != null) {
      user = AppUser.fromJson(userJson);
    } else {
      final me = await _api.get('/me') as Map<String, dynamic>;
      user = AppUser.fromJson(me);
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      needsProfileCompletion:
          (data['profileCompleted'] as bool? ?? true) == false,
    );
    await _cacheUser(user, state.needsProfileCompletion);
  }

  /// Refreshes cached profile data from the backend.
  Future<AppUser?> refreshUser() async {
    final data = await _api.get('/me') as Map<String, dynamic>;
    final user = AppUser.fromJson(data);
    await _cacheUser(user, false);
    state = state.copyWith(user: user);
    return user;
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final data = await _api.patch('/me', body: patch) as Map<String, dynamic>;
    final user = AppUser.fromJson(data);
    await _cacheUser(user, false);
    state = state.copyWith(user: user, needsProfileCompletion: false);
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.post('/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: {'token': token, 'password': newPassword},
    );
  }

  Future<void> signOut({bool clearServer = true}) async {
    if (clearServer) {
      try {
        await _api.post('/auth/logout');
      } catch (_) {
        // Best effort; local session is cleared regardless.
      }
    }
    await _api.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mgdp.cachedUser');
    await prefs.remove('mgdp.cachedProfileCompletion');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Dismisses the one-time profile completion prompt.
  void acknowledgeProfileCompletion() {
    state = state.copyWith(needsProfileCompletion: false);
  }
}

// ---------------------------------------------------------------- providers

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Convenience provider for the signed-in user, or null.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isAuthenticated,
);
