import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  // Non-null when backend returned isVerified: false — holds the username
  final String? pendingPasswordChangeEmail;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.pendingPasswordChangeEmail,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    String? pendingPasswordChangeEmail,
    bool clearError = false,
    bool clearPendingPasswordChange = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      pendingPasswordChangeEmail: clearPendingPasswordChange
          ? null
          : (pendingPasswordChangeEmail ?? this.pendingPasswordChangeEmail),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _repo.getStoredUser();
    if (user != null) {
      state = AuthState(user: user, isAuthenticated: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true, clearPendingPasswordChange: true);
    try {
      final auth = await _repo.login(email: email, password: password);
      state = AuthState(user: auth.user, isAuthenticated: true);
      return true;
    } on PasswordChangeRequiredException catch (e) {
      // First login — backend requires password change before issuing tokens
      state = state.copyWith(
        isLoading: false,
        pendingPasswordChangeEmail: e.email,
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final email = state.pendingPasswordChangeEmail;
    if (email == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.changePassword(
        email: email,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      // Auto-login with new password after successful change
      final auth = await _repo.login(email: email, password: newPassword);
      state = AuthState(user: auth.user, isAuthenticated: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  void dismissPasswordChange() {
    state = state.copyWith(clearPendingPasswordChange: true, clearError: true);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        return 'Cannot reach server. Check that the backend is running.';
      }
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server. Check that the backend is running.';
    }
    return msg.replaceFirst('Exception: ', '');
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider));
  // When the API client fires onSessionExpired (401 + failed refresh),
  // sessionExpiredProvider increments → we log out and go to login.
  ref.listen<int>(sessionExpiredProvider, (prev, next) {
    notifier.logout();
  });
  return notifier;
});
