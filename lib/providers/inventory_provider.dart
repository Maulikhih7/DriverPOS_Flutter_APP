import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';

final inventorySearchQueryProvider = StateProvider<String>((ref) => '');

final inventoryProvider = FutureProvider.autoDispose<List<InventoryModel>>((ref) async {
  final query = ref.watch(inventorySearchQueryProvider);
  return ref.read(inventoryRepositoryProvider).getInventory(
    search: query.isNotEmpty ? query : null,
  );
});

class InventoryActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final InventoryRepository _repo;
  final Ref _ref;

  InventoryActionsNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addItem(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addInventory(data);
      _ref.invalidate(inventoryProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateInventory(id, data);
      _ref.invalidate(inventoryProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteInventory(id);
      _ref.invalidate(inventoryProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final inventoryActionsProvider =
    StateNotifierProvider<InventoryActionsNotifier, AsyncValue<void>>((ref) {
  return InventoryActionsNotifier(ref.read(inventoryRepositoryProvider), ref);
});
