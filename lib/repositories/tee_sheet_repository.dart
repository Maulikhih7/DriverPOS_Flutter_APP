import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/tee_sheet_model.dart';

final teeSheetRepositoryProvider = Provider<TeeSheetRepository>((ref) {
  return TeeSheetRepository(ref.read(apiClientProvider));
});

class TeeSheetRepository {
  final ApiClient _client;

  TeeSheetRepository(this._client);

  Future<List<TeeSheetInfo>> getAllTeesheets() async {
    final response = await _client.get(ApiConstants.getAllTeesheets);
    final list = response['data'] as List? ?? [];
    return list.map((t) => TeeSheetInfo.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<List<TeeTimeRow>> getTeeSheet({
    required String golfCourseName,
    required String teeSheetName,
    required String date,
  }) async {
    final response = await _client.get(
      ApiConstants.teeSheet,
      queryParams: {
        'date': date,
        'golfCourse': golfCourseName,
        'teeSheet': teeSheetName,
      },
    );
    final list = response['data'] as List? ?? [];
    return list.map((t) => TeeTimeRow.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<({String slotId, List<String> docIds})> bookSlot({
    required String golfCourseId,
    required String teeSheetId,
    required String date,
    required String startingSlot,
    required int persons,
    required int holes,
    required List<Map<String, dynamic>> customers,
    int personPerSlot = 4,
    String? cartOne,
    String? cartTwo,
    String? notes,
    bool? split,
  }) async {
    final response = await _client.post(
      ApiConstants.bookSlot,
      data: {
        'golfCourseId': golfCourseId,
        'teeSheetId': teeSheetId,
        'date': date,
        'startingSlot': startingSlot,
        'persons': persons,
        'personPerSlot': personPerSlot,
        'holes': holes,
        'customers': customers,
        if (cartOne != null && cartOne.isNotEmpty) 'cartOne': cartOne,
        if (cartTwo != null && cartTwo.isNotEmpty) 'cartTwo': cartTwo,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (split != null) 'split': split,
      },
    );
    final slotId = response['data']?.toString() ?? '';
    final docIds = (response['docId'] as List?)
            ?.map((d) => d.toString())
            .toList() ??
        [];
    return (slotId: slotId, docIds: docIds);
  }

  Future<void> addCustomersToSalesCart({
    required String slotId,
    required List<String> individual,
  }) async {
    await _client.post(
      ApiConstants.addCustomerToSales,
      data: {
        'slotId': slotId,
        'individual': individual,
      },
    );
  }

  Future<List<CustomerSuggestion>> getCustomerSuggestions({
    required String golfCourseName,
    required String date,
    required String time,
    String? name,
  }) async {
    final response = await _client.get(
      ApiConstants.customerSuggestion,
      queryParams: {
        'golfCourse': golfCourseName,
        'date': date,
        'time': time,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    final list = response['data'] as List? ?? [];
    return list
        .map((c) => CustomerSuggestion.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteSlot(String slotId, {String? customerId}) async {
    await _client.delete(
      '${ApiConstants.deleteBooking}/$slotId',
      data: customerId != null ? {'customerId': customerId} : {},
    );
  }

  Future<SlotDetail> getSlotDetails(String slotId) async {
    final response = await _client.get('${ApiConstants.slotDetails}/$slotId');
    return SlotDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> markNoShow({
    required String slotId,
    required String customerId,
    required String docId,
  }) async {
    await _client.put(
      '${ApiConstants.teeSheetNoShow}/$slotId/$customerId/$docId',
    );
  }

  Future<void> updateSlotCustomers({
    required String slotId,
    required List<Map<String, dynamic>> customers,
    // The backend's updateSlot controller destructures `startingSlot` out of
    // the body separately from the generic `...updateData` spread and writes
    // it back onto every touched slot doc — omitting it would null it out.
    required String startingSlot,
    required String date,
    required int persons,
    String? golfCourseId,
    String? teeSheetId,
    String? cartOne,
    String? cartTwo,
    String? notes,
    int? holes,
    int? carts,
    bool? split,
  }) async {
    final data = <String, dynamic>{
      'customers': customers,
      'startingSlot': startingSlot,
      'date': date,
      'persons': persons,
    };
    if (golfCourseId != null && golfCourseId.isNotEmpty) data['golfCourseId'] = golfCourseId;
    if (teeSheetId != null && teeSheetId.isNotEmpty) data['teeSheetId'] = teeSheetId;
    if (cartOne != null && cartOne.isNotEmpty) data['cartOne'] = cartOne;
    if (cartTwo != null && cartTwo.isNotEmpty) data['cartTwo'] = cartTwo;
    if (notes != null) data['notes'] = notes;
    if (holes != null) data['holes'] = holes;
    if (carts != null) data['carts'] = carts;
    if (split != null) data['split'] = split;
    await _client.put('${ApiConstants.updateBooking}/$slotId', data: data);
  }
}
