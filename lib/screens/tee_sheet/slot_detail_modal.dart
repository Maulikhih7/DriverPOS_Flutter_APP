import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tee_sheet_model.dart';
import '../../providers/tee_sheet_provider.dart';
import '../../repositories/tee_sheet_repository.dart';
import '../../services/socket_service.dart';
import '../../widgets/interactive_confirm.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

Future<void> showSlotDetailModal(
  BuildContext context,
  WidgetRef ref, {
  required TeeSheetInfo sheet,
  required String startingSlot,
  required String date,
  required List<TeeSlotEntry> existingEntries,
  required int existingCount,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: SlotDetailModal(
        sheet: sheet,
        startingSlot: startingSlot,
        date: date,
        existingEntries: existingEntries,
        existingCount: existingCount,
      ),
    ),
  );
}

// ── Main modal widget ─────────────────────────────────────────────────────────

class SlotDetailModal extends ConsumerStatefulWidget {
  final TeeSheetInfo sheet;
  final String startingSlot;
  final String date;
  final List<TeeSlotEntry> existingEntries;
  final int existingCount;

  const SlotDetailModal({
    super.key,
    required this.sheet,
    required this.startingSlot,
    required this.date,
    required this.existingEntries,
    required this.existingCount,
  });

  @override
  ConsumerState<SlotDetailModal> createState() => _SlotDetailModalState();
}

