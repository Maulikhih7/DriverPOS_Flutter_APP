import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../repositories/transaction_repository.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  List<TransactionModel> _transactions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(transactionRepositoryProvider)
          .getTransactions(search: search);
      setState(() => _transactions = list);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showDetail(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TransactionDetailSheet(
        transaction: tx,
        onVoid: () async {
          Navigator.pop(context);
          await _doVoid(tx);
        },
        onRefund: () async {
          Navigator.pop(context);
          await _doIssueRefund(tx);
        },
      ),
    );
  }

  Future<void> _doVoid(TransactionModel tx) async {
    try {
      await ref.read(transactionRepositoryProvider).voidTransaction(tx.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transaction voided'),
        backgroundColor: AppColors.primary,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _doIssueRefund(TransactionModel tx) async {
    try {
      await ref
          .read(transactionRepositoryProvider)
          .issueRefundFromTransaction(tx.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Refund issued'),
        backgroundColor: AppColors.primary,
      ));
      _load();
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
        title: const Text('Transactions'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextFormField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search by receipt # or customer…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _load();
                  },
                )
              : null,
          isDense: true,
        ),
        onChanged: (q) {
          setState(() {});
          if (q.length >= 2 || q.isEmpty) _load(search: q.isNotEmpty ? q : null);
        },
      ),
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
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
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
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('No transactions found',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TransactionTile(
          transaction: _transactions[i],
          onTap: () => _showDetail(_transactions[i]),
        ),
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final dateStr = tx.createdAt != null
        ? DateFormat('MMM d, y • h:mm a').format(tx.createdAt!.toLocal())
        : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _methodColor(tx.paymentType).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_methodIcon(tx.paymentType),
                  color: _methodColor(tx.paymentType), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.customerName?.isNotEmpty == true
                              ? tx.customerName!
                              : 'Guest',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${tx.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (tx.receiptNumber != null) ...[
                        Text('#${tx.receiptNumber}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ),
                      _StatusChip(status: tx.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Color _methodColor(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return AppColors.primary;
      case 'credit':
      case 'debit':
        return AppColors.info;
      case 'giftcard':
      case 'gift card':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _methodIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'credit':
      case 'debit':
        return Icons.credit_card;
      case 'giftcard':
      case 'gift card':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color get _color {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return AppColors.primary;
      case 'voided':
      case 'void':
        return AppColors.danger;
      case 'refunded':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Transaction detail bottom sheet ──────────────────────────────────────────

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onVoid;
  final VoidCallback onRefund;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.onVoid,
    required this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final dateStr = tx.createdAt != null
        ? DateFormat('MMMM d, y • h:mm a').format(tx.createdAt!.toLocal())
        : '—';
    final isVoided = tx.status.toLowerCase() == 'voided' ||
        tx.status.toLowerCase() == 'void';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Transaction Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                _StatusChip(status: tx.status),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Header info
                _DetailRow('Receipt #',
                    tx.receiptNumber != null ? '#${tx.receiptNumber}' : '—'),
                _DetailRow('Customer',
                    tx.customerName?.isNotEmpty == true
                        ? tx.customerName!
                        : 'Guest'),
                _DetailRow('Payment', tx.paymentType),
                _DetailRow('Date', dateStr),
                const Divider(height: 20),
                // Items
                if (tx.items.isNotEmpty) ...[
                  const Text('Items',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...tx.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.name,
                                  style:
                                      const TextStyle(fontSize: 13)),
                            ),
                            Text('×${item.quantity}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted)),
                            const SizedBox(width: 12),
                            Text(
                                '\$${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  const Divider(height: 20),
                ],
                // Totals
                if (tx.tax > 0)
                  _DetailRow('Tax', '\$${tx.tax.toStringAsFixed(2)}'),
                _DetailRow('Total',
                    '\$${tx.totalAmount.toStringAsFixed(2)}',
                    bold: true),
                const SizedBox(height: 24),
                // Actions
                if (!isVoided) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRefund,
                      icon: const Icon(Icons.replay_outlined, size: 18),
                      label: const Text('Issue Refund'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onVoid,
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Void Transaction'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DetailRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
