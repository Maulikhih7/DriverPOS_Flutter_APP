import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  bool get isSupported => _token != null;
  String? _token;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
      _token = await _messaging.getToken();
      debugPrint('FCM Token: $_token');
    } catch (e) {
      // Device lacks Google Play Services (e.g. dedicated terminals like P18)
      debugPrint('FCM not available on this device: $e');
    }
  }

  Future<String?> getToken() async => _token;

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title} — ${message.notification?.body}');
  }

  void _onNotificationTap(RemoteMessage message) {
    debugPrint('FCM tapped: ${message.data}');
  }
}
