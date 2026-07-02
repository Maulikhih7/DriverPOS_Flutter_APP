import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/dashboard_model.dart';
import 'widgets/stat_card.dart';
import 'widgets/dashboard_box.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final date = ref.watch(dashboardDateProvider);
    final fmt = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.golfCourse?.name ?? 'Dashboard',
                style: Theme.of(context).textTheme.titleLarge),
            Text(fmt.format(date),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: AppColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                ref.read(dashboardDateProvider.notifier).state = picked;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              ref.invalidate(salesDataProvider);
              ref.invalidate(departmentSalesProvider);
              ref.invalidate(topSpendersProvider);
              ref.invalidate(lowInventoryProvider);
              ref.invalidate(bookedTeeTimesProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(salesDataProvider);
          ref.invalidate(departmentSalesProvider);
          ref.invalidate(topSpendersProvider);
          ref.invalidate(lowInventoryProvider);
          ref.invalidate(bookedTeeTimesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SalesSummaryRow(),
            const SizedBox(height: 16),
            _SalesChartBox(),
            const SizedBox(height: 16),
            _DepartmentChartBox(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _TopSpendersBox()),
                const SizedBox(width: 12),
                Expanded(child: _BookedTeeTimesBox()),
              ],
            ),
            const SizedBox(height: 16),
            _LowInventoryBox(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Sales summary row ─────────────────────────────────────────────────────────

class _SalesSummaryRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesDataProvider);
    final bookedAsync = ref.watch(bookedTeeTimesProvider);

    final totalSales = salesAsync.value?.fold<double>(
      0, (sum, d) => sum + d.amount) ?? 0.0;
    final totalTeeTimes = bookedAsync.value?.length ?? 0;
    final currFmt = NumberFormat.currency(symbol: '\$');
    final deptCount = (ref.watch(departmentSalesProvider).value?.length ?? 0).toDouble();
    final lowCount  = (ref.watch(lowInventoryProvider).value?.length ?? 0).toDouble();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: [
        StatCard(
          title: "Today's Sales",
          value: currFmt.format(totalSales),
          icon: Icons.attach_money,
          iconColor: AppColors.primary,
          bgColor: AppColors.primaryLight,
          animatedEnd: totalSales,
          formatter: (v) => currFmt.format(v),
        ),
        StatCard(
          title: 'Booked Tee Times',
          value: totalTeeTimes.toString(),
          icon: Icons.golf_course,
          iconColor: AppColors.info,
          bgColor: AppColors.infoMuted,
          animatedEnd: totalTeeTimes.toDouble(),
          formatter: (v) => v.toStringAsFixed(0),
        ),
        StatCard(
          title: 'Departments',
          value: deptCount.toStringAsFixed(0),
          icon: Icons.category_outlined,
          iconColor: const Color(0xFFF1AE24),
          bgColor: const Color(0xFFFFF8E1),
          animatedEnd: deptCount,
          formatter: (v) => v.toStringAsFixed(0),
        ),
        StatCard(
          title: 'Low Stock',
          value: lowCount.toStringAsFixed(0),
          icon: Icons.warning_amber_outlined,
          iconColor: AppColors.danger,
          bgColor: const Color(0xFFFFEBEE),
          animatedEnd: lowCount,
          formatter: (v) => v.toStringAsFixed(0),
        ),
      ],
    );
  }
}

// ── Sales bar chart ───────────────────────────────────────────────────────────

class _SalesChartBox extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesDataProvider);

    return DashboardBox(
      title: 'Sales Report',
      height: 220,
      child: salesAsync.when(
        loading: () => const DashboardBoxLoading(),
        error: (e, _) => DashboardBoxEmpty(message: 'Failed to load sales'),
        data: (data) {
          if (data.isEmpty) return const DashboardBoxEmpty(message: 'No sales today');
          return _buildBarChart(context, data);
        },
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<SalesDataPoint> data) {
    final maxY = data.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final groups = data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.amount,
            color: AppColors.primary,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (v, _) => Text(
                  '\$${v.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label.length > 8 ? '${data[i].label.substring(0, 8)}..' : data[i].label,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '\$${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Department pie chart ──────────────────────────────────────────────────────

class _DepartmentChartBox extends ConsumerWidget {
  static const _colors = [
    AppColors.primary, AppColors.info, Color(0xFFF1AE24),
    Color(0xFF9B59B6), Color(0xFFE74C3C), Color(0xFF1ABC9C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptAsync = ref.watch(departmentSalesProvider);

    return DashboardBox(
      title: 'Department Sales',
      height: 260,
      child: deptAsync.when(
        loading: () => const DashboardBoxLoading(),
        error: (_, __) => const DashboardBoxEmpty(message: 'Failed to load departments'),
        data: (data) {
          if (data.isEmpty) return const DashboardBoxEmpty(message: 'No department data');
          return _buildPieChart(context, data);
        },
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, List<SalesDataPoint> data) {
    final total = data.fold<double>(0, (s, d) => s + d.amount);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: data.asMap().entries.map((e) {
                  final pct = total > 0 ? (e.value.amount / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: e.value.amount,
                    color: _colors[e.key % _colors.length],
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                    radius: 75,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _colors[e.key % _colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.value.label.length > 12
                        ? '${e.value.label.substring(0, 12)}..'
                        : e.value.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Top Spenders ──────────────────────────────────────────────────────────────

class _TopSpendersBox extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topSpendersProvider);
    return DashboardBox(
      title: 'Top Spenders',
      height: 250,
      child: async.when(
        loading: () => const DashboardBoxLoading(),
        error: (_, __) => const DashboardBoxEmpty(message: 'No data'),
        data: (data) {
          if (data.isEmpty) return const DashboardBoxEmpty(message: 'No spenders yet');
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length > 5 ? 5 : data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = data[i];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  radius: 18,
                  child: Text(
                    s.customerName.isNotEmpty ? s.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(s.customerName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                trailing: Text(
                  '\$${s.totalSpent.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Booked Tee Times ──────────────────────────────────────────────────────────

class _BookedTeeTimesBox extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookedTeeTimesProvider);
    return DashboardBox(
      title: 'Booked Tee Times',
      height: 250,
      child: async.when(
        loading: () => const DashboardBoxLoading(),
        error: (_, __) => const DashboardBoxEmpty(message: 'No data'),
        data: (data) {
          if (data.isEmpty) return const DashboardBoxEmpty(message: 'No bookings today');
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length > 6 ? 6 : data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = data[i];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(b.time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                title: Text(b.customerName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                trailing: Text('${b.holes}H', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Low Inventory ─────────────────────────────────────────────────────────────

class _LowInventoryBox extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lowInventoryProvider);
    return DashboardBox(
      title: 'Low Inventory',
      height: 200,
      child: async.when(
        loading: () => const DashboardBoxLoading(),
        error: (_, __) => const DashboardBoxEmpty(message: 'No data'),
        data: (data) {
          if (data.isEmpty) return const DashboardBoxEmpty(message: 'All inventory levels OK');
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final item = data[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.name, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.stock} left',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
