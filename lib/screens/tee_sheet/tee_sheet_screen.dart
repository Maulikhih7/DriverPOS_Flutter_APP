import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tee_sheet_model.dart';
import '../../models/tee_sheet_page_config.dart';
import '../../providers/tee_sheet_page_config_provider.dart';
import '../../providers/tee_sheet_provider.dart';
import '../../services/socket_service.dart';
import 'slot_detail_modal.dart';
import 'widgets/tee_sheet_legend_modal.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

class TeeSheetScreen extends ConsumerWidget {
  const TeeSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teeSheetListAsync = ref.watch(teeSheetListProvider);
    final selectedSheet = ref.watch(selectedTeeSheetProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Column(
        children: [
          // Tee sheet selector (horizontal chips)
          teeSheetListAsync.when(
            loading: () =>
                const LinearProgressIndicator(color: Color(0xFF9ECF9A)),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Failed to load: $e',
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
            data: (sheets) => _TeeSheetSelector(sheets: sheets),
          ),
          if (selectedSheet == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select a tee sheet to view',
                  style: GoogleFonts.nunito(color: AppColors.textMuted),
                ),
              ),
            )
          else
            const Expanded(child: _TeeSheetView()),
        ],
      ),
    );
  }
}

// ── Tee sheet selector ────────────────────────────────────────────────────────

