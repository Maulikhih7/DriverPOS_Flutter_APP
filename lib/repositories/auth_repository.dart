import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

class PasswordChangeRequiredException implements Exception {
  final String email;
  const PasswordChangeRequiredException(this.email);
}

class AuthRepository {
  final ApiClient _client;
  final _storage = const FlutterSecureStorage();

  AuthRepository(this._client);

  Future<AuthResponse> login({
    required String email,
    required String password,
    String? timeZone,
  }) async {
    final response = await _client.post(
      '${ApiConstants.login}?role=workStation',
      data: {
        'email': email,
        'password': password,
        'timeZone': timeZone ?? AppConstants.defaultTimeZone,
      },
    );
    final json = response as Map<String, dynamic>;
    final userData = json['data'] as Map<String, dynamic>? ?? {};

    // Backend returns isVerified: false on first login — must change password first
    if (userData['isVerified'] == false) {
      throw PasswordChangeRequiredException(email);
    }

    final auth = AuthResponse.fromJson(json);
    await _storage.write(key: AppConstants.tokenKey, value: auth.accessToken);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: auth.refreshToken);
    await _storage.write(
        key: AppConstants.userKey, value: jsonEncode(auth.user.toJson()));
    return auth;
  }

  Future<void> changePassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.put(
      '${ApiConstants.updatePassword}?role=workStation',
      data: {
        'email': email,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  Future<UserModel?> getStoredUser() async {
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }
}
