import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/dvpaylite_config.dart';

class PaymentService {
  static const _channel = MethodChannel('com.driverpos.golf_pos_app/payment');
  static const _tpnKey = 'terminal_tpn';
  // Bounds how long we wait on the DVPayLite terminal — without this, a
  // hung terminal leaves the confirm button spinning forever with no way
  // for the cashier to recover short of restarting the app.
  static const _terminalTimeout = Duration(seconds: 90);

  static Future<Map?> _invokeWithTimeout(
    String method,
    Map<String, dynamic> args,
  ) {
    return _channel.invokeMethod<Map>(method, args).timeout(
      _terminalTimeout,
      onTimeout: () => throw PlatformException(
        code: 'TIMEOUT',
        message: 'Terminal did not respond in time',
      ),
    );
  }

  static Future<String?> getSavedTPN() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tpnKey);
  }

  static Future<void> saveTPN(String tpn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tpnKey, tpn);
  }

  static Future<void> clearTPN() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tpnKey);
  }

  static Future<Map<String, dynamic>> registerTerminal(String tpn) async {
    try {
      final result = await _channel.invokeMethod<Map>('registerTerminal', {
        'tpn': tpn,
        'applicationType': 'DVPAYLITE',
      });
      return result != null ? Map<String, dynamic>.from(result) : {};
    } on PlatformException catch (e) {
      throw PaymentException(e.code, e.message ?? 'Registration failed');
    }
  }

  static Future<PaymentResult> performSale({
    required String tpn,
    required double amount,
    String paymentType = 'CREDIT',
    double tip = 0.0,
    String? refId,
  }) async {
    final ref = refId ?? const Uuid().v4().replaceAll('-', '').substring(0, 12);
    final config = await DvPayLiteConfig.load();
    try {
      final result = await _invokeWithTimeout('performSale', {
        'tpn': tpn,
        'applicationType': 'DVPAYLITE',
        'type': 'SALE',
        'paymentType': paymentType,
        'amount': amount.toStringAsFixed(2),
        'tip': tip.toStringAsFixed(2),
        'refId': ref,
        ...config.toPaymentArgs(),
      });
      final res = result != null ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final approved = res['respCode'] == '00' || res['status'] == 'Approved';
      return PaymentResult(approved: approved, data: res, refId: ref);
    } on PlatformException catch (e) {
      throw PaymentException(e.code, e.message ?? 'Transaction failed');
    }
  }

  static Future<PaymentResult> performVoid({
    required String tpn,
    required String refId,
  }) async {
    final config = await DvPayLiteConfig.load();
    try {
      final result = await _invokeWithTimeout('performSale', {
        'tpn': tpn,
        'applicationType': 'DVPAYLITE',
        'type': 'VOID',
        'refId': refId,
        ...config.toPaymentArgs(),
      });
      final res = result != null ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final approved = res['respCode'] == '00' || res['status'] == 'Approved';
      return PaymentResult(approved: approved, data: res, refId: refId);
    } on PlatformException catch (e) {
      throw PaymentException(e.code, e.message ?? 'Void failed');
    }
  }

  static Future<PaymentResult> performRefund({
    required String tpn,
    required double amount,
    required String refId,
  }) async {
    final config = await DvPayLiteConfig.load();
    try {
      final result = await _invokeWithTimeout('performSale', {
        'tpn': tpn,
        'applicationType': 'DVPAYLITE',
        'type': 'REFUND',
        'amount': amount.toStringAsFixed(2),
        'refId': refId,
        ...config.toPaymentArgs(),
      });
      final res = result != null ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final approved = res['respCode'] == '00' || res['status'] == 'Approved';
      return PaymentResult(approved: approved, data: res, refId: refId);
    } on PlatformException catch (e) {
      throw PaymentException(e.code, e.message ?? 'Refund failed');
    }
  }
}

class PaymentResult {
  final bool approved;
  final Map<String, dynamic> data;
  final String refId;

  const PaymentResult({required this.approved, required this.data, required this.refId});

  String get authCode => data['authCode'] ?? data['approvalCode'] ?? '';
  String get cardLast4 => data['cardNumber'] ?? data['maskedCard'] ?? '****';
  String get responseCode => data['respCode'] ?? '';
  String get responseMessage => data['respMessage'] ?? data['message'] ?? '';
}

class PaymentException implements Exception {
  final String code;
  final String message;
  const PaymentException(this.code, this.message);

  @override
  String toString() => message;
}
