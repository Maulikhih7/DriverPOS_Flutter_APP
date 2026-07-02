import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/customer_model.dart';
import '../../../providers/pos_provider.dart';
import '../../../repositories/customer_repository.dart';
import '../../../widgets/interactive_confirm.dart';

class CartSection extends ConsumerWidget {
  const CartSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _CartHeader(cart: cart),
          Expanded(child: _CartItemsList(cart: cart)),
          if (cart.items.isNotEmpty) _CartTotals(cart: cart),
          _CartActions(cart: cart),
        ],
      ),
    );
  }
}

class _CartHeader extends ConsumerWidget {
  final CartState cart;
  const _CartHeader({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        border: Border(bottom: BorderSide(color: Color(0xFFE8E0C8))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text('ORDER DETAILS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11,
                      letterSpacing: 1.2, color: AppColors.textMuted)),
              const Spacer(),
              if (cart.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _CustomerSelector(customer: cart.customer),
        ],
      ),
    );
  }
}

class _CustomerSelector extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  const _CustomerSelector({required this.customer});

  @override
  ConsumerState<_CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends ConsumerState<_CustomerSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.customer != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.customer!.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.customer!.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (widget.customer!.email != null)
                        Text(widget.customer!.email!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSearch(context),
                  child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () => _showSearch(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_search_outlined, size: 18, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text('Select Customer', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CustomerSearchSheet(
        onSelected: (c) {
          ref.read(cartProvider.notifier).setCustomer(c);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _CustomerSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<CustomerModel> onSelected;
  const _CustomerSearchSheet({required this.onSelected});

  @override
  ConsumerState<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends ConsumerState<_CustomerSearchSheet> {
  final _ctrl = TextEditingController();
  List<CustomerModel> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(customerRepositoryProvider).getCustomers(
        search: q.isNotEmpty ? q : null,
        limit: 15,
      );
      setState(() => _results = results);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextFormField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) => _search(q),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final c = _results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text(c.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c.fullName),
                        subtitle: c.email != null ? Text(c.email!) : null,
                        onTap: () => widget.onSelected(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartItemsList extends ConsumerWidget {
  final CartState cart;
  const _CartItemsList({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.border.withOpacity(0.6)),
            const SizedBox(height: 8),
            const Text('No items yet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Tap a product to add', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const _DashedDivider(),
      itemBuilder: (_, i) {
        final item = cart.items[i];
        return Dismissible(
          key: ValueKey('${item.item.id}_$i'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            HapticFeedback.mediumImpact();
            ref.read(cartProvider.notifier).removeProduct(i);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                const SizedBox(height: 2),
                const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Item number badge
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('\$${item.discountPrice.toStringAsFixed(2)} ea',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).updateQuantity(i, item.totalQuantity - 1);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('${item.totalQuantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                              color: AppColors.primary)),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).updateQuantity(i, item.totalQuantity + 1);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Text('\$${(item.discountPrice * item.totalQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dashed receipt-style divider
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 10,
        child: CustomPaint(painter: _DashedDividerPainter()),
      );
}

class _DashedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8D0B8)
      ..strokeWidth = 1;
    const dashW = 5.0;
    const gapW = 4.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(_DashedDividerPainter _) => false;
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  final CartState cart;
  const _CartTotals({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        border: Border(top: BorderSide(color: Color(0xFFE8E0C8))),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: '\$${cart.subtotal.toStringAsFixed(2)}'),
          if (cart.addonSubtotal > 0)
            _TotalRow(label: 'Addons', value: '\$${cart.addonSubtotal.toStringAsFixed(2)}'),
          _TotalRow(label: 'Tax', value: '\$${(cart.totalTax + cart.addonTax).toStringAsFixed(2)}'),
          const _DashedDivider(),
          _TotalRow(
            label: 'TOTAL',
            value: '\$${cart.total.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)
        : const TextStyle(fontSize: 13, color: AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style.copyWith(color: bold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

class _CartActions extends ConsumerWidget {
  final CartState cart;
  const _CartActions({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // Secondary row: Hold Orders + Refund
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/hold-orders'),
                  icon: const Icon(Icons.pause_circle_outline, size: 15),
                  label: const Text('Orders'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/refund'),
                  icon: const Icon(Icons.replay_outlined, size: 15),
                  label: const Text('Refund'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (cart.items.isEmpty || cart.isCheckingOut)
                    ? null
                    : () => ref.read(cartProvider.notifier).holdCart(),
                icon: const Icon(Icons.pause_outlined, size: 15),
                label: const Text('Hold'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Slide-to-checkout
          SwipeToConfirm(
            label: cart.items.isEmpty
                ? 'Add items to checkout'
                : 'Slide to Checkout  \$${cart.total.toStringAsFixed(2)}',
            color: AppColors.primary,
            loading: cart.isCheckingOut,
            enabled: cart.items.isNotEmpty && !cart.isCheckingOut,
            height: 52,
            onConfirmed: (cart.items.isEmpty || cart.isCheckingOut)
                ? null
                : () => _checkout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    if (cartState.customer == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a customer before checking out'),
          backgroundColor: AppColors.warning,
        ));
      return;
    }

    // Push products to the server cart; result contains the server-side sale doc
    final result = await ref.read(cartProvider.notifier).checkout();
    if (!context.mounted) return;

    if (result != null) {
      // Prefer server-side totals when available
      final serverData = result['data'] as Map<String, dynamic>?;
      final serverTotal = (serverData?['totalCartAmount'] as num?)?.toDouble();
      final serverTax   = (serverData?['totalTaxAmount'] as num?)?.toDouble();
      final serverDiscount = (serverData?['totalDiscountAmount'] as num?)?.toDouble();

      context.push('/checkout', extra: {
        'total':        serverTotal ?? cartState.total,
        'subtotal':     cartState.subtotal,
        'tax':          serverTax ?? (cartState.totalTax + cartState.addonTax),
        'discountAmount': serverDiscount ?? 0.0,
        'customerId':   cartState.customer!.id,
        'customerName': cartState.customer!.fullName,
      });
    } else if (cartState.error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(cartState.error!),
          backgroundColor: AppColors.danger,
        ));
    }
  }
}
