import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final customersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider);
  return ref.read(customerRepositoryProvider).getCustomers(
    search: query.isNotEmpty ? query : null,
  );
});

class CustomerActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerRepository _repo;
  final Ref _ref;

  CustomerActionsNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> createCustomer(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createCustomer(data);
      _ref.invalidate(customersProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateCustomer(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateCustomer(id, data);
      _ref.invalidate(customersProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCustomer(id);
      _ref.invalidate(customersProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final customerActionsProvider =
    StateNotifierProvider<CustomerActionsNotifier, AsyncValue<void>>((ref) {
  return CustomerActionsNotifier(ref.read(customerRepositoryProvider), ref);
});
