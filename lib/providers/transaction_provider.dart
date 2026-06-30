import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

final transactionSearchQueryProvider = StateProvider<String>((ref) => '');

final transactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final query = ref.watch(transactionSearchQueryProvider);
  return ref.read(transactionRepositoryProvider).getTransactions(
    search: query.isNotEmpty ? query : null,
  );
});

class TransactionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repo;
  final Ref _ref;

  TransactionActionsNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> voidTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.voidTransaction(id);
      _ref.invalidate(transactionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> emailReceipt({required String transactionId, required String email}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.emailReceipt(transactionId: transactionId, email: email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final transactionActionsProvider =
    StateNotifierProvider<TransactionActionsNotifier, AsyncValue<void>>((ref) {
  return TransactionActionsNotifier(ref.read(transactionRepositoryProvider), ref);
});
