import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';

/// App-level singleton — shared across all screens. Connect once after login,
/// disconnect on logout. Screens only subscribe/unsubscribe their event listeners.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

class SocketService {
  io.Socket? _socket;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  static String get _socketUrl {
    final base = ApiConstants.baseUrl; // e.g. https://api.dev.driverpos.io/api/v1
    final uri = Uri.parse(base);
    final isDefaultPort =
        (uri.scheme == 'https' && uri.port == 443) ||
        (uri.scheme == 'http' && uri.port == 80);
    return isDefaultPort
        ? '${uri.scheme}://${uri.host}'
        : '${uri.scheme}://${uri.host}:${uri.port}';
  }

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (_socket != null) return; // already created — socket manages reconnection itself

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    if (token == null) {
      debugPrint('[Socket] No token — skipping connection');
      return;
    }

    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected — id: ${_socket?.id}');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[Socket] Disconnected: $reason');
    });

    _socket!.onConnectError((e) {
      debugPrint('[Socket] Connect error: $e');
    });

    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnected');
    });

    _socket!.onAny((event, data) {
      debugPrint('[Socket] EVENT: $event  data: $data');
    });

    _socket!.connect();
  }

  // ---------------------------------------------------------------------------
  // Trigger-event subscription
  // Servers broadcast `/triggerEvent?teesheetId=X&date=Y` whenever a teesheet
  // changes (booking created/updated/deleted, pending slots, etc.).
  // ---------------------------------------------------------------------------

  void subscribeToTeeSheet({
    required String teeSheetId,
    required String date,
    required VoidCallback onUpdate,
  }) {
    if (_socket == null) {
      debugPrint('[Socket] Cannot subscribe — socket not created');
      return;
    }
    final event = '/triggerEvent?teesheetId=$teeSheetId&date=$date';
    _socket!.on(event, (_) {
      debugPrint('[Socket] TeeSheet trigger: $event');
      onUpdate();
    });
    debugPrint('[Socket] Subscribed to $event');
  }

  void unsubscribeFromTeeSheet({
    required String teeSheetId,
    required String date,
  }) {
    final event = '/triggerEvent?teesheetId=$teeSheetId&date=$date';
    _socket?.off(event);
    debugPrint('[Socket] Unsubscribed from $event');
  }

  // ---------------------------------------------------------------------------
  // Socket-based teesheet data fetch
  // Matches the web: emit `/teesheet`, listen to the per-query response event.
  // The backend emits the response on:
  //   `/teesheet?golfCourse=${golfCourseName}&teeSheet=${teeSheet}&date=${date}`
  // ---------------------------------------------------------------------------

  void requestTeeSheet({
    required String golfCourse,
    required String teeSheet,
    required String date,
    required void Function(Map<String, dynamic> data) onData,
    VoidCallback? onTimeout,
  }) {
    if (_socket == null) {
      debugPrint('[Socket] requestTeeSheet — socket not connected');
      return;
    }

    final responseEvent =
        '/teesheet?golfCourse=$golfCourse&teeSheet=$teeSheet&date=$date';

    _socket!.off(responseEvent); // clear any stale listener

    Timer? timer;

    _socket!.once(responseEvent, (data) {
      timer?.cancel();
      debugPrint('[Socket] TeeSheet data received for $responseEvent');
      if (data is Map<String, dynamic>) {
        onData(data);
      } else if (data is Map) {
        onData(Map<String, dynamic>.from(data));
      }
    });

    // Timeout safety: remove the listener if the server doesn't respond
    timer = Timer(const Duration(seconds: 10), () {
      _socket?.off(responseEvent);
      debugPrint('[Socket] requestTeeSheet timeout for $responseEvent');
      onTimeout?.call();
    });

    _socket!.emit('/teesheet', {
      'date': date,
      'golfCourse': golfCourse,
      'teeSheet': teeSheet,
    });

    debugPrint('[Socket] Emitted /teesheet for $responseEvent');
  }

  // ---------------------------------------------------------------------------
  // Pending reservation
  // Matches the web: emit `/pendingReservation` to hold a slot while the user
  // is filling the booking form, then release it on cancel or confirm.
  //
  // Backend responds on the same `/pendingReservation` event:
  //   { status, success, message, slotId? }
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> requestPendingSlot({
    required String teeSheetId,
    required String date,
    required String startingSlot,
    required int slotCustomer, // existing booked count in that slot
    required bool isPending,   // true = hold, false = release
    String? pendingSlotId,     // required when isPending == false
  }) async {
    if (_socket == null) {
      debugPrint('[Socket] requestPendingSlot — socket not connected');
      return null;
    }

    final completer = Completer<Map<String, dynamic>?>();

    _socket!.once('/pendingReservation', (data) {
      if (!completer.isCompleted) {
        if (data is Map<String, dynamic>) {
          completer.complete(data);
        } else if (data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete(null);
        }
      }
    });

    final payload = <String, dynamic>{
      'teeSheetId': teeSheetId,
      'date': date,
      'startingSlot': startingSlot,
      'slotCustomer': slotCustomer,
      'isPending': isPending,
    };
    final id = pendingSlotId;
    if (id != null) payload['pendingSlotId'] = id;

    _socket!.emit('/pendingReservation', payload);

    debugPrint(
        '[Socket] Emitted /pendingReservation isPending=$isPending for $teeSheetId/$date/$startingSlot');

    return completer.future
        .timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void dispose() {
    _socket?.dispose();
    _socket = null;
    debugPrint('[Socket] Disposed');
  }
}
