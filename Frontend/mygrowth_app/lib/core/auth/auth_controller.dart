import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../network/api_client.dart';

/// Auth lifecycle states.
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.needsProfileCompletion = false,
    this.offlineMode = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool needsProfileCompletion;
  final bool offlineMode;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => user?.canUseAdminArea ?? false;
  bool get isMainAdmin => user?.isMainAdmin ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool clearUser = false,
    bool? needsProfileCompletion,
    bool? offlineMode,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      needsProfileCompletion:
          needsProfileCompletion ?? this.needsProfileCompletion,
      offlineMode: offlineMode ?? this.offlineMode,
    );
  }
}

/// Owns the session: login, registration, refresh, logout, profile updates.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final client = ref.read(apiClientProvider);
    client.onSessionExpired = () async {
      await signOut(clearServer: false);
    };
    client.onConnectionRestored = () {
      if (state.offlineMode) state = state.copyWith(offlineMode: false);
    };
    return const AuthState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  /// Restores a persisted session on app start. Returns the user if valid.
  Future<AppUser?> bootstrapSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _api.loadSession();
    if (!_api.hasSession) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return null;
    }
    try {
      final data = await _api.get('/me') as Map<String, dynamic>;
      final user = AppUser.fromJson(data);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        needsProfileCompletion: (data['profileCompleted'] as bool? ?? true) == false,
      );
      await _cacheUser(user, state.needsProfileCompletion);
      return user;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cachedOfflineState();
        if (cached != null) {
          state = cached;
          return cached.user;
        }
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
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

  Future<void> signIn({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;
    await _applyAuthResponse(data);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    ) as Map<String, dynamic>;
    await _applyAuthResponse(data);
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null) {
      throw ApiException(500, 'invalid_response', 'Login response was malformed.');
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
      needsProfileCompletion: (data['profileCompleted'] as bool? ?? true) == false,
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
    state = state.copyWith(
      user: user,
      needsProfileCompletion: false,
    );
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

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience provider for the signed-in user, or null.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isAuthenticated,
);
