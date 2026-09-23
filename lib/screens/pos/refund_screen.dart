import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/default_route.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/pos_repository.dart';
import '../../repositories/transaction_repository.dart';

class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

enum _RefundStep { search, review, payment, success }

class _RefundScreenState extends ConsumerState<RefundScreen> {
  _RefundStep _step = _RefundStep.search;

  // Search
  final _searchCtrl = TextEditingController();
  List<TransactionModel> _results = [];
  bool _searching = false;
  String? _searchError;

  // Selected transaction
  TransactionModel? _selected;

  // Server-side return cart
  Map<String, dynamic>? _returnCart;
  bool _loadingCart = false;

  // Payment
  String _refundMethod = 'Original';
  final _pinCtrl = TextEditingController();
  bool _processing = false;
  String? _payError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final list = await ref
          .read(transactionRepositoryProvider)
          .getTransactions(search: q.trim());
      setState(() => _results = list);
    } catch (e) {
      setState(
          () => _searchError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _selectTransaction(TransactionModel tx) async {
    setState(() {
      _selected = tx;
      _loadingCart = true;
      _step = _RefundStep.review;
    });

    try {
      // Stage the Return cart server-side from this order's line items
      await ref
          .read(transactionRepositoryProvider)
          .issueRefundFromTransaction(tx.id);

      // Fetch the return cart
      final cart = await ref
          .read(posRepositoryProvider)
          .getViewSales(cartState: 'Return');
      setState(() => _returnCart = cart);
    } catch (e) {
      // Non-fatal: show what we have from the transaction itself
    } finally {
      setState(() => _loadingCart = false);
    }
  }

  Future<void> _processRefund() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _payError = 'Employee PIN is required');
      return;
    }
    final tx = _selected!;
    setState(() {
      _processing = true;
      _payError = null;
    });

    try {
      final customerId = _returnCart?['data']?['customerDetails']?['_id'] as String? ?? '';
      final amount = ((_returnCart?['data']?['totalCartAmount'] as num?)
              ?.toDouble()) ??
          tx.totalAmount;

      await ref.read(transactionRepositoryProvider).refundOrder(
            pinNumber: pin,
            amount: amount,
            customerId: customerId.isNotEmpty ? customerId : tx.id,
            refundMethod: _refundMethod,
          );
      setState(() => _step = _RefundStep.success);
    } catch (e) {
      setState(
          () => _payError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _processing = false);
    }
  }

  Widget _buildBody() {
    switch (_step) {
      case _RefundStep.search:
        return _buildSearch();
      case _RefundStep.review:
        return _buildReview();
      case _RefundStep.payment:
        return _buildPayment();
      case _RefundStep.success:
        return _buildSuccess();
    }
  }

  // ── Step 1: Search ───────────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by order ID or customer name…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (q) {
              setState(() {});
              _search(q);
            },
          ),
        ),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_searchError != null) {
      return Center(
        child: Text(_searchError!,
            style: const TextStyle(color: AppColors.danger)),
      );
    }
    if (_results.isEmpty && _searchCtrl.text.isNotEmpty) {
      return const Center(
        child: Text('No transactions found',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('Search for a transaction to refund',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final tx = _results[i];
        return GestureDetector(
          onTap: () => _selectTransaction(tx),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.customerName?.isNotEmpty == true
                            ? tx.customerName!
                            : 'Guest',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.receiptNumber != null ? '#${tx.receiptNumber}' : tx.id,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${tx.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 2: Review ───────────────────────────────────────────────────────────

  Widget _buildReview() {
    final tx = _selected!;
    if (_loadingCart) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final cartData = _returnCart?['data'] as Map<String, dynamic>?;
    final cartItems =
        (cartData?['products']?['items'] as List?) ?? [];
    final cartTotal =
        (cartData?['totalCartAmount'] as num?)?.toDouble() ?? tx.totalAmount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Transaction',
          child: Column(
            children: [
              _InfoRow('Receipt',
                  tx.receiptNumber != null ? '#${tx.receiptNumber}' : '—'),
              _InfoRow(
                'Customer',
                tx.customerName?.isNotEmpty == true
                    ? tx.customerName!
                    : 'Guest',
              ),
              _InfoRow('Payment', tx.paymentType),
              _InfoRow('Total', '\$${cartTotal.toStringAsFixed(2)}',
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (cartItems.isNotEmpty)
          _SectionCard(
            title: 'Items',
            child: Column(
              children: cartItems.map<Widget>((item) {
                final name = item['name'] as String? ?? '';
                final qty = item['quantity'] as int? ?? 1;
                final lineTotal =
                    (item['lineTotal'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(fontSize: 13))),
                      Text('×$qty',
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13)),
                      const SizedBox(width: 12),
                      Text('\$${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        else if (tx.items.isNotEmpty)
          _SectionCard(
            title: 'Items',
            child: Column(
              children: tx.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(item.name,
                                    style:
                                        const TextStyle(fontSize: 13))),
                            Text('×${item.quantity}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                            const SizedBox(width: 12),
                            Text(
                                '\$${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Step 3: Payment ──────────────────────────────────────────────────────────

  Widget _buildPayment() {
    final tx = _selected!;
    final cartData = _returnCart?['data'] as Map<String, dynamic>?;
    final refundAmount =
        (cartData?['totalCartAmount'] as num?)?.toDouble() ?? tx.totalAmount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Refund Amount',
          child: Center(
            child: Text(
              '\$${refundAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Refund Method',
          child: Column(
            children: ['Original', 'StoreCredit'].map((method) {
              final selected = _refundMethod == method;
              return GestureDetector(
                onTap: () => setState(() => _refundMethod = method),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryLight
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        method == 'Original'
                            ? 'Original Payment Method'
                            : 'Store Credit',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Employee PIN',
          child: TextFormField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Enter PIN',
              prefixIcon: Icon(Icons.lock_outline, size: 18),
              isDense: true,
            ),
          ),
        ),
        if (_payError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_payError!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Step 4: Success ──────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Refund Processed',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'The refund has been successfully processed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    context.go(defaultRouteForUser(ref.read(authProvider).user)),
                child: const Text('Back to POS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom button ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _RefundStep.search ||
                _step == _RefundStep.success) {
              context.pop();
            } else if (_step == _RefundStep.payment) {
              setState(() => _step = _RefundStep.review);
            } else {
              setState(() {
                _step = _RefundStep.search;
                _selected = null;
                _returnCart = null;
              });
            }
          },
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  String get _appBarTitle {
    switch (_step) {
      case _RefundStep.search:
        return 'Refund — Search';
      case _RefundStep.review:
        return 'Refund — Review';
      case _RefundStep.payment:
        return 'Refund — Confirm';
      case _RefundStep.success:
        return 'Refund — Done';
    }
  }

  Widget? _buildBottomBar() {
    if (_step == _RefundStep.search || _step == _RefundStep.success) {
      return null;
    }

    final isPayment = _step == _RefundStep.payment;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (_loadingCart || _processing)
                ? null
                : () {
                    if (_step == _RefundStep.review) {
                      setState(() => _step = _RefundStep.payment);
                    } else {
                      _processRefund();
                    }
                  },
            icon: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Icon(isPayment
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward),
            label: Text(
              _processing
                  ? 'Processing…'
                  : isPayment
                      ? 'Process Refund'
                      : 'Continue',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _InfoRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: bold ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}
