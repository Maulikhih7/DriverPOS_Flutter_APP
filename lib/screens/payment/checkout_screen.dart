import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/default_route.dart';
import '../../core/theme/app_theme.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/payment_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double total;
  final double subtotal;
  final double tax;
  final String customerId;
  final String customerName;
  final double? discountAmount;

  const CheckoutScreen({
    super.key,
    required this.total,
    required this.subtotal,
    required this.tax,
    required this.customerId,
    required this.customerName,
    this.discountAmount,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _PayMethod { cash, card, check, giftCard, split }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  _PayMethod _method = _PayMethod.cash;
  bool _processing = false;
  String? _error;
  bool _showSuccess = false;
  String _successMessage = '';

  final _pinCtrl = TextEditingController();
  final _tenderedCtrl = TextEditingController();
  final _gcManualCtrl = TextEditingController();   // manual gift card entry
  final _splitCashCtrl = TextEditingController();
  final _splitCardCtrl = TextEditingController();

  String? _savedTPN;
  bool _loadingTPN = true;

  // Customer gift cards (loaded from GET /customer/:id)
  List<CustomerGiftCard> _customerGiftCards = [];
  bool _loadingCustomerCards = false;

  // Staged gift cards to apply at checkout
  final List<Map<String, dynamic>> _appliedGiftCards = [];

  double get _tendered => double.tryParse(_tenderedCtrl.text) ?? 0.0;
  double get _change => (_tendered - widget.total).clamp(0.0, double.infinity);

  double get _gcAppliedTotal =>
      _appliedGiftCards.fold(0.0, (s, c) => s + ((c['giftCardAmount'] as num).toDouble()));
  double get _gcRemaining => (widget.total - _gcAppliedTotal).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _tenderedCtrl.text = widget.total.toStringAsFixed(2);
    _splitCashCtrl.text = widget.total.toStringAsFixed(2);
    _splitCardCtrl.text = '0.00';
    _loadTPN();
  }

  Future<void> _loadTPN() async {
    final tpn = await ref.read(mappedTpnProvider.future);
    if (mounted) setState(() { _savedTPN = tpn; _loadingTPN = false; });
  }

  Future<void> _loadCustomerGiftCards() async {
    if (_loadingCustomerCards || widget.customerId.isEmpty) return;
    setState(() => _loadingCustomerCards = true);
    try {
      final customer = await ref.read(customerRepositoryProvider).getCustomerById(widget.customerId);
      if (mounted) setState(() => _customerGiftCards = customer.giftCards);
    } catch (_) {
      // non-fatal — manual entry still works
    } finally {
      if (mounted) setState(() => _loadingCustomerCards = false);
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _tenderedCtrl.dispose();
    _gcManualCtrl.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────────

  String? _validate() {
    if (_pinCtrl.text.trim().isEmpty) return 'Employee PIN is required';
    switch (_method) {
      case _PayMethod.cash:
        if (_tendered < widget.total) return 'Tendered must be ≥ \$${widget.total.toStringAsFixed(2)}';
      case _PayMethod.card:
        if (_savedTPN == null) return 'No terminal registered. Go to Terminal Setup first.';
      case _PayMethod.giftCard:
        if (_appliedGiftCards.isEmpty && _gcManualCtrl.text.trim().isEmpty) {
          return 'Apply at least one gift card or enter a card number';
        }
      case _PayMethod.split:
        final cash = double.tryParse(_splitCashCtrl.text) ?? 0;
        final card = double.tryParse(_splitCardCtrl.text) ?? 0;
        if ((cash + card - widget.total).abs() > 0.02) {
          return 'Cash + Card must equal \$${widget.total.toStringAsFixed(2)}';
        }
        if (card > 0 && _savedTPN == null) {
          return 'No terminal registered for card portion.';
        }
      case _PayMethod.check:
        break;
    }
    return null;
  }

  // ── Payment execution ────────────────────────────────────────────────────────

  Future<void> _processPayment() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }

    setState(() { _error = null; _processing = true; });
    try {
      switch (_method) {
        case _PayMethod.cash:   await _doCash();    break;
        case _PayMethod.card:   await _doCard();    break;
        case _PayMethod.check:  await _doCheck();   break;
        case _PayMethod.giftCard: await _doGiftCard(); break;
        case _PayMethod.split:  await _doSplit();   break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _doCash() async {
    await ref.read(transactionRepositoryProvider).checkout(
      pinNumber: _pinCtrl.text.trim(),
      paymentType: 'Cash',
      amount: widget.total,
      totalAmount: widget.total,
      totalDiscountAmount: widget.discountAmount ?? 0,
      changeGiven: _change > 0 ? _change : null,
      customerId: widget.customerId,
    );
    _onSuccess('Cash payment recorded');
  }

  Future<void> _doCheck() async {
    await ref.read(transactionRepositoryProvider).checkout(
      pinNumber: _pinCtrl.text.trim(),
      paymentType: 'Check',
      amount: widget.total,
      totalAmount: widget.total,
      totalDiscountAmount: widget.discountAmount ?? 0,
      customerId: widget.customerId,
    );
    _onSuccess('Check payment recorded');
  }

  Future<void> _doCard() async {
    // Step 1 — create a pending P-18 transaction on the backend. No charge
    // has happened yet, so a failure here is a plain, retryable error.
    Map<String, dynamic> pending;
    try {
      pending = await ref.read(transactionRepositoryProvider).checkout(
        pinNumber: _pinCtrl.text.trim(),
        paymentType: 'Credit',
        amount: widget.total,
        totalAmount: widget.total,
        totalDiscountAmount: widget.discountAmount ?? 0,
        customerId: widget.customerId,
        p18Device: true,
      );
    } catch (e) {
      setState(() {
        _processing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
    final referenceId = pending['referenceId'] as String?;
    if (referenceId == null || referenceId.isEmpty) {
      setState(() { _processing = false; _error = 'Backend did not return a P-18 reference ID.'; });
      return;
    }

    // Step 2 — launch DVPayLite for the actual card charge, tagged with the
    // backend's referenceId so the two records match up.
    PaymentResult result;
    try {
      result = await PaymentService.performSale(
        tpn: _savedTPN!,
        amount: widget.total,
        paymentType: 'CREDIT',
        refId: referenceId,
      );
    } on PaymentException catch (e) {
      setState(() { _processing = false; _error = e.message; });
      return;
    }

    if (!result.approved) {
      setState(() {
        _processing = false;
        _error = result.responseMessage.isNotEmpty
            ? 'Card declined: ${result.responseMessage}'
            : 'Card declined. Please try again.';
      });
      return;
    }

    // Step 3 — verify with the backend. The card is already charged at this
    // point — a failure here must never be shown as a plain decline, or the
    // cashier may recharge a paid card.
    try {
      await ref.read(transactionRepositoryProvider).verifyP18Transaction(referenceId);
    } catch (e) {
      setState(() {
        _processing = false;
        _error = 'Card was charged (Auth: ${result.authCode}) but the sale failed to verify. '
            'Do NOT recharge — note this auth code and contact support to reconcile.';
      });
      return;
    }
    _onSuccess('Card payment approved  •  Auth: ${result.authCode}');
  }

  // Stage a customer-owned gift card (balance already known)
  void _stageCustomerCard(CustomerGiftCard card) {
    final already = _appliedGiftCards.any((c) => c['giftCardNumber'] == card.number);
    if (already) return;
    final toApply = card.amount > _gcRemaining ? _gcRemaining : card.amount;
    if (toApply <= 0) return;
    setState(() => _appliedGiftCards.add({'giftCardNumber': card.number, 'giftCardAmount': toApply}));
  }

  // Stage a manually-entered card (look up balance via API first)
  Future<void> _stageManualCard() async {
    final cardNumber = _gcManualCtrl.text.trim();
    if (cardNumber.isEmpty) return;
    final already = _appliedGiftCards.any((c) => c['giftCardNumber'] == cardNumber);
    if (already) { setState(() => _error = 'Card already applied'); return; }

    setState(() { _error = null; _processing = true; });
    try {
      final gc = await ref.read(transactionRepositoryProvider).applyGiftCard(cardNumber);
      // Safe cast — JSON numbers may be int or double
      double balance = 0;
      final raw = gc['balance'] ?? gc['amount'];
      if (raw is int) balance = raw.toDouble();
      else if (raw is double) balance = raw;
      else if (raw is String) balance = double.tryParse(raw) ?? 0;

      final toApply = balance > _gcRemaining ? _gcRemaining : balance;
      if (toApply <= 0) {
        setState(() { _processing = false; _error = 'No balance available on this card'; });
        return;
      }
      setState(() {
        _appliedGiftCards.add({'giftCardNumber': cardNumber, 'giftCardAmount': toApply});
        _gcManualCtrl.clear();
        _processing = false;
      });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _doGiftCard() async {
    final staged = List<Map<String, dynamic>>.from(_appliedGiftCards);

    // If manual field still has text, include it (already staged by _stageManualCard)
    // Nothing extra needed — staged list covers everything

    final gcTotal = staged.fold<double>(0, (s, c) => s + (c['giftCardAmount'] as num).toDouble());
    final remaining = (widget.total - gcTotal).clamp(0.0, double.infinity);

    await ref.read(transactionRepositoryProvider).checkout(
      pinNumber: _pinCtrl.text.trim(),
      paymentType: 'Cash',
      amount: remaining,
      totalAmount: widget.total,
      totalDiscountAmount: widget.discountAmount ?? 0,
      customerId: widget.customerId,
      applyGiftCard: true,
      multiGiftCardData: staged,
    );
    _onSuccess('Gift card(s) applied · \$${gcTotal.toStringAsFixed(2)} credited');
  }

  Future<void> _doSplit() async {
    final cash = double.tryParse(_splitCashCtrl.text) ?? 0;
    final card = double.tryParse(_splitCardCtrl.text) ?? 0;
    String? cardAuthRef;

    if (card > 0) {
      // Process card portion via DVPayLite first
      PaymentResult result;
      try {
        result = await PaymentService.performSale(
          tpn: _savedTPN!,
          amount: card,
          paymentType: 'CREDIT',
        );
      } on PaymentException catch (e) {
        setState(() { _processing = false; _error = e.message; });
        return;
      }
      if (!result.approved) {
        setState(() { _processing = false; _error = 'Card declined: ${result.responseMessage}'; });
        return;
      }
      cardAuthRef = result.authCode.isNotEmpty ? result.authCode : result.refId;
    }

    // The card portion (if any) is already charged at this point — a failure
    // here must never be shown as a plain decline, or the cashier may
    // recharge a paid card.
    try {
      await ref.read(transactionRepositoryProvider).checkout(
        pinNumber: _pinCtrl.text.trim(),
        paymentType: 'Credit',
        type: 'Split',
        amount: widget.total,
        totalAmount: widget.total,
        cashAmount: cash,
        cardAmount: card,
        customerId: widget.customerId,
      );
    } catch (e) {
      setState(() {
        _processing = false;
        _error = cardAuthRef != null
            ? 'Card portion was charged (Auth: $cardAuthRef) but the sale failed to save. '
                'Do NOT recharge — note this auth code and contact support to reconcile.'
            : e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
    _onSuccess('Split payment recorded');
  }

  void _setTendered(double amount) {
    setState(() => _tenderedCtrl.text = amount.toStringAsFixed(2));
  }

  void _numpadKey(String key) {
    final current = _tenderedCtrl.text;
    setState(() {
      if (key == '⌫') {
        if (current.length <= 1) {
          _tenderedCtrl.text = '0';
        } else {
          var next = current.substring(0, current.length - 1);
          if (next.endsWith('.')) next = next.substring(0, next.length - 1);
          _tenderedCtrl.text = next;
        }
      } else if (key == '.') {
        if (!current.contains('.')) _tenderedCtrl.text = '$current.';
      } else {
        final parts = current.split('.');
        if (parts.length == 2 && parts[1].length >= 2) return;
        _tenderedCtrl.text = current == '0' ? key : '$current$key';
      }
    });
  }

  void _onSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _successMessage = message;
      _showSuccess = true;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _processing ? null : () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _buildMethodPicker(),
                    const SizedBox(height: 16),
                    _buildMethodDetails(),
                    const SizedBox(height: 16),
                    _buildPinField(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _buildError(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _buildConfirmButton(),
            ],
          ),
          if (_showSuccess) _SuccessOverlay(
            message: _successMessage,
            onComplete: () {
              ref.read(cartProvider.notifier).clearCart();
              if (mounted) {
                context.go(defaultRouteForUser(ref.read(authProvider).user));
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────────

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  widget.customerName.isNotEmpty ? widget.customerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Text('Customer', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _SRow('Subtotal', '\$${widget.subtotal.toStringAsFixed(2)}'),
          if ((widget.discountAmount ?? 0) > 0)
            _SRow('Discount', '-\$${widget.discountAmount!.toStringAsFixed(2)}', green: true),
          if (widget.tax > 0)
            _SRow('Tax', '\$${widget.tax.toStringAsFixed(2)}'),
          const Divider(height: 12),
          _SRow('Total', '\$${widget.total.toStringAsFixed(2)}', bold: true, green: true),
        ],
      ),
    );
  }

  // ── Payment method picker ─────────────────────────────────────────────────────

  Widget _buildMethodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          children: [
            _MethodTile(
              label: 'Cash',
              icon: Icons.payments_outlined,
              selected: _method == _PayMethod.cash,
              onTap: () => setState(() => _method = _PayMethod.cash),
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'Card',
              icon: Icons.contactless_outlined,
              selected: _method == _PayMethod.card,
              onTap: () => setState(() => _method = _PayMethod.card),
              badge: 'DVPayLite',
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'Check',
              icon: Icons.receipt_outlined,
              selected: _method == _PayMethod.check,
              onTap: () => setState(() => _method = _PayMethod.check),
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'Gift Card',
              icon: Icons.card_giftcard_outlined,
              selected: _method == _PayMethod.giftCard,
              onTap: () {
                setState(() => _method = _PayMethod.giftCard);
                _loadCustomerGiftCards();
              },
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'Split',
              icon: Icons.call_split_outlined,
              selected: _method == _PayMethod.split,
              onTap: () => setState(() => _method = _PayMethod.split),
            ),
          ],
        ),
      ],
    );
  }

  // ── Method-specific detail fields ─────────────────────────────────────────────

  Widget _buildMethodDetails() {
    switch (_method) {
      case _PayMethod.cash:
        return _buildCashDetails();
      case _PayMethod.card:
        return _buildCardDetails();
      case _PayMethod.check:
        return _buildCheckDetails();
      case _PayMethod.giftCard:
        return _buildGiftCardDetails();
      case _PayMethod.split:
        return _buildSplitDetails();
    }
  }

  Widget _buildCashDetails() {
    final display = _tenderedCtrl.text.isEmpty ? '0.00' : _tenderedCtrl.text;
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Amount display ───────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const Text('AMOUNT TENDERED', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: AppColors.textMuted,
              )),
              const SizedBox(height: 4),
              Text('\$$display', style: const TextStyle(
                fontSize: 38, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Quick presets ────────────────────────────────────────────────────
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _PresetBtn('Exact', onTap: () => _setTendered(widget.total)),
            for (final amt in [5, 10, 20, 50, 100])
              _PresetBtn('\$$amt', onTap: () => _setTendered(amt.toDouble())),
          ],
        ),
        const SizedBox(height: 14),

        // ── Numpad ───────────────────────────────────────────────────────────
        _CashNumpad(onKey: _numpadKey),
        const SizedBox(height: 14),

        // ── Change due ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _change >= 0 ? AppColors.primaryLight : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Change Due', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(
                '\$${_change.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: _change >= 0 ? AppColors.primary : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _buildCardDetails() {
    if (_loadingTPN) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Card via DVPayLite', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        if (_savedTPN == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: AppColors.danger, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'No terminal registered. Go to Settings → Terminal Setup first.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.push('/terminal-settings');
                _loadTPN();
              },
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Go to Terminal Setup'),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Terminal ready', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('TPN: $_savedTPN', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tapping "Process" will open the DVPayLite app to collect the card payment. Return here after approval.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
    ));
  }

  Widget _buildCheckDetails() {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Check Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Text(
          'Records \$${widget.total.toStringAsFixed(2)} as a check payment. Enter your PIN below and confirm.',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    ));
  }

  Widget _buildGiftCardDetails() {
    final remaining = _gcRemaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Applied summary ───────────────────────────────────────────────
        if (_appliedGiftCards.isNotEmpty) ...[
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Applied Cards',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('\$${_gcAppliedTotal.toStringAsFixed(2)} credited',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ..._appliedGiftCards.asMap().entries.map((e) {
                final amt = (e.value['giftCardAmount'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.value['giftCardNumber'] as String,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text('-\$${amt.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontSize: 13)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _appliedGiftCards.removeAt(e.key)),
                      child: const Icon(Icons.close, size: 16, color: AppColors.danger),
                    ),
                  ]),
                );
              }),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    remaining > 0 ? 'Remaining (charged as Cash)' : 'Fully covered',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    '\$${remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: remaining > 0 ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(height: 12),
        ],

        // ── Customer's gift cards list ─────────────────────────────────────
        _Card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Customer's Gift Cards",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            if (_loadingCustomerCards)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else if (_customerGiftCards.isEmpty)
              const Text('No gift cards on this account',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              ..._customerGiftCards.map((card) {
                final alreadyApplied =
                    _appliedGiftCards.any((c) => c['giftCardNumber'] == card.number);
                final expired = card.expiryDate != null &&
                    DateTime.tryParse(card.expiryDate!)
                            ?.isBefore(DateTime.now()) ==
                        true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alreadyApplied ? AppColors.primaryLight : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: alreadyApplied ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.card_giftcard_outlined,
                        size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.number,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            'Balance: \$${card.amount.toStringAsFixed(2)}'
                            '${card.expiryDate != null ? '  •  Exp: ${card.expiryDate}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: expired ? AppColors.danger : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (alreadyApplied)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                    else if (!expired && card.amount > 0)
                      TextButton(
                        onPressed: remaining <= 0 ? null : () => _stageCustomerCard(card),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    else
                      Text(expired ? 'Expired' : 'Empty',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                  ]),
                );
              }),
          ],
        )),
        const SizedBox(height: 12),

        // ── Manual entry ──────────────────────────────────────────────────
        _Card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a New Gift Card',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _gcManualCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Card number (e.g. 1234 5678 9012 3456)',
                    prefixIcon: Icon(Icons.card_giftcard_outlined, size: 18),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _stageManualCard(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _processing ? null : _stageManualCard,
                style: ElevatedButton.styleFrom(minimumSize: const Size(72, 48)),
                child: _processing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply'),
              ),
            ]),
          ],
        )),
      ],
    );
  }

  Widget _buildSplitDetails() {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Split Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _splitCashCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: const InputDecoration(labelText: 'Cash', prefixText: '\$ ', isDense: true),
            onChanged: (v) {
              final cash = double.tryParse(v) ?? 0;
              setState(() => _splitCardCtrl.text = (widget.total - cash).clamp(0, double.infinity).toStringAsFixed(2));
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _splitCardCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: const InputDecoration(labelText: 'Card (DVPayLite)', prefixText: '\$ ', isDense: true),
            onChanged: (v) {
              final card = double.tryParse(v) ?? 0;
              setState(() => _splitCashCtrl.text = (widget.total - card).clamp(0, double.infinity).toStringAsFixed(2));
            },
          )),
        ]),
        if (_savedTPN == null) ...[
          const SizedBox(height: 8),
          const Text('No terminal registered — card portion will be skipped.', style: TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
      ],
    ));
  }

  // ── PIN field ─────────────────────────────────────────────────────────────────

  Widget _buildPinField() {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Employee PIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        TextFormField(
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
      ],
    ));
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final isCard = _method == _PayMethod.card || _method == _PayMethod.split;
    final label = _processing
        ? (isCard ? 'Waiting for DVPayLite…' : 'Processing…')
        : 'Confirm Payment  ·  \$${widget.total.toStringAsFixed(2)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _processing ? null : _processPayment,
            icon: _processing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 22),
            label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

