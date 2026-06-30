import 'product_model.dart';

class CartItem {
  final ProductModel item;
  final int totalQuantity;
  final double discountPrice;
  final double totalDiscountedPrice;
  final double totalTaxAmount;
  final double totalTaxPercentage;
  final List<TaxInfo> fullTaxInfo;
  final CartAddOns addOns;

  const CartItem({
    required this.item,
    required this.totalQuantity,
    required this.discountPrice,
    required this.totalDiscountedPrice,
    required this.totalTaxAmount,
    required this.totalTaxPercentage,
    this.fullTaxInfo = const [],
    this.addOns = const CartAddOns(),
  });

  CartItem copyWith({
    ProductModel? item,
    int? totalQuantity,
    double? discountPrice,
    double? totalDiscountedPrice,
    double? totalTaxAmount,
    double? totalTaxPercentage,
    List<TaxInfo>? fullTaxInfo,
    CartAddOns? addOns,
  }) {
    return CartItem(
      item: item ?? this.item,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      discountPrice: discountPrice ?? this.discountPrice,
      totalDiscountedPrice: totalDiscountedPrice ?? this.totalDiscountedPrice,
      totalTaxAmount: totalTaxAmount ?? this.totalTaxAmount,
      totalTaxPercentage: totalTaxPercentage ?? this.totalTaxPercentage,
      fullTaxInfo: fullTaxInfo ?? this.fullTaxInfo,
      addOns: addOns ?? this.addOns,
    );
  }

  static CartItem fromProduct(ProductModel product, int quantity) {
    final price = product.effectivePrice;
    final taxPct = product.taxes.fold<double>(0, (sum, t) => sum + t.percentage);
    final taxPerUnit = price * taxPct / 100;
    return CartItem(
      item: product,
      totalQuantity: quantity,
      discountPrice: price,
      totalDiscountedPrice: price * quantity,
      totalTaxAmount: taxPerUnit,
      totalTaxPercentage: taxPct,
      fullTaxInfo: product.taxes,
    );
  }

  double get grandTotal =>
      totalDiscountedPrice + (totalTaxAmount * totalQuantity) + addOns.totalPrice;

  Map<String, dynamic> toCheckoutJson() {
    final data = <String, dynamic>{
      'item': item.rootId ?? item.id,
      'quantity': totalQuantity,
      'price': discountPrice,
      'tax': totalTaxPercentage,
    };
    if (item.punchCard != null) data['punchCard'] = item.punchCard;
    if (item.drivingRangePass != null) data['drivingRangePass'] = item.drivingRangePass;
    if (addOns.products.isNotEmpty) {
      data['addOns'] = addOns.products.map((p) => {
        'addOn': p.id,
        'quantity': p.quantity,
        'price': p.price,
      }).toList();
    }
    return data;
  }
}

class CartAddOns {
  final List<AddOnProduct> products;
  final double totalPrice;
  final double priceWithoutTax;
  final double totalTax;

  const CartAddOns({
    this.products = const [],
    this.totalPrice = 0,
    this.priceWithoutTax = 0,
    this.totalTax = 0,
  });
}

class AddOnProduct {
  final String id;
  final String name;
  final double price;
  final int quantity;

  const AddOnProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });
}
