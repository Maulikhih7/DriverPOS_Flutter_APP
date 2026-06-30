import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/customer_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.read(apiClientProvider));
});

class CustomerRepository {
  final ApiClient _client;

  CustomerRepository(this._client);

  Future<List<CustomerModel>> getCustomers({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final path = search != null && search.isNotEmpty
        ? ApiConstants.customerSearch
        : ApiConstants.customerList;

    final response = await _client.get(path, queryParams: <String, dynamic>{
      if (search != null && search.isNotEmpty) 'name': search,
      'page': page,
      'limit': limit,
    });

    final list = (response['data'] ?? response) as List? ?? [];
    return list
        .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerModel> getCustomerById(String id) async {
    final response =
        await _client.get('${ApiConstants.customerList}/$id');
    final data = response['data'] ?? response;
    return CustomerModel.fromJson(data as Map<String, dynamic>);
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.createCustomer, data: data);
    final result = response['data'] ?? response;
    return CustomerModel.fromJson(result as Map<String, dynamic>);
  }

  Future<CustomerModel> updateCustomer(
      String id, Map<String, dynamic> data) async {
    final response = await _client.put(
        '${ApiConstants.updateCustomer}/$id',
        data: data);
    final result = response['data'] ?? response;
    return CustomerModel.fromJson(result as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.delete('${ApiConstants.deleteCustomer}/$id');
  }

  Future<List<CustomerModel>> searchSuggestions(String query) async {
    return getCustomers(search: query, limit: 10);
  }
}
