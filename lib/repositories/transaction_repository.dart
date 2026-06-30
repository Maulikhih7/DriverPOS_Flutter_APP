import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.read(apiClientProvider));
});

class TerminalModel {
  final String id;
  final String name;
  final String tpn;
  final String authkey;

  const TerminalModel({
    required this.id,
    required this.name,
    required this.tpn,
    required this.authkey,
  });

  factory TerminalModel.fromJson(Map<String, dynamic> json) {
    return TerminalModel(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Terminal',
      tpn: json['tpn'] as String? ?? '',
      authkey: json['authkey'] as String? ?? '',
    );
  }
}

class TransactionRepository {
  final ApiClient _client;

  TransactionRepository(this._client);

  Future<List<TerminalModel>> getTerminals() async {
    final response = await _client.get(ApiConstants.terminals);
    final list = (response['data'] ?? response) as List? ?? [];
    return list
        .map((t) => TerminalModel.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> checkout({
    required String pinNumber,
    required String paymentType,
    required double amount,
    required double totalAmount,
    double totalDiscountAmount = 0,
    double? changeGiven,
    String? terminalId,
    String? bypassReferenceId,
    String? customerId,
    // Gift card
    bool applyGiftCard = false,
    List<Map<String, dynamic>> multiGiftCardData = const [],
    // Store credit
    bool applyStoreCredit = false,
    String? storeCreditNumber,
    double? storeCreditAmount,
    // Rain check
    bool applyRainCheck = false,
    List<Map<String, dynamic>> multiRainCheckData = const [],
    // Punch card
    bool applyPunchCard = false,
    String? punchCardNumber,
    // Anonymous gift card
    bool applyAnonymousGiftCard = false,
    String? giftCardNumber,
    double? giftCardAmount,
    // Saved card / OTP
    String? otp,
    String? cardId,
    String? customerEmail,
    // Split
    double? cardAmount,
    double? cashAmount,
    String? type,
  }) async {
    // Always-present fields
    final body = <String, dynamic>{
      'pinNumber': pinNumber,
      'paymentType': paymentType,
      'amount': amount,
      'totalAmount': totalAmount,
      'totalDiscountAmount': totalDiscountAmount,
    };

    // Optional fields — only include when non-null / non-default
    if (customerId != null) body['customerId'] = customerId;
    if (changeGiven != null) body['changeGiven'] = changeGiven;
    if (terminalId != null) body['terminalId'] = terminalId;
    if (bypassReferenceId != null) body['bypassReferenceId'] = bypassReferenceId;
    if (type != null) body['type'] = type;

    // Gift card
    if (applyGiftCard) {
      body['applyGiftCard'] = true;
      if (multiGiftCardData.isNotEmpty) body['applyMultiGiftCardData'] = multiGiftCardData;
    }
    // Store credit
    if (applyStoreCredit) {
      body['applyStoreCredit'] = true;
      if (storeCreditNumber != null) body['storeCreditNumber'] = storeCreditNumber;
      if (storeCreditAmount != null) body['storeCreditAmount'] = storeCreditAmount;
    }
    // Rain check
    if (applyRainCheck) {
      body['applyRainCheck'] = true;
      if (multiRainCheckData.isNotEmpty) body['applyMultiRainCheckData'] = multiRainCheckData;
    }
    // Punch card
    if (applyPunchCard && punchCardNumber != null) {
      body['applyPunchCard'] = true;
      body['punchCardNumber'] = punchCardNumber;
    }
    // Anonymous gift card
    if (applyAnonymousGiftCard) {
      body['applyAnonymousGiftCard'] = true;
      if (giftCardNumber != null) body['giftCardNumber'] = giftCardNumber;
      if (giftCardAmount != null) body['giftCardAmount'] = giftCardAmount;
    }
    // Saved card / OTP
    if (cardId != null) body['cardId'] = cardId;
    if (otp != null) body['otp'] = otp;
    if (customerEmail != null) body['customerEmail'] = customerEmail;
    // Split amounts
    if (cashAmount != null) body['cashAmount'] = cashAmount;
    if (cardAmount != null) body['cardAmount'] = cardAmount;

    await _client.post(ApiConstants.checkout, data: body);
  }

  /// POST /transaction/refund
  Future<void> refundOrder({
    required String pinNumber,
    required double amount,
    required String customerId,
    String? terminalId,
    String refundMethod = 'Original',
  }) async {
    await _client.post(
      ApiConstants.transactionRefund,
      data: <String, dynamic>{
        'pinNumber': pinNumber,
        'amount': amount,
        'customerId': customerId,
        'terminalId': ?terminalId,
        'refundMethod': refundMethod,
      },
    );
  }

  /// POST /transaction/issue-refund/:id
  Future<void> issueRefundFromTransaction(String transactionId) async {
    await _client.post('${ApiConstants.issueRefund}/$transactionId');
  }

  /// POST /transaction/sendOtp
  Future<void> sendOtp(String customerEmail) async {
    await _client.post(
      ApiConstants.sendOtp,
      data: {'customerEmail': customerEmail},
    );
  }

  /// POST /transaction/applyGiftCard
  Future<Map<String, dynamic>> applyGiftCard(String giftCardNumber) async {
    final response = await _client.post(
      ApiConstants.payWithGiftCard,
      data: {'giftCardNumber': giftCardNumber},
    );
    return (response['data'] ?? response) as Map<String, dynamic>;
  }

  Future<List<TransactionModel>> getTransactions({
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final path = search != null && search.isNotEmpty
        ? ApiConstants.transactionSearch
        : ApiConstants.transactionReport;

    final response = await _client.get(path, queryParams: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      'page': page,
      'limit': limit,
    });

    // API may return { data: [...] }, { data: { transactions: [...] } }, or just [...]
    dynamic raw = response is Map ? response['data'] : response;
    if (raw is Map) {
      raw = raw['transactions'] ?? raw['data'] ?? raw['list'] ?? raw['result'] ?? [];
    }
    final list = raw is List ? raw : [];
    return list.map((t) => TransactionModel.fromJson(Map<String, dynamic>.from(t as Map))).toList();
  }

  Future<TransactionModel> getTransactionById(String id) async {
    final response =
        await _client.get('${ApiConstants.transactionReport}/$id');
    return TransactionModel.fromJson(response['data']);
  }

  Future<void> voidTransaction(String id) async {
    await _client.post('${ApiConstants.voidTransaction}/$id');
  }

  Future<void> emailReceipt({
    required String transactionId,
    required String email,
  }) async {
    await _client.post(
      ApiConstants.transactionEmailReceipt,
      data: {'transactionId': transactionId, 'email': email},
    );
  }

  Future<void> issueRefund({
    required String transactionId,
    required double amount,
    required String reason,
  }) async {
    await _client.post(
      ApiConstants.transactionRefund,
      data: {
        'transactionId': transactionId,
        'amount': amount,
        'reason': reason,
      },
    );
  }
}
