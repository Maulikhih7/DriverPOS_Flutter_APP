import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(apiClientProvider));
});

class DashboardRepository {
  final ApiClient _client;

  DashboardRepository(this._client);

  Future<List<SalesDataPoint>> getSalesData({
    required String startDate,
    required String endDate,
    String? golfCourse,
  }) async {
    final response = await _client.get(
      ApiConstants.salesReport,
      queryParams: {
        'startDate': startDate,
        'endDate': endDate,
        if (golfCourse != null && golfCourse.isNotEmpty) 'golfCourse': golfCourse,
      },
    );
    final list = response['data'] as List? ?? [];
    return list.map((d) => SalesDataPoint.fromJson(d)).toList();
  }

  Future<List<TopSpender>> getTopSpenders({
    required String date,
    String? golfCourse,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.customerReport,
        queryParams: {
          'startDate': date,
          'endDate': date,
          if (golfCourse != null && golfCourse.isNotEmpty) 'golfCourse': golfCourse,
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((d) => TopSpender.fromJson(d)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<LowInventoryItem>> getLowInventory() async {
    try {
      final response = await _client.get(ApiConstants.lowInventoryReport);
      final list = response['data'] as List? ?? [];
      return list.map((d) => LowInventoryItem.fromJson(d)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BookedTeeTime>> getBookedTeeTimes({
    required String date,
    String? golfCourse,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.teeSheetReport,
        queryParams: {
          'startDate': date,
          'endDate': date,
          if (golfCourse != null && golfCourse.isNotEmpty) 'golfCourse': golfCourse,
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((d) => BookedTeeTime.fromJson(d)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SalesDataPoint>> getDepartmentSales({
    required String startDate,
    required String endDate,
    String? golfCourse,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.departmentReport,
        queryParams: {
          'startDate': startDate,
          'endDate': endDate,
          if (golfCourse != null && golfCourse.isNotEmpty) 'golfCourse': golfCourse,
        },
      );
      final list = response['data'] as List? ?? [];
      return list.map((d) => SalesDataPoint.fromJson(d)).toList();
    } catch (_) {
      return [];
    }
  }
}