class _SlotDetailModalState extends ConsumerState<SlotDetailModal>
    with SingleTickerProviderStateMixin {
  late final SocketService _socket;
  late final TabController _tabs;

  // Slot detail state
  bool _loadingDetail = false;
  SlotDetail? _detail;

  // Booking form state
  int _persons = 1;
  int _holes = 18;
  final _cart1Ctrl = TextEditingController();
  final _cart2Ctrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _perSlot = 4;
  bool _split = false;
  String _selectedSplit = '4 Per Split';

  final List<_PlayerEntry> _rows = [];
  String? _pendingSlotId;
  bool _saving = false;
  String? _error;

  // Selected tab
  String _selectedTab = 'tee_times';

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _tabs = TabController(length: 3, vsync: this);
    _holes = widget.sheet.holes.contains(18) ? 18 : widget.sheet.holes.first;

    // Matches the web (handleBookedCustomerHandler passes a no-op
    // triggerTeesheetEvent and never emits PENDING_TEESHEET_EVENT when
    // opening an existing booking) — the pending-reservation hold is only
    // for a brand-new booking, not for editing one that already exists.
    if (widget.existingEntries.isNotEmpty) {
      _loadDetail(widget.existingEntries.first.slotId);
    } else {
      _holdSlot();
      _initEmptyRows();
    }
  }

  @override
  void dispose() {
    _releaseSlot();
    _tabs.dispose();
    _cart1Ctrl.dispose();
    _cart2Ctrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Pending reservation ───────────────────────────────────────────────────

  Future<void> _holdSlot() async {
    if (!_socket.isConnected) return;
    final res = await _socket.requestPendingSlot(
      teeSheetId: widget.sheet.id,
      date: widget.date,
      startingSlot: widget.startingSlot,
      slotCustomer: widget.existingCount,
      isPending: true,
    );
    final id = res?['slotId'] as String?;
    if (mounted && id != null) _pendingSlotId = id;
  }

  void _releaseSlot() {
    final id = _pendingSlotId;
    if (id == null) return;
    _pendingSlotId = null;
    if (!_socket.isConnected) return;
    _socket.requestPendingSlot(
      teeSheetId: widget.sheet.id,
      date: widget.date,
      startingSlot: widget.startingSlot,
      slotCustomer: widget.existingCount,
      isPending: false,
      pendingSlotId: id,
    );
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadDetail(String slotId) async {
    setState(() => _loadingDetail = true);
    try {
      final detail = await ref
          .read(teeSheetRepositoryProvider)
          .getSlotDetails(slotId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _holes = detail.holes;
        _perSlot = detail.personPerSlot;
        _persons = detail.persons;
        _cart1Ctrl.text = detail.cartOne ?? '';
        _cart2Ctrl.text = detail.cartTwo ?? '';
        _notesCtrl.text = detail.notes ?? '';
        _split = detail.split;
        _rows
          ..clear()
          ..addAll(detail.customers.map(_PlayerEntry.fromCustomer));
        // Web always pads the row table to 5 visible seats — max capacity
        // per slot — regardless of how many are actually booked/named.
        while (_rows.length < 5) {
          _rows.add(_PlayerEntry.empty());
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _initEmptyRows() {
    _rows.clear();
    // Matches web: always 5 visible seats for a new booking — "persons" is
    // a separate, freely-set total, not tied to how many rows are shown.
    for (var i = 0; i < 5; i++) {
      _rows.add(_PlayerEntry.empty());
    }
    setState(() {});
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _markNoShow(_PlayerEntry entry) async {
    final cid = entry.customerId;
    final did = entry.docId;
    final sid = entry.slotId ?? _detail?.slotId;
    if (cid == null || did == null || sid == null) return;

    try {
      await ref
          .read(teeSheetRepositoryProvider)
          .markNoShow(slotId: sid, customerId: cid, docId: did);
      if (!mounted) return;
      ref.invalidate(teeSheetSlotsProvider);
      await _loadDetail(sid);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _deletePlayer(_PlayerEntry entry) async {
    final cid = entry.customerId;
    final sid = entry.slotId ?? _detail?.slotId;
    if (sid == null) return;

    try {
      await ref
          .read(teeSheetRepositoryProvider)
          .deleteSlot(sid, customerId: cid);
      if (!mounted) return;
      ref.invalidate(teeSheetSlotsProvider);
      if (_detail != null) {
        await _loadDetail(sid);
      } else {
        setState(() => _rows.remove(entry));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _payExistingSlot() async {
    final unpaid = _rows
        .where((r) => r.customerId != null && r.transaction != 'Paid')
        .toList();
    if (unpaid.isEmpty) return;

    final totalAmount = unpaid.fold<double>(0, (s, r) => s + r.amount);
    final totalTax = unpaid.fold<double>(0, (s, r) => s + r.taxAmount);
    final subtotal = totalAmount - totalTax;
    final first = unpaid.first;
    final slotId = first.slotId ?? _detail?.slotId;
    final docIds = unpaid.map((r) => r.docId).whereType<String>().toList();

    if (slotId == null || docIds.isEmpty) {
      setState(() => _error = 'Unable to find booking details for payment');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Backend's /transaction/checkout requires an existing Sale cart —
      // create it from this slot's unpaid players before navigating away.
      await ref
          .read(teeSheetRepositoryProvider)
          .addCustomersToSalesCart(slotId: slotId, individual: docIds);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }

    if (!mounted) return;

    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(
      '/checkout',
      extra: {
        'total': totalAmount,
        'subtotal': subtotal,
        'tax': totalTax,
        'customerId': first.customerId!,
        'customerName': first.fullName ?? 'Guest',
      },
    );
  }

  Future<void> _saveBooking({bool andPay = false}) async {
    final filled = _rows.where((r) => r.suggestion != null).toList();
    if (filled.isEmpty) {
      setState(() => _error = 'Add at least one customer');
      return;
    }
    // Matches web's validation: persons must cover at least the named seats
    // — the rest are auto-filled server-side as "Guest Customer".
    if (_persons < filled.length) {
      setState(
        () => _error =
            'Persons must be at least equal to the number of named customers',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final golfCourseId = widget.sheet.golfCourseId ?? '';

      final customers = filled.map((r) {
        final fees = r.suggestion!.feesForHoles(_holes);
        return {
          'customerId': r.suggestion!.id,
          'greenFee': fees.greenFee,
          'cartFee': r.cartNeeded ? fees.cartFee : 0.0,
          'greenFeeTax': fees.greenFeeTax,
          'cartFeeTax': r.cartNeeded ? fees.cartFeeTax : 0.0,
          'amount': r.cartNeeded ? fees.total : fees.greenFee,
          'taxAmount': r.cartNeeded ? fees.taxAmount : fees.greenFeeTax,
          'cartNeeded': r.cartNeeded,
          'handicap': r.handicap,
          'rentalClubs': r.rentalClubs,
        };
      }).toList();

      var totalAmount = customers.fold<double>(
        0,
        (s, c) => s + (c['amount'] as num).toDouble(),
      );
      var totalTax = customers.fold<double>(
        0,
        (s, c) => s + (c['taxAmount'] as num).toDouble(),
      );

      // Seats left unfilled are auto-assigned to "Guest Customer" server-side
      // (see validateCustomers) — price them the same way here so Reserve &
      // Pay charges the correct total instead of only the named players'.
      final guestCount = _persons - filled.length;
      if (guestCount > 0) {
        final guestSuggestions = await ref
            .read(teeSheetRepositoryProvider)
            .getCustomerSuggestions(
              golfCourseName: widget.sheet.golfCourseName ?? '',
              date: widget.date,
              time: widget.startingSlot,
              name: 'Guest Customer',
            );
        final guestMatches = guestSuggestions.where(
          (c) => c.fullName == 'Guest Customer',
        );
        if (guestMatches.isNotEmpty) {
          final guest = guestMatches.first;
          final guestFees = guest.feesForHoles(_holes);
          totalAmount += guestCount * guestFees.greenFee;
          totalTax += guestCount * guestFees.greenFeeTax;
        } else {
          // No "Guest Customer" pricing record for this course — proceeding
          // would silently undercharge for the unfilled seats.
          throw Exception(
            "Course is missing a 'Guest Customer' pricing record — cannot "
            'price $guestCount unfilled seat(s). Contact support.',
          );
        }
      }

      final subtotal = totalAmount - totalTax;

      final booked = await ref
          .read(teeSheetRepositoryProvider)
          .bookSlot(
            golfCourseId: golfCourseId,
            teeSheetId: widget.sheet.id,
            date: widget.date,
            startingSlot: widget.startingSlot,
            // Total seats in this booking — backend fills the gap between
            // this and customers.length with "Guest Customer" entries.
            persons: _persons,
            personPerSlot: _perSlot,
            holes: _holes,
            customers: customers,
            cartOne: _cart1Ctrl.text,
            cartTwo: _cart2Ctrl.text,
            notes: _notesCtrl.text,
            split: _split,
          );

      ref.invalidate(teeSheetSlotsProvider);

      if (andPay) {
        // Backend's /transaction/checkout requires an existing Sale cart —
        // create it from the just-booked slot before navigating away.
        await ref
            .read(teeSheetRepositoryProvider)
            .addCustomersToSalesCart(
              slotId: booked.slotId,
              individual: booked.docIds,
            );
      }

      if (!mounted) return;

      final router = GoRouter.of(context);
      Navigator.pop(context);

      if (andPay) {
        router.push(
          '/checkout',
          extra: {
            'total': totalAmount,
            'subtotal': subtotal,
            'tax': totalTax,
            'customerId': filled.first.suggestion!.id,
            'customerName': filled.first.suggestion!.fullName,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reservation confirmed for ${widget.startingSlot}',
              style: GoogleFonts.nunito(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF9ECF9A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      String msg;
      if (e is DioException) {
        final data = e.response?.data;
        msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : e.toString().replaceFirst('Exception: ', '');
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _error = msg;
        });
      }
    }
  }

  Future<void> _updateBooking() async {
    final filled = _rows
        .where((r) => r.suggestion != null || r.customerId != null)
        .toList();
    if (filled.isEmpty) {
      setState(() => _error = 'Add at least one customer');
      return;
    }
    if (_persons < filled.length) {
      setState(
        () => _error =
            'Persons must be at least equal to the number of named customers',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final slotId = _detail?.slotId ?? widget.existingEntries.first.slotId;

      final customers = filled.map((r) {
        if (r.suggestion != null) {
          // Newly added / re-selected player — derive fresh fees for the
          // current holes since we have their rate table.
          final fees = r.suggestion!.feesForHoles(_holes);
          return {
            if (r.docId != null) 'docId': r.docId,
            'customerId': r.suggestion!.id,
            'greenFee': fees.greenFee,
            'cartFee': r.cartNeeded ? fees.cartFee : 0.0,
            'greenFeeTax': fees.greenFeeTax,
            'cartFeeTax': r.cartNeeded ? fees.cartFeeTax : 0.0,
            'amount': r.cartNeeded ? fees.total : fees.greenFee,
            'taxAmount': r.cartNeeded ? fees.taxAmount : fees.greenFeeTax,
            'cartNeeded': r.cartNeeded,
            'handicap': r.handicap,
            'rentalClubs': r.rentalClubs,
            'noshow': r.noshow,
          };
        }
        // Already-booked player — reuse the fee breakdown the server last
        // computed for them (we don't hold a rate table for players loaded
        // from an existing booking, only for freshly-searched ones).
        return {
          'docId': r.docId,
          'customerId': r.customerId,
          'greenFee': r.greenFee,
          'cartFee': r.cartNeeded ? r.cartFee : 0.0,
          'greenFeeTax': r.greenFeeTax,
          'cartFeeTax': r.cartNeeded ? r.cartFeeTax : 0.0,
          'amount': r.amount,
          'taxAmount': r.taxAmount,
          'cartNeeded': r.cartNeeded,
          'handicap': r.handicap,
          'rentalClubs': r.rentalClubs,
          'noshow': r.noshow,
        };
      }).toList();

      await ref
          .read(teeSheetRepositoryProvider)
          .updateSlotCustomers(
            slotId: slotId,
            customers: customers,
            startingSlot: widget.startingSlot,
            date: widget.date,
            persons: _persons,
            golfCourseId: widget.sheet.golfCourseId,
            teeSheetId: widget.sheet.id,
            cartOne: _cart1Ctrl.text,
            cartTwo: _cart2Ctrl.text,
            notes: _notesCtrl.text,
            holes: _holes,
            carts: filled.where((r) => r.cartNeeded).length,
            split: _split,
          );

      ref.invalidate(teeSheetSlotsProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking updated',
            style: GoogleFonts.nunito(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF9ECF9A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      String msg;
      if (e is DioException) {
        final data = e.response?.data;
        msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : e.toString().replaceFirst('Exception: ', '');
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _error = msg;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SizedBox(
          width: 1020,
          height: mq.size.height * 0.88,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 40,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildTabRow(),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.danger.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Expanded(child: _buildTabContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF9ECF9A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pending Reservation — on ${widget.date} @ ${widget.startingSlot}',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _tab('Tee Times', 'tee_times'),
          const SizedBox(width: 8),
          _tab('Events', 'events'),
          const SizedBox(width: 8),
          _tab('Block', 'block'),
        ],
      ),
    );
  }

  Widget _tab(String label, String id) {
    final isActive = _selectedTab == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF9ECF9A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF9ECF9A) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 'events') {
      return Center(
        child: Text(
          'Events — coming soon',
          style: GoogleFonts.nunito(color: AppColors.textMuted),
        ),
      );
    }
    if (_selectedTab == 'block') {
      return Center(
        child: Text(
          'Block — coming soon',
          style: GoogleFonts.nunito(color: AppColors.textMuted),
        ),
      );
    }
    return _buildTeeTimesTab();
  }

  Widget _buildTeeTimesTab() {
    if (_loadingDetail) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9ECF9A)),
      );
    }

    return Column(
      children: [
        // Config row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildConfigRow(),
        ),

        // Player rows
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Player table
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_rows.length, (i) {
                        final isAdded = i >= 5;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPlayerRow(i, isAdded: isAdded),
                            if (i < _rows.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Add More button
                GestureDetector(
                  onTap: () {
                    setState(() => _rows.add(_PlayerEntry.empty()));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add More',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Split Shot checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _split,
                      activeColor: const Color(0xFF9ECF9A),
                      onChanged: (v) => setState(() => _split = v ?? false),
                    ),
                    Text(
                      'Split Shot',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Notes + buttons footer
        _buildFooter(),
      ],
    );
  }

  Widget _buildConfigRow() {
    return Row(
      children: [
        Text(
          'Add New Tee Time',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF244065),
          ),
        ),
        const SizedBox(width: 10),

        // Person icon + count
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF244065),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        _SmallDropdown<int>(
          value: _persons,
          items: const [1, 2, 3, 4, 5],
          label: (v) => '$v',
          // Matches web: this is just the intended total — it doesn't
          // resize the row table, which always shows all 5 seats.
          onChanged: (v) => setState(() => _persons = v),
        ),
        const SizedBox(width: 8),

        // Flag icon + holes
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFF5A623),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag_outlined, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 6),
        _SmallDropdown<int>(
          value: _holes,
          items: widget.sheet.holes.isNotEmpty ? widget.sheet.holes : [9, 18],
          label: (v) => '$v',
          onChanged: (v) => setState(() => _holes = v),
        ),
        const SizedBox(width: 8),

        // Cart 1
        Expanded(child: _miniTextField('Enter cart one', _cart1Ctrl)),
        const SizedBox(width: 8),

        // Cart 2
        Expanded(child: _miniTextField('Enter cart two', _cart2Ctrl)),
        const SizedBox(width: 8),

        // Per-split dropdown
        _SmallDropdown<String>(
          value: _selectedSplit,
          items: const ['4 Per Split', '3 Per Split', '2 Per Split'],
          label: (v) => v,
          onChanged: (v) {
            setState(() {
              _selectedSplit = v;
              _perSlot = int.parse(v.split(' ').first);
            });
          },
        ),
      ],
    );
  }

  Widget _miniTextField(String hint, TextEditingController ctrl) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.nunito(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
            fontSize: 13,
            color: const Color(0xFF9CA3AF),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF9ECF9A), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow(int index, {bool isAdded = false}) {
    final e = _rows[index];
    final number = (index + 1).toString().padLeft(2, '0');
    final isBooked = e.docId != null;

    Color rowBg = Colors.white;
    if (e.noshow) rowBg = const Color(0xFFFFEBEE);
    if (e.checkedIn) rowBg = const Color(0xFFE8F5E9);

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // Row number
          SizedBox(
            width: 24,
            child: Text(
              number,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF244065),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Name search field
          Expanded(
            flex: 3,
            child: isBooked
                ? Text(
                    e.fullName ?? 'Guest',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: e.noshow
                          ? AppColors.danger
                          : e.checkedIn
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF374151),
                      decoration: e.noshow ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : _CustomerSearchField(
                    initialText: e.suggestion?.fullName,
                    golfCourseName: widget.sheet.golfCourseName ?? '',
                    date: widget.date,
                    time: widget.startingSlot,
                    onSelected: (s) {
                      setState(() {
                        e.suggestion = s;
                        e.email = s.email;
                        e.phoneNumber = s.phoneNumber;
                        e.membershipType = s.membershipType;
                      });
                    },
                  ),
          ),
          const SizedBox(width: 8),

          // Phone
          Expanded(
            flex: 2,
            child: Text(
              e.phoneNumber ?? '—',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Membership
          Expanded(
            flex: 2,
            child: Text(
              e.membershipType ?? '—',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Cart toggle
          GestureDetector(
            onTap: () => setState(() => e.cartNeeded = !e.cartNeeded),
            child: Icon(
              Icons.directions_car,
              size: 16,
              color: e.cartNeeded
                  ? const Color(0xFF244065)
                  : const Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(width: 6),

          // Rental clubs toggle
          GestureDetector(
            onTap: () => setState(() => e.rentalClubs = !e.rentalClubs),
            child: Opacity(
              opacity: e.rentalClubs ? 1.0 : 0.3,
              child: Image.asset(
                'assets/images/teesheet_rental_clubs.png',
                width: 16,
                height: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Handicap toggle
          GestureDetector(
            onTap: () => setState(() => e.handicap = !e.handicap),
            child: Opacity(
              opacity: e.handicap ? 1.0 : 0.3,
              child: Image.asset(
                'assets/images/teesheet_handicap.png',
                width: 16,
                height: 16,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Golf ball icon
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF9ECF9A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.golf_course, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 4),

          // Delete
          GestureDetector(
            onTap: () => _deletePlayer(e),
            child: const Icon(
              Icons.delete_outline,
              size: 16,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 6),

          // No Show button
          GestureDetector(
            onTap: () => _markNoShow(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: e.noshow ? AppColors.danger : const Color(0xFF9ECF9A),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'No show',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Remove button for dynamically added rows
          if (isAdded) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _rows.removeAt(index)),
              child: const Icon(Icons.close, size: 13, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isExisting = widget.existingEntries.isNotEmpty;
    final blocked = _saving || _loadingDetail;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Notes textarea
          Expanded(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _notesCtrl,
                maxLines: null,
                expands: true,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                ),
                decoration: InputDecoration(
                  hintText: 'Write Notes',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Action buttons — swipe & hold controls
          SizedBox(
            width: 270,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isExisting) ...[
                  // Slide to Reserve
                  SwipeToConfirm(
                    label: 'Slide to Reserve',
                    color: const Color(0xFF244065),
                    loading: _saving,
                    enabled: !blocked,
                    height: 48,
                    onConfirmed: _saving ? null : () => _saveBooking(),
                  ),
                  const SizedBox(height: 8),
                  // Hold to Reserve & Pay
                  HoldToConfirm(
                    label: 'Reserve & Pay',
                    color: const Color(0xFFF5A623),
                    holdDuration: const Duration(milliseconds: 1100),
                    loading: _saving,
                    enabled: !blocked,
                    height: 48,
                    onConfirmed: _saving ? null : () => _saveBooking(andPay: true),
                  ),
                ] else ...[
                  // Hold to Update
                  HoldToConfirm(
                    label: 'Update Booking',
                    color: const Color(0xFF244065),
                    holdDuration: const Duration(milliseconds: 900),
                    loading: _saving,
                    enabled: !blocked,
                    height: 48,
                    onConfirmed: blocked ? null : _updateBooking,
                  ),
                  const SizedBox(height: 8),
                  // Slide to Pay
                  SwipeToConfirm(
                    label: 'Slide to Pay',
                    color: const Color(0xFFF5A623),
                    loading: _saving,
                    enabled: !blocked,
                    height: 48,
                    onConfirmed: blocked ? null : _payExistingSlot,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer search field ─────────────────────────────────────────────────────

class _CustomerSearchField extends ConsumerStatefulWidget {
  final String? initialText;
  final String golfCourseName;
  final String date;
  final String time;
  final ValueChanged<CustomerSuggestion> onSelected;

  const _CustomerSearchField({
    this.initialText,
    required this.golfCourseName,
    required this.date,
    required this.time,
    required this.onSelected,
  });

  @override
  ConsumerState<_CustomerSearchField> createState() =>
      _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends ConsumerState<_CustomerSearchField> {
  late final TextEditingController _ctrl;
  List<CustomerSuggestion> _results = [];
  bool _loading = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _showDropdown = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _showDropdown = true;
    });
    try {
      // Course/date/time-aware lookup — returns real green/cart fees per
      // customer's membership, unlike the generic customer directory search.
      final r = await ref
          .read(teeSheetRepositoryProvider)
          .getCustomerSuggestions(
            golfCourseName: widget.golfCourseName,
            date: widget.date,
            time: widget.time,
            name: q,
          );
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: TextField(
            controller: _ctrl,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: const Color(0xFF374151),
            ),
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF9ECF9A),
                        ),
                      ),
                    )
                  : _ctrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() => _showDropdown = false);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(top: 6, bottom: 6),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
            ),
            onChanged: _search,
          ),
        ),
        if (_showDropdown && _results.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 280,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final c = _results[i];
                  return InkWell(
                    onTap: () {
                      _ctrl.text = c.fullName;
                      setState(() => _showDropdown = false);
                      widget.onSelected(c);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              c.fullName,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (c.phoneNumber != null)
                            Expanded(
                              flex: 2,
                              child: Text(
                                c.phoneNumber!,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ── Small dropdown ────────────────────────────────────────────────────────────

class _SmallDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _SmallDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF9CA3AF),
          ),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(label(v))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Player entry (mutable UI model) ──────────────────────────────────────────

class _PlayerEntry {
  CustomerSuggestion? suggestion;
  String? docId;
  String? customerId;
  String? fullName;
  String? email;
  String? phoneNumber;
  String? membershipType;
  double amount;
  double taxAmount;
  double greenFee;
  double cartFee;
  double greenFeeTax;
  double cartFeeTax;
  bool cartNeeded;
  bool rentalClubs;
  bool handicap;
  bool checkedIn;
  bool noshow;
  bool isGuest;
  String transaction;
  String? slotId;

  _PlayerEntry.empty()
    : amount = 0,
      taxAmount = 0,
      greenFee = 0,
      cartFee = 0,
      greenFeeTax = 0,
      cartFeeTax = 0,
      cartNeeded = false,
      rentalClubs = false,
      handicap = false,
      checkedIn = false,
      noshow = false,
      isGuest = false,
      transaction = 'Unpaid';

  _PlayerEntry.fromCustomer(SlotCustomer c)
    : docId = c.docId,
      customerId = c.customerId,
      fullName = c.fullName,
      email = c.email,
      phoneNumber = c.phoneNumber,
      membershipType = c.membershipType,
      amount = c.amount,
      taxAmount = c.taxAmount,
      greenFee = c.greenFee,
      cartFee = c.cartFee,
      greenFeeTax = c.greenFeeTax,
      cartFeeTax = c.cartFeeTax,
      cartNeeded = c.cartNeeded,
      rentalClubs = c.rentalClubs,
      handicap = c.handicap,
      checkedIn = c.checkedIn,
      noshow = c.noshow,
      isGuest = c.isGuest,
      transaction = c.transaction,
      slotId = c.slotId;
}
