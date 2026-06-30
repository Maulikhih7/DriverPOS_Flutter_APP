import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';

enum SocketStatus { disconnected, connecting, connected, error }

/// Each screen-config notifier creates its own [PageConfigService]
/// instance (not a shared singleton) — the service holds exactly one
/// socket subscribed to exactly one screenKey at a time, so sharing one
/// instance across screens would make the second `subscribeToScreenKey`
/// call tear down the first screen's socket.
class PageConfigService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.pageConfigBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  io.Socket? _socket;
  void Function(SocketStatus, String?)? onStatusChange;
  String? _activeScreenKey;

  // ── REST fetch ─────────────────────────────────────────────────────────────

  Future<T?> fetchScreenConfig<T>(
    String pageId,
    String screenKey,
    T Function(Map<String, dynamic> screenDoc) fromJson,
  ) async {
    try {
      final response = await _dio.get('${ApiConstants.pageConfigPath}/$pageId');
      final body = response.data;
      Map<String, dynamic>? screenDoc;
      if (body is Map<String, dynamic>) {
        final page = body['page'];
        if (page is Map<String, dynamic>) {
          final screens = page['screens'];
          if (screens is List) {
            for (final s in screens) {
              if (s is Map<String, dynamic> && s['screenKey'] == screenKey) {
                screenDoc = s;
                break;
              }
            }
          }
        }
      }
      if (screenDoc == null) {
        debugPrint('[PageConfig] screen "$screenKey" not found in REST response');
        return null;
      }
      return fromJson(screenDoc);
    } on DioException catch (e) {
      debugPrint('[PageConfig] REST fetch error: ${e.message}');
      return null;
    }
  }

  // ── Socket (mirrors SocketService pattern) ─────────────────────────────────

  Future<void> subscribeToScreenKey<T>({
    required String screenKey,
    required T Function(Map<String, dynamic> screenDoc) fromJson,
    required void Function(T config) onUpdate,
  }) async {
    _activeScreenKey = screenKey;

    // Dispose any previous socket before creating a new one
    _socket?.dispose();
    _socket = null;

    onStatusChange?.call(SocketStatus.connecting, null);

    final token = await const FlutterSecureStorage()
        .read(key: AppConstants.tokenKey);

    final opts = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(2000)
        .setReconnectionAttempts(10);

    if (token != null) opts.setAuth({'token': token});

    _socket = io.io(ApiConstants.pageConfigBaseUrl, opts.build());

    _socket!.onConnect((_) {
      debugPrint('[PageConfig] Socket connected — id: ${_socket?.id}');
      onStatusChange?.call(SocketStatus.connected, null);
      // Tell the server which screen we want updates for
      _socket!.emit('subscribe', {'screenKey': screenKey});
      debugPrint('[PageConfig] Emitted subscribe for "$screenKey"');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[PageConfig] Socket disconnected: $reason');
      onStatusChange?.call(SocketStatus.disconnected, reason?.toString());
    });

    _socket!.onConnectError((e) {
      debugPrint('[PageConfig] Connect error: $e');
      onStatusChange?.call(SocketStatus.error, e.toString());
    });

    _socket!.onReconnect((_) {
      debugPrint('[PageConfig] Reconnected — re-subscribing to "$screenKey"');
      _socket!.emit('subscribe', {'screenKey': screenKey});
    });

    _socket!.on('screen:update', (data) {
      debugPrint('[PageConfig] screen:update received');
      if (data is! Map) return;
      final payload = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);

      // Server wraps the screen document under payload['data']
      final raw = payload['data'];
      if (raw is! Map) return;
      final screenDoc = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);

      if (screenDoc['screenKey'] != _activeScreenKey) return;

      try {
        final config = fromJson(screenDoc);
        debugPrint('[PageConfig] Applying live update for "$_activeScreenKey"');
        onUpdate(config);
      } catch (e) {
        debugPrint('[PageConfig] Parse error: $e');
      }
    });

    _socket!.connect();
  }

  void unsubscribeFromScreenKey(String screenKey) {
    _socket?.off('screen:update');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _activeScreenKey = null;
    debugPrint('[PageConfig] Unsubscribed from "$screenKey"');
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _dio.close();
    debugPrint('[PageConfig] Disposed');
  }
}
