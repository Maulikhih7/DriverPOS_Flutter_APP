import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/dvpaylite_config.dart';

class PaymentService {
  static const _channel = MethodChannel('com.driverpos.golf_pos_app/payment');
  static const _tpnKey = 'terminal_tpn';

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
      final result = await _channel.invokeMethod<Map>('performSale', {
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
