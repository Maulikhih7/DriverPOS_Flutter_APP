import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_model.dart';

final dashboardDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final salesDataProvider = FutureProvider.autoDispose<List<SalesDataPoint>>((ref) async {
  return const [
    SalesDataPoint(label: 'Green Fees', amount: 2450.00),
    SalesDataPoint(label: 'Cart Rentals', amount: 890.00),
    SalesDataPoint(label: 'Pro Shop', amount: 1230.00),
    SalesDataPoint(label: 'Food & Bev', amount: 675.00),
    SalesDataPoint(label: 'Lessons', amount: 320.00),
  ];
});

final departmentSalesProvider = FutureProvider.autoDispose<List<SalesDataPoint>>((ref) async {
  return const [
    SalesDataPoint(label: 'Green Fees', amount: 2450.00),
    SalesDataPoint(label: 'Cart Rentals', amount: 890.00),
    SalesDataPoint(label: 'Pro Shop', amount: 1230.00),
    SalesDataPoint(label: 'Food & Bev', amount: 675.00),
    SalesDataPoint(label: 'Lessons', amount: 320.00),
  ];
});

final topSpendersProvider = FutureProvider.autoDispose<List<TopSpender>>((ref) async {
  return const [
    TopSpender(customerId: 'c1', customerName: 'Alice Johnson', totalSpent: 520.00),
    TopSpender(customerId: 'c2', customerName: 'Bob Williams', totalSpent: 345.00),
    TopSpender(customerId: 'c3', customerName: 'Carol Davis', totalSpent: 289.00),
    TopSpender(customerId: 'c4', customerName: 'David Brown', totalSpent: 175.00),
    TopSpender(customerId: 'c5', customerName: 'Emma Wilson', totalSpent: 140.00),
  ];
});

final lowInventoryProvider = FutureProvider.autoDispose<List<LowInventoryItem>>((ref) async {
  return const [
    LowInventoryItem(name: 'Titleist Pro V1 (12pk)', stock: 3, threshold: 10),
    LowInventoryItem(name: 'Golf Glove - Medium', stock: 5, threshold: 10),
    LowInventoryItem(name: 'Tee Pack (100ct)', stock: 7, threshold: 15),
  ];
});

final bookedTeeTimesProvider = FutureProvider.autoDispose<List<BookedTeeTime>>((ref) async {
  return const [
    BookedTeeTime(time: '7:00 AM', customerName: 'Alice Johnson', holes: 18, status: 'Booked'),
    BookedTeeTime(time: '7:12 AM', customerName: 'Bob Williams', holes: 18, status: 'Booked'),
    BookedTeeTime(time: '7:24 AM', customerName: 'Carol Davis', holes: 9, status: 'Booked'),
    BookedTeeTime(time: '8:00 AM', customerName: 'David Brown', holes: 18, status: 'Booked'),
    BookedTeeTime(time: '8:30 AM', customerName: 'Emma Wilson', holes: 18, status: 'Booked'),
    BookedTeeTime(time: '9:00 AM', customerName: 'Frank Miller', holes: 9, status: 'Booked'),
  ];
});
