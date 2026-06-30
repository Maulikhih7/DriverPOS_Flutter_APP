class InventoryModel {
  final String id;
  final String name;
  final double price;
  final double? cost;
  final int stock;
  final bool stockUnlimited;
  final int? reorderLevel;
  final String? category;
  final String? subCategory;
  final String? department;
  final String? image;
  final String? barcode;
  final String? sku;
  final String? brand;
  final List<TaxDetail> taxDetails;
  final bool status;

  const InventoryModel({
    required this.id,
    required this.name,
    required this.price,
    this.cost,
    required this.stock,
    this.stockUnlimited = false,
    this.reorderLevel,
    this.category,
    this.subCategory,
    this.department,
    this.image,
    this.barcode,
    this.sku,
    this.brand,
    this.taxDetails = const [],
    this.status = true,
  });

  bool get isLowStock =>
      !stockUnlimited && reorderLevel != null && stock <= reorderLevel!;

  String get stockDisplay =>
      stockUnlimited ? 'Unlimited' : stock.toString();

  factory InventoryModel.fromJson(Map<String, dynamic> json) {
    final unlimited = json['qtyUnlimited'] == true;
    return InventoryModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      // Backend uses 'unitPrice' for selling price
      price: _toDouble(json['unitPrice'] ?? json['price']),
      cost: json['unitCost'] != null ? _toDouble(json['unitCost']) : null,
      stockUnlimited: unlimited,
      stock: unlimited ? 0 : _toInt(json['quantity'] ?? json['stock']),
      reorderLevel: json['reorderLevel'] is int
          ? json['reorderLevel']
          : int.tryParse('${json['reorderLevel'] ?? ''}'),
      category: json['category'] is Map
          ? json['category']['name']
          : json['category'],
      subCategory: json['subCategory'] is Map
          ? json['subCategory']['name']
          : json['subCategory'],
      department: json['department'] is Map
          ? json['department']['name']
          : json['department'],
      image: json['image'],
      barcode: json['barcode'],
      sku: json['sku'],
      brand: json['brand'],
      taxDetails: (json['taxDetails'] as List? ?? [])
          .map((t) => TaxDetail.fromJson(t as Map<String, dynamic>))
          .toList(),
      status: json['status'] ?? true,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class TaxDetail {
  final String taxRateName;
  final double percentage;

  const TaxDetail({required this.taxRateName, required this.percentage});

  factory TaxDetail.fromJson(Map<String, dynamic> json) {
    return TaxDetail(
      taxRateName: json['taxRateName'] ?? '',
      percentage: InventoryModel._toDouble(json['percentage']),
    );
  }
}
