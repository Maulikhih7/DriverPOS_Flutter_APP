import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import 'encryption_service.dart';

// Notifier that the API client fires when the session expires.
// Auth provider listens to this to reset state and go to login.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.onSessionExpired = () {
    // Increment the counter — AuthNotifier watches this and logs out.
    Future.microtask(() {
      try { ref.read(sessionExpiredProvider.notifier).state++; } catch (_) {}
    });
  };
  return client;
});

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  // Called when a 401 cannot be recovered (session truly expired).
  VoidCallback? onSessionExpired;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Attach auth token
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Encrypt request body (POST / PUT / PATCH / DELETE-with-body)
    // Dev/staging server runs decryptMiddleware which expects { iv, data, tag }
    final body = options.data;
    if (body != null && body is Map) {
      final plainText = jsonEncode(body);
      final encrypted = await EncryptionService.encrypt(plainText);
      options.data = encrypted;
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken =
            await _storage.read(key: AppConstants.refreshTokenKey);
        if (refreshToken != null) {
          final res = await Dio().post(
            '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
            data: {'refreshToken': refreshToken},
          );
          final newToken = res.data['accessToken'] as String;
          await _storage.write(key: AppConstants.tokenKey, value: newToken);
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // Refresh failed — clear session and signal the app to go to login.
        await _clearSession();
        onSessionExpired?.call();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  // ── HTTP methods ─────────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    final response = await _dio.get(path, queryParameters: queryParams);
    return response.data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data;
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data;
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    final response = await _dio.patch(path, data: data);
    return response.data;
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    final response = await _dio.delete(path, data: data);
    return response.data;
  }
}
