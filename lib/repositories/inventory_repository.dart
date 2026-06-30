import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/inventory_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(apiClientProvider));
});

class InventoryRepository {
  final ApiClient _client;

  InventoryRepository(this._client);

  Future<List<InventoryModel>> getInventory({
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final path = search != null && search.isNotEmpty
        ? ApiConstants.inventorySearch
        : ApiConstants.inventoryList;

    final response = await _client.get(path, queryParams: {
      if (search != null && search.isNotEmpty) 'name': search,
      if (category != null) 'category': category,
      'page': page,
      'limit': limit,
    });
    final list = response['data'] as List? ?? [];
    return list.map((i) => InventoryModel.fromJson(i)).toList();
  }

  Future<InventoryModel> addInventory(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.addInventory, data: data);
    return InventoryModel.fromJson(response['data']);
  }

  Future<InventoryModel> updateInventory(String id, Map<String, dynamic> data) async {
    final response = await _client.put(
      '${ApiConstants.updateInventory}/$id',
      data: data,
    );
    return InventoryModel.fromJson(response['data']);
  }

  Future<void> deleteInventory(String id) async {
    await _client.delete('${ApiConstants.deleteInventory}/$id');
  }
}