class _TeeSheetSelector extends ConsumerWidget {
  final List<TeeSheetInfo> sheets;
  const _TeeSheetSelector({required this.sheets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTeeSheetProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sheets.isNotEmpty && selected == null) {
        ref.read(selectedTeeSheetProvider.notifier).state = sheets.first;
      }
    });

    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: sheets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final sheet = sheets[i];
            final isSel = selected?.id == sheet.id;
            return GestureDetector(
              onTap: () =>
                  ref.read(selectedTeeSheetProvider.notifier).state = sheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF9ECF9A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSel
                        ? const Color(0xFF9ECF9A)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Text(
                  sheet.name,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Socket-aware tee sheet view ───────────────────────────────────────────────

class _TeeSheetView extends ConsumerStatefulWidget {
  const _TeeSheetView();

  @override
  ConsumerState<_TeeSheetView> createState() => _TeeSheetViewState();
}

class _TeeSheetViewState extends ConsumerState<_TeeSheetView> {
  late final SocketService _socket;
  String? _subSheetId;
  String? _subDate;

  // Toolbar state
  String _activeButton = 'notes';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Row height scale (compact / comfortable / expanded)
  double _rowHeight = 54.0;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _initSocket();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _releaseSubscription();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSocket() async {
    await _socket.connect();
    if (mounted) _resubscribe();
  }

  void _releaseSubscription() {
    if (_subSheetId != null && _subDate != null) {
      _socket.unsubscribeFromTeeSheet(
        teeSheetId: _subSheetId!,
        date: _subDate!,
      );
    }
  }

  void _resubscribe() {
    final sheet = ref.read(selectedTeeSheetProvider);
    final date = ref.read(selectedDateProvider);
    if (sheet == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    _releaseSubscription();
    _subSheetId = sheet.id;
    _subDate = dateStr;

    _socket.subscribeToTeeSheet(
      teeSheetId: sheet.id,
      date: dateStr,
      onUpdate: () {
        if (mounted) ref.invalidate(teeSheetSlotsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedTeeSheetProvider, (prev, next) => _resubscribe());
    ref.listen(selectedDateProvider, (prev, next) => _resubscribe());

    final date = ref.watch(selectedDateProvider);
    final slotsAsync = ref.watch(teeSheetSlotsProvider);
    final pageConfig = ref.watch(teeSheetPageConfigProvider).config;

    return Column(
      children: [
        // Date navigation
        _DateBar(date: date),

        // Toolbar: view toggles + search + action icons
        _buildToolbar(pageConfig),

        // Header row
        _buildHeaderRow(pageConfig),

        // Slot rows
        Expanded(
          child: slotsAsync.when(
            loading: () => _TeeSheetShimmerLoading(),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(teeSheetSlotsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9ECF9A),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            data: (rows) {
              final filtered = _searchQuery.isEmpty
                  ? rows
                  : rows
                        .where(
                          (r) =>
                              ((_activeButton == 'toggleBack') ? r.backBooking : r.frontBooking).any(
                                (e) => e.customer.toLowerCase().contains(
                                  _searchQuery,
                                ),
                              ) ||
                              r.time.toLowerCase().contains(_searchQuery),
                        )
                        .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.golf_course,
                        size: 48,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No tee times for this date'
                            : 'No results for "$_searchQuery"',
                        style: GoogleFonts.nunito(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                );
              }

              final sheet = ref.read(selectedTeeSheetProvider)!;
              return RefreshIndicator(
                color: const Color(0xFF9ECF9A),
                strokeWidth: 2.5,
                onRefresh: () async {
                  ref.invalidate(teeSheetSlotsProvider);
                  await Future.any([
                    ref.read(teeSheetSlotsProvider.future).then((_) {}).catchError((_) {}),
                    Future.delayed(const Duration(seconds: 5)),
                  ]);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StaggeredRow(
                      index: i,
                      child: _TeeTimeRow(
                        row: filtered[i],
                        sheet: sheet,
                        date: DateFormat('yyyy-MM-dd').format(date),
                        showBack: (_activeButton == 'toggleBack'),
                        isEven: i.isEven,
                        isLast: i == filtered.length - 1,
                        rowHeight: _rowHeight,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(TeeSheetPageConfig config) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < config.buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _tabButton(config.buttons[i]),
          ],
          const SizedBox(width: 10),

          // Search bar
          if (config.searchEnabled)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF374151),
                  ),
                  decoration: InputDecoration(
                    hintText: config.searchPlaceholder,
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10, right: 6),
                      child: Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 0,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 10),

          _iconBtn(
            'assets/images/info_tea.png',
            'Status legend',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const TeeSheetLegendModal(),
            ),
          ),
          const SizedBox(width: 4),
          _iconBtn('assets/images/print_tea_data.png', 'Print tee sheet'),
          const SizedBox(width: 4),

          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
            size: 22,
          ),
          const SizedBox(width: 4),

          Container(width: 1, height: 24, color: const Color(0xFFA8CE9F)),
          const SizedBox(width: 8),

          // Row height controls
          _iconBtnAction(
            Icons.remove_rounded,
            'Compact rows',
            onTap: () => setState(() => _rowHeight = (_rowHeight - 10).clamp(36.0, 100.0)),
          ),
          const SizedBox(width: 2),
          _iconBtnAction(
            Icons.add_rounded,
            'Expand rows',
            onTap: () => setState(() => _rowHeight = (_rowHeight + 10).clamp(36.0, 100.0)),
          ),
          const SizedBox(width: 8),

          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF9ECF9A),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/andr_cpytp.png',
              width: 16,
              height: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(TeeSheetButtonConfig button) {
    final isActive = _activeButton == button.key;
    return GestureDetector(
      onTap: () => setState(() => _activeButton = button.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: button.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? button.accent : const Color(0xFFD1D5DB),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          button.label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? button.accent : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _iconBtnAction(IconData icon, String tooltip, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _iconBtn(String asset, String featureName, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap:
          onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$featureName — coming soon',
                style: GoogleFonts.nunito(fontSize: 13),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(child: Image.asset(asset, width: 18, height: 18)),
      ),
    );
  }

  Widget _buildHeaderRow(TeeSheetPageConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF9ECF9A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              config.timeColumnTitle,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 36,
              alignment: Alignment.center,
              child: Text(
                (_activeButton == 'toggleBack') ? config.backColumnTitle : config.frontColumnTitle,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date navigation bar ───────────────────────────────────────────────────────

class _DateBar extends ConsumerWidget {
  final DateTime date;
  const _DateBar({required this.date});

  void _stepDate(WidgetRef ref, int days) {
    ref.read(selectedDateProvider.notifier).state =
        date.add(Duration(days: days));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('EEE, MMM dd, yyyy');
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -400) _stepDate(ref, 1);   // swipe left → next day
        if (v > 400) _stepDate(ref, -1);   // swipe right → prev day
      },
      child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: Color(0xFF244065),
              size: 18,
            ),
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                date.subtract(const Duration(days: 1)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              minimumSize: const Size(30, 30),
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF9ECF9A),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ref.read(selectedDateProvider.notifier).state = picked;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3EC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF799C74),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fmt.format(date),
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF244065),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
              color: Color(0xFF244065),
              size: 18,
            ),
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                date.add(const Duration(days: 1)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              minimumSize: const Size(30, 30),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ));  // closes GestureDetector > child: Container
  }
}

// ── Single tee time row ───────────────────────────────────────────────────────

class _TeeTimeRow extends ConsumerWidget {
  final TeeTimeRow row;
  final TeeSheetInfo sheet;
  final String date;
  final bool showBack;
  final bool isEven;
  final bool isLast;
  final double rowHeight;

  const _TeeTimeRow({
    required this.row,
    required this.sheet,
    required this.date,
    required this.showBack,
    required this.isEven,
    required this.isLast,
    this.rowHeight = 54,
  });

  Color _statusStrip(List<TeeSlotEntry> entries) {
    if (row.isBlock) return const Color(0xFFE53935);
    if (entries.isEmpty) return const Color(0xFFD1D5DB);
    final hasPending = entries.any((e) => e.isPending);
    if (hasPending) return const Color(0xFFF59E0B);
    final hasPaid = entries.any((e) => e.checkedIn);
    if (hasPaid) return const Color(0xFF244065);
    return const Color(0xFF22C55E);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFull = row.count >= 5;

    // No row-level tap target — matches the web, where the Time column has
    // no click behavior of its own. Each booking capsule and the leftover
    // empty space are individually tappable (see _buildBookingArea).
    final totalCount = showBack ? row.backCount : row.frontCount;
    final allowNewBooking = !showBack;

    final entries = showBack ? row.backBooking : row.frontBooking;
    final stripColor = _statusStrip(entries);

    return Row(
      children: [
        // Status strip
        Container(
          width: 4,
          height: rowHeight,
          color: stripColor,
        ),

        // Time column
        Container(
          width: 64,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: const BorderSide(color: Color(0xFFD9D9D9)),
              bottom: isLast
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFD9D9D9)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                row.time,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: row.isBlock
                      ? AppColors.danger
                      : isFull
                      ? const Color(0xFF795548)
                      : const Color(0xFF244065),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                row.isBlock ? 'Block' : '${row.count}/5',
                style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
              ),
              if (entries.isNotEmpty && rowHeight >= 44) ...[
                const SizedBox(height: 3),
                _MiniAvatarRow(entries: entries),
              ],
            ],
          ),
        ),

        // Single full-width booking column (Front or Back)
        Expanded(
          child: Container(
            height: rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: row.isBlock ? const Color(0xFFFFEBEE) : Colors.transparent,
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFFD9D9D9)),
              ),
            ),
            child: row.isBlock && !showBack
                ? Row(
                    children: [
                      const Icon(Icons.block, size: 14, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Text(
                        row.blockName ?? 'Blocked',
                        style: GoogleFonts.nunito(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : _buildBookingArea(
                    context,
                    ref,
                    entries: entries,
                    totalCount: totalCount,
                    allowNewBooking: allowNewBooking,
                  ),
          ),
        ),
      ],
    );
  }

  // Mirrors the web's per-capsule click model (ShowFrontTeeSheetData.jsx):
  // each existing booking gets its own tap target sized proportionally to
  // its player count, and any leftover width (the slot isn't full) is a
  // separate tap target that starts a brand-new, independent booking in
  // the same slot — instead of always re-opening whichever booking(s)
  // already exist there.
  Widget _buildBookingArea(
    BuildContext context,
    WidgetRef ref, {
    required List<TeeSlotEntry> entries,
    required int totalCount,
    required bool allowNewBooking,
  }) {
    if (entries.isEmpty) {
      if (!allowNewBooking) {
        return Text(
          '—',
          style: GoogleFonts.nunito(color: AppColors.border, fontSize: 12),
        );
      }
      return GestureDetector(
        // Same hit-testing note as the leftover-space target below — the
        // surrounding empty area of the row isn't covered by the Icon/Text
        // bounds, so it needs to be explicitly opaque to be fully tappable.
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            _openModal(context, ref, entries: const [], count: totalCount),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 14,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 6),
            Text(
              'Tap to book',
              style: GoogleFonts.nunito(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    int spanFor(int customerCount) =>
        customerCount >= 4 ? 24 : customerCount * 6;
    final usedSpan = entries.fold<int>(
      0,
      (s, e) => s + spanFor(e.customerCount),
    );
    final remainingSpan = allowNewBooking ? (24 - usedSpan).clamp(0, 24) : 0;

    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            // Mirrors TeeSheetConnections.jsx — a green dot-line-dot link
            // shown between sibling capsules from the same split booking
            // (same groupId), so it's visually clear they're one original
            // reservation even though each person got their own capsule.
            (entries[i - 1].groupId != null &&
                    entries[i - 1].groupId == entries[i].groupId)
                ? const _SplitConnector()
                : const SizedBox(width: 6),
          Expanded(
            flex: spanFor(entries[i].customerCount),
            child: GestureDetector(
              onTap: () => _openModal(
                context,
                ref,
                entries: [entries[i]],
                count: entries[i].customerCount,
              ),
              child: _PlayerChip(entry: entries[i]),
            ),
          ),
        ],
        if (remainingSpan > 0) ...[
          const SizedBox(width: 6),
          Expanded(
            flex: remainingSpan,
            child: GestureDetector(
              // A childless/colorless box never registers a hit under the
              // default `deferToChild` behavior — without `opaque` here,
              // taps on this empty leftover space silently fall through to
              // nothing (or, on a real touchscreen, land back on the
              // adjacent capsule instead).
              behavior: HitTestBehavior.opaque,
              onTap: () => _openModal(
                context,
                ref,
                entries: const [],
                count: totalCount,
              ),
              // Visually distinct from the adjacent capsule(s) so it's
              // unmistakable that this is a separate "start a new booking"
              // target, not part of the existing booking next to it.
              child: Container(
                height: _PlayerChip._height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                  borderRadius: BorderRadius.circular(_PlayerChip._height / 2),
                ),
                child: const Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFFB0B7C0),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openModal(
    BuildContext context,
    WidgetRef ref, {
    required List<TeeSlotEntry> entries,
    required int count,
  }) {
    showSlotDetailModal(
      context,
      ref,
      sheet: sheet,
      startingSlot: row.time,
      date: date,
      existingEntries: entries,
      existingCount: count,
    );
  }
}

// ── Mini avatar row (shown in time column) ────────────────────────────────────

class _MiniAvatarRow extends StatelessWidget {
  final List<TeeSlotEntry> entries;
  const _MiniAvatarRow({required this.entries});

  static const _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
  ];

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final count = entries.length.clamp(0, 4);
    return SizedBox(
      height: 14,
      width: (count * 10 + 4).toDouble(),
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 10.0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initial(entries[i].customer),
                  style: const TextStyle(
                    fontSize: 7,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Player chip ───────────────────────────────────────────────────────────────

class _PlayerChip extends StatelessWidget {
  final TeeSlotEntry entry;
  const _PlayerChip({required this.entry});

  static const double _height = 34;
  static const double _badgeWidth = 28;
  static const Color _bodyText = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    // Mirrors the web capsule (CustomerCapsuleBox.jsx): pill shape, a
    // left hole-count badge segment, and the booking's server-computed
    // bgColor/color — not a locally-derived status color — so the card
    // always matches whatever the web shows for the same booking.
    final bg =
        entry.bgColor ??
        (entry.noshow
            ? const Color(0xFFFFEBEE)
            : entry.checkedIn
            ? const Color(0xFFE8F5E9)
            : entry.isPending
            ? const Color(0xFFFFF8E1)
            : const Color(0xFFEAF3E7));
    final badge = entry.badgeColor ?? const Color(0xFFA5A3AB);

    final icons = <Widget>[
      if (entry.carts > 0) ...[
        const _StatusIcon('assets/images/teesheet_golf_cart.png'),
        if (entry.assignedCart != null) ...[
          const SizedBox(width: 2),
          Text(
            entry.assignedCart!,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _bodyText,
            ),
          ),
        ],
        const SizedBox(width: 4),
      ],
      if (entry.handicap)
        const _StatusIcon('assets/images/teesheet_handicap.png'),
      if (entry.rentalClubs)
        const _StatusIcon('assets/images/teesheet_rental_clubs.png'),
      if (entry.rainCheck)
        const _StatusIcon('assets/images/teesheet_raincheck.png'),
      if (entry.isPreAuth)
        const _StatusIcon('assets/images/teesheet_preauth.png'),
      if (entry.preventNoshow)
        const _StatusIcon('assets/images/teesheet_prevent_noshow.png'),
      if (entry.onlineBook)
        const _StatusIcon('assets/images/teesheet_online.png'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: Container(
          // Combined (non-split, multi-customer) bookings send their bg as
          // a CSS linear-gradient — e.g. half-paid/half-unpaid within one
          // capsule — so prefer the parsed gradient when present, matching
          // the web exactly instead of collapsing it to one flat color.
          color: entry.bgGradient == null ? bg : null,
          decoration: entry.bgGradient == null
              ? null
              : BoxDecoration(gradient: entry.bgGradient),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _badgeWidth,
                color: badge,
                alignment: Alignment.center,
                child: Text(
                  '${entry.holes}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${entry.customerCount}',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _bodyText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.customer,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _bodyText,
                                decoration: entry.noshow
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (icons.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: icons,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitConnector extends StatelessWidget {
  const _SplitConnector();

  static const _green = Color(0xFF44DD44);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: _green)),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String asset;
  const _StatusIcon(this.asset);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Image.asset(asset, width: 12, height: 12),
    );
  }
}

// ── Stagger fade-slide wrapper for first-load animation ───────────────────────

class _StaggeredRow extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredRow({required this.index, required this.child});

  @override
  State<_StaggeredRow> createState() => _StaggeredRowState();
}

class _StaggeredRowState extends State<_StaggeredRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(AppAnimations.staggerDelay(widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Shimmer skeleton for loading state ────────────────────────────────────────

class _TeeSheetShimmerLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
