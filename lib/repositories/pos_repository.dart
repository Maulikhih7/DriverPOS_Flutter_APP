import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/product_model.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(ref.read(apiClientProvider));
});

class PosRepository {
  final ApiClient _client;

  PosRepository(this._client);

  Future<List<DepartmentModel>> getDepartments({bool salesCart = false}) async {
    final response = await _client.get(
      ApiConstants.departments,
      queryParams: {
        if (salesCart) 'salesCart': true,
        'workStation': true,
      },
    );
    final list = (response['data'] ?? response) as List? ?? [];
    return list
        .map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<LabelModel>> getLabels({String? department}) async {
    final response = await _client.get(
      ApiConstants.labels,
      queryParams: <String, dynamic>{
        'department': ?department,
      },
    );
    final list = (response['data'] ?? response) as List? ?? [];
    return list
        .map((l) => LabelModel.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  // Products always via /label/products — matches web app's ProductListing component
  // Response: { data: [...], count: N, total: N, limit: N }
  Future<List<ProductModel>> getProducts({
    String? departmentId,
    String? labelId,
    String? name,
    int limit = 24,
    int page = 1,
  }) async {
    final response = await _client.get(
      ApiConstants.labelProducts,
      queryParams: <String, dynamic>{
        if (departmentId != null && departmentId.isNotEmpty) 'department': departmentId,
        if (labelId != null && labelId.isNotEmpty) 'label': labelId,
        if (name != null && name.isNotEmpty) 'name': name,
        'limit': limit,
        'page': page,
      },
    );

    // Response shape: { data: [...], count, total, limit }
    final raw = response;
    List? list;
    if (raw is Map) {
      final d = raw['data'];
      if (d is List) {
        list = d;
      } else if (d is Map) {
        // Possible nested shape { data: { docs: [...] } }
        final docs = d['docs'] ?? d['items'];
        if (docs is List) list = docs;
      }
    } else if (raw is List) {
      list = raw;
    }
    list ??= [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  // Returns the full server-side current sales cart
  Future<Map<String, dynamic>?> getViewSales(
      {String cartState = 'Sale'}) async {
    final response = await _client.get(
      ApiConstants.salesDetails,
      queryParams: {'cartState': cartState},
    );
    return response as Map<String, dynamic>?;
  }

  // POST /sales/add/item
  Future<Map<String, dynamic>> addItemToSales({
    required String customerId,
    required String? golfCourseId,
    required List<Map<String, dynamic>> products,
    String cartState = 'Sale',
  }) async {
    final response = await _client.post(
      ApiConstants.addItemToSales,
      data: <String, dynamic>{
        'cartState': cartState,
        'customerId': customerId,
        'product': products,
        'golfCourseId': ?golfCourseId,
      },
    );
    return response as Map<String, dynamic>;
  }

  // DELETE /sales/remove?cartState=... with body
  Future<void> removeFromSales({
    required String customerCartId,
    required String itemId,
    String cartState = 'Sale',
  }) async {
    await _client.delete(
      ApiConstants.removeFromSales,
      data: <String, dynamic>{
        'customerCartId': customerCartId,
        'itemId': itemId,
        'cartState': cartState,
      },
    );
  }

  // PUT /sales/cart/:saleId?cartState=...
  // Backend reads cartState from the query string (req.query), not the body
  // — sending it as a body field (the old implementation) meant the backend
  // always saw cartState as undefined and 400'd with "Cart state should be
  // Sale or Hold or Return" regardless of what value was actually passed.
  Future<void> sendToState(String saleId, String cartState) async {
    await _client.put(
      '${ApiConstants.holdSales}/$saleId',
      data: <String, dynamic>{},
      queryParams: {'cartState': cartState},
    );
  }

  Future<Map<String, dynamic>> createSaleAndAddProducts({
    required String customerId,
    required String? golfCourseId,
    required List<Map<String, dynamic>> products,
    String? saleId,
  }) async {
    final response = await _client.post(
      ApiConstants.addProductsToSales,
      data: <String, dynamic>{
        'saleId': ?saleId,
        'cartState': 'Sale',
        'customerId': customerId,
        'product': products,
        'golfCourseId': ?golfCourseId,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHoldCarts() async {
    final response = await _client.get(ApiConstants.holdCarts);
    return List<Map<String, dynamic>>.from(
        (response['data'] ?? response) as List? ?? []);
  }

  // DELETE /sales/remove/:saleId
  Future<void> removeHoldCart(String saleId) async {
    await _client.delete('${ApiConstants.removeFromSales}/$saleId');
  }

  // GET /sales/cart-config
  Future<Map<String, dynamic>?> getCartConfig() async {
    final response = await _client.get(ApiConstants.cartConfig);
    return (response['data'] ?? response) as Map<String, dynamic>?;
  }

  // GET /terminal/:id — full terminal doc (includes tpn), unlike cart-config's trimmed summary
  Future<Map<String, dynamic>?> getTerminalDetails(String terminalId) async {
    final response = await _client.get('${ApiConstants.terminals}/$terminalId');
    return (response['data'] ?? response) as Map<String, dynamic>?;
  }

  Future<void> holdCart({
    required String customerId,
    required String? golfCourseId,
    required List<Map<String, dynamic>> products,
  }) async {
    await _client.post(
      ApiConstants.addProductsToSales,
      data: <String, dynamic>{
        'cartState': 'Hold',
        'customerId': customerId,
        'product': products,
        'golfCourseId': ?golfCourseId,
      },
    );
  }

  Future<void> clearSaleCart() async {
    await _client.delete(ApiConstants.clearSales);
  }

  Future<ProductModel?> scanBarcode(String barcode) async {
    try {
      final response = await _client.get(
        ApiConstants.barcodeScan,
        queryParams: {'barcode': barcode},
      );
      final data = response['data'];
      if (data == null) return null;
      return ProductModel.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
