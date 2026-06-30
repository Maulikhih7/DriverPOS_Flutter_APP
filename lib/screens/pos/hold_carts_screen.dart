import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/pos_provider.dart';
import '../../repositories/pos_repository.dart';

class HoldCartsScreen extends ConsumerStatefulWidget {
  const HoldCartsScreen({super.key});

  @override
  ConsumerState<HoldCartsScreen> createState() => _HoldCartsScreenState();
}

class _HoldCartsScreenState extends ConsumerState<HoldCartsScreen> {
  List<Map<String, dynamic>> _carts = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(posRepositoryProvider).getHoldCarts();
      setState(() => _carts = list);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resume(Map<String, dynamic> cart) async {
    final saleId = cart['_id'] as String? ?? cart['saleId'] as String? ?? '';
    if (saleId.isEmpty) return;

    try {
      await ref.read(posRepositoryProvider).sendToState(saleId, 'Sale');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cart resumed as active sale'),
        backgroundColor: AppColors.primary,
      ));
      // Invalidate providers so the POS screen picks up the restored cart
      ref.invalidate(holdCartsProvider);
      ref.invalidate(viewSalesProvider);
      context.go('/pos');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _delete(Map<String, dynamic> cart, int index) async {
    final saleId = cart['_id'] as String? ?? cart['saleId'] as String? ?? '';
    if (saleId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hold Cart'),
        content: const Text(
            'Are you sure you want to delete this hold cart? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(posRepositoryProvider).removeHoldCart(saleId);
      setState(() => _carts.removeAt(index));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hold cart deleted'),
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Hold Orders'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 48),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_carts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_outline,
                size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text('No hold orders',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const Text(
              'Hold a cart from the POS screen\nto see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _carts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _HoldCartCard(
          cart: _carts[i],
          onResume: () => _resume(_carts[i]),
          onDelete: () => _delete(_carts[i], i),
        ),
      ),
    );
  }
}

// ── Hold cart card ────────────────────────────────────────────────────────────

class _HoldCartCard extends StatelessWidget {
  final Map<String, dynamic> cart;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _HoldCartCard({
    required this.cart,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final saleId = cart['saleId'] as String? ?? '—';
    final customerDetails =
        cart['customerDetails'] as Map<String, dynamic>?;
    final customerName = customerDetails?['fullName'] as String? ??
        '${customerDetails?['firstName'] ?? ''} ${customerDetails?['lastName'] ?? ''}'
            .trim();
    final total =
        (cart['totalCartAmount'] as num?)?.toDouble() ?? 0.0;
    final itemCount =
        (cart['products']?['items'] as List?)?.length ?? 0;
    final createdAt = cart['createdAt'] as String?;

    String dateStr = '—';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final local = dt.toLocal();
        dateStr =
            '${local.month}/${local.day}/${local.year}  ${_fmtTime(local)}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  saleId,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning),
                ),
              ),
              const Spacer(),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                customerName.isNotEmpty ? customerName : 'No customer',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(width: 16),
              const Icon(Icons.access_time,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.danger),
                  label: const Text('Delete',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(0, 40),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
