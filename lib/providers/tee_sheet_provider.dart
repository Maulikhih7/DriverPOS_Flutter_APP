import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/tee_sheet_model.dart';
import '../repositories/tee_sheet_repository.dart';

final teeSheetListProvider = FutureProvider<List<TeeSheetInfo>>((ref) async {
  return ref.read(teeSheetRepositoryProvider).getAllTeesheets();
});

final selectedTeeSheetProvider = StateProvider<TeeSheetInfo?>((ref) => null);

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final teeSheetSlotsProvider = FutureProvider.autoDispose<List<TeeTimeRow>>((ref) async {
  final teeSheet = ref.watch(selectedTeeSheetProvider);
  final date = ref.watch(selectedDateProvider);
  if (teeSheet == null) return [];

  final golfCourseName = teeSheet.golfCourseName;
  if (golfCourseName == null || golfCourseName.isEmpty) return [];

  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  return ref.read(teeSheetRepositoryProvider).getTeeSheet(
    golfCourseName: golfCourseName,
    teeSheetName: teeSheet.name,
    date: dateStr,
  );
});

class TeeSheetActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TeeSheetActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<({String slotId, List<String> docIds})?> bookSlot({
    required String golfCourseId,
    required String teeSheetId,
    required String date,
    required String startingSlot,
    required int holes,
    required List<Map<String, dynamic>> customers,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(teeSheetRepositoryProvider).bookSlot(
        golfCourseId: golfCourseId,
        teeSheetId: teeSheetId,
        date: date,
        startingSlot: startingSlot,
        persons: customers.length,
        personPerSlot: 4,
        holes: holes,
        customers: customers,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(teeSheetSlotsProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> addCustomersToSalesCart({
    required String slotId,
    required List<String> docIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(teeSheetRepositoryProvider).addCustomersToSalesCart(
        slotId: slotId,
        individual: docIds,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteSlot(String slotId, {String? customerId}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(teeSheetRepositoryProvider).deleteSlot(slotId, customerId: customerId);
      state = const AsyncValue.data(null);
      _ref.invalidate(teeSheetSlotsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  String? get errorMessage {
    final s = state;
    if (s is AsyncError) return s.error.toString().replaceFirst('Exception: ', '');
    return null;
  }
}

final teeSheetActionsProvider =
    StateNotifierProvider<TeeSheetActionsNotifier, AsyncValue<void>>((ref) {
  return TeeSheetActionsNotifier(ref);
});
