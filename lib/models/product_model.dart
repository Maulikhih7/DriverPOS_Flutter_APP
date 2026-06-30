class ProductModel {
  final String id;
  final String? rootId;
  final String name;
  final double price;
  final double? discountPrice;
  final String? image;
  final String? department;
  final String? category;
  final List<TaxInfo> taxes;
  final bool? punchCard;
  final bool? drivingRangePass;
  final int? stock;
  final bool stockUnlimited;
  final String? barcode;
  final String? description;

  const ProductModel({
    required this.id,
    this.rootId,
    required this.name,
    required this.price,
    this.discountPrice,
    this.image,
    this.department,
    this.category,
    this.taxes = const [],
    this.punchCard,
    this.drivingRangePass,
    this.stock,
    this.stockUnlimited = false,
    this.barcode,
    this.description,
  });

  double get effectivePrice => discountPrice ?? price;

  String get stockDisplay =>
      stockUnlimited ? 'Unlimited' : (stock ?? 0).toString();

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handles both /inventory items (unitPrice, taxDetails, qtyUnlimited)
    // and /label/products items (price, taxes)
    final unlimited = json['qtyUnlimited'] == true;
    return ProductModel(
      id: json['_id'] ?? json['id'] ?? '',
      rootId: json['rootId'],
      name: json['name'] ?? '',
      price: _toDouble(json['unitPrice'] ?? json['price']),
      discountPrice: json['discountPrice'] != null
          ? _toDouble(json['discountPrice'])
          : null,
      image: json['image'],
      department: json['department'] is Map
          ? json['department']['name']
          : json['department'],
      category: json['category'] is Map
          ? json['category']['name']
          : json['category'],
      taxes: _parseTaxes(json),
      punchCard: json['punchCard'],
      drivingRangePass: json['drivingRangePass'],
      stockUnlimited: unlimited,
      stock: unlimited ? null : _toInt(json['quantity'] ?? json['stock']),
      barcode: json['barcode'],
      description: json['description'] ?? json['comments'],
    );
  }

  static List<TaxInfo> _parseTaxes(Map<String, dynamic> json) {
    // Backend inventory uses 'taxDetails'; label products may use 'taxes'
    final raw = (json['taxDetails'] as List?) ??
        (json['taxes'] as List?) ??
        [];
    return raw.map((t) => TaxInfo.fromJson(t as Map<String, dynamic>)).toList();
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

class TaxInfo {
  final String taxRateName;
  final double percentage;

  const TaxInfo({required this.taxRateName, required this.percentage});

  factory TaxInfo.fromJson(Map<String, dynamic> json) {
    return TaxInfo(
      taxRateName: json['taxRateName'] ?? json['name'] ?? '',
      percentage:
          ProductModel._toDouble(json['percentage'] ?? json['rate']),
    );
  }
}

class DepartmentModel {
  final String id;
  final String name;
  final bool? isSalesCart;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.isSalesCart,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      isSalesCart: json['isSalesCart'],
    );
  }
}

class LabelModel {
  final String id;
  final String name;

  const LabelModel({required this.id, required this.name});

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
