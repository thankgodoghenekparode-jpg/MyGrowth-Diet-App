import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../network/api_client.dart';

/// Auth lifecycle states.
enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.needsProfileCompletion = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool needsProfileCompletion;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => user?.canUseAdminArea ?? false;
  bool get isMainAdmin => user?.isMainAdmin ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool clearUser = false,
    bool? needsProfileCompletion,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      needsProfileCompletion:
          needsProfileCompletion ?? this.needsProfileCompletion,
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
      return user;
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isNetworkError) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        // Keep the session but surface an error state via unauthenticated-less
        // fallback: treat as unauthenticated so the user can retry login.
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
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
  }

  /// Refreshes cached profile data from the backend.
  Future<AppUser?> refreshUser() async {
    final data = await _api.get('/me') as Map<String, dynamic>;
    final user = AppUser.fromJson(data);
    state = state.copyWith(user: user);
    return user;
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final data = await _api.patch('/me', body: patch) as Map<String, dynamic>;
    final user = AppUser.fromJson(data);
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