// ── Payment success overlay ───────────────────────────────────────────────────

class _SuccessOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;
  const _SuccessOverlay({required this.message, required this.onComplete});

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _ringCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _mainCtrl, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _mainCtrl, curve: Curves.easeOut);

    HapticFeedback.heavyImpact();
    _mainCtrl.forward();
    _ringCtrl.repeat();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainCtrl, _ringCtrl]),
      builder: (_, __) => Container(
        color: Colors.black.withOpacity(0.65 * _opacity.value),
        alignment: Alignment.center,
        child: Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing ring + checkmark
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 1.0 + 0.35 * _ringCtrl.value,
                      child: Opacity(
                        opacity: (1.0 - _ringCtrl.value).clamp(0, 1),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF9ECF9A), width: 3),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9ECF9A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x559ECF9A),
                            blurRadius: 32,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 58, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Payment Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _SRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool green;
  const _SRow(this.label, this.value, {this.bold = false, this.green = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          color: bold ? AppColors.textPrimary : AppColors.textMuted,
        )),
        Text(value, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: green ? AppColors.primary : AppColors.textPrimary,
        )),
      ],
    ),
  );
}

// ── Cash numpad widgets ────────────────────────────────────────────────────────

class _CashNumpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _CashNumpad({required this.onKey});

  static const _rows = [
    ['7', '8', '9'],
    ['4', '5', '6'],
    ['1', '2', '3'],
    ['.', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: row.map((k) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _NumpadBtn(label: k, onTap: () => onKey(k)),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}

class _NumpadBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumpadBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBack = label == '⌫';
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isBack ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isBack ? AppColors.danger.withValues(alpha: 0.35) : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: isBack
            ? const Icon(Icons.backspace_outlined, size: 20, color: AppColors.danger)
            : Text(label, style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetBtn(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary,
        )),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _MethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              )),
              if (badge != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge!, style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
                  )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
