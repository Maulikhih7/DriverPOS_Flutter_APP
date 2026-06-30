class DashboardStats {
  final double todaySales;
  final int todayTransactions;
  final int bookedTeeTimes;
  final int totalCustomers;

  const DashboardStats({
    this.todaySales = 0,
    this.todayTransactions = 0,
    this.bookedTeeTimes = 0,
    this.totalCustomers = 0,
  });
}

class SalesDataPoint {
  final String label;
  final double amount;

  const SalesDataPoint({required this.label, required this.amount});

  factory SalesDataPoint.fromJson(Map<String, dynamic> json) {
    return SalesDataPoint(
      label: json['name'] ?? json['label'] ?? json['department'] ?? '',
      amount: _toDouble(json['amount'] ?? json['total'] ?? json['value']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

class TopSpender {
  final String customerId;
  final String customerName;
  final double totalSpent;

  const TopSpender({
    required this.customerId,
    required this.customerName,
    required this.totalSpent,
  });

  factory TopSpender.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final name = customer is Map
        ? '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim()
        : json['customerName'] ?? '';
    return TopSpender(
      customerId: customer is Map ? customer['_id'] ?? '' : '',
      customerName: name.isEmpty ? 'Guest' : name,
      totalSpent: SalesDataPoint._toDouble(json['totalSpent'] ?? json['amount']),
    );
  }
}

class BookedTeeTime {
  final String time;
  final String customerName;
  final int holes;
  final String status;

  const BookedTeeTime({
    required this.time,
    required this.customerName,
    required this.holes,
    required this.status,
  });

  factory BookedTeeTime.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final name = customer is Map
        ? '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim()
        : '';
    return BookedTeeTime(
      time: json['time'] ?? '',
      customerName: name.isEmpty ? 'Guest' : name,
      holes: json['holes'] ?? 18,
      status: json['status'] ?? 'Booked',
    );
  }
}

class LowInventoryItem {
  final String name;
  final int stock;
  final int threshold;

  const LowInventoryItem({
    required this.name,
    required this.stock,
    required this.threshold,
  });

  factory LowInventoryItem.fromJson(Map<String, dynamic> json) {
    return LowInventoryItem(
      name: json['name'] ?? '',
      stock: (json['stock'] ?? json['quantity'] ?? 0) is int
          ? json['stock'] ?? 0
          : int.tryParse('${json['stock'] ?? 0}') ?? 0,
      threshold: (json['lowStockThreshold'] ?? 10) is int
          ? json['lowStockThreshold'] ?? 10
          : int.tryParse('${json['lowStockThreshold'] ?? 10}') ?? 10,
    );
  }
}
