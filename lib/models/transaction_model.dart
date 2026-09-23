class TransactionModel {
  final String id;
  final String? receiptNumber;
  final double totalAmount;
  final double tax;
  final String paymentType;
  final String status;
  final String? customerName;
  final String? employeeName;
  final DateTime? createdAt;
  final List<TransactionItem> items;

  const TransactionModel({
    required this.id,
    this.receiptNumber,
    required this.totalAmount,
    required this.tax,
    required this.paymentType,
    required this.status,
    this.customerName,
    this.employeeName,
    this.createdAt,
    this.items = const [],
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      receiptNumber: (json['orderId'] ?? json['receiptNumber'])?.toString(),
      totalAmount: _toDouble(json['totalAmount'] ?? json['amount']),
      tax: _toDouble(json['taxAmount'] ?? json['tax'] ?? json['totalTax']),
      paymentType: json['paymentType'] ?? json['type'] ?? 'Cash',
      status: json['status'] ?? 'Completed',
      customerName: json['customer'] is Map
          ? (json['customer']['fullName'] ??
              '${json['customer']['firstName'] ?? ''} ${json['customer']['lastName'] ?? ''}'.trim())
          : json['customerName'],
      employeeName: json['employee'] is Map
          ? (json['employee']['fullName'] ?? json['employee']['name'])
          : (json['employee'] is String ? json['employee'] : json['employeeName']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      items: (json['items'] as List?)
          ?.map((i) => TransactionItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList() ?? [],
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

class TransactionItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  const TransactionItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['_id'] ?? '',
      name: json['item'] is Map ? json['item']['name'] ?? '' : json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: TransactionModel._toDouble(json['price']),
    );
  }
}
