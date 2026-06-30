import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _tabs = [
    _NavTab(label: 'Tee Sheet',    icon: Icons.list_alt_outlined,        path: '/tee-sheet'),
    _NavTab(label: 'Sales',        icon: Icons.shopping_cart_outlined,   path: '/pos'),
    _NavTab(label: 'Dashboard',    icon: Icons.bar_chart_outlined,       path: '/dashboard'),
    _NavTab(label: 'Transactions', icon: Icons.receipt_long_outlined,    path: '/transactions'),
  ];

  // Live clock
  DateTime _now = DateTime.now();
  Timer? _timer;

  // AppBar dropdown state
  String _selectedCourse = '';
  bool _isCourseMenuOpen = false;
  bool _isTeeSheetMenuOpen = false;
  bool _isProfileMenuOpen = false;
  String _selectedTeeSheet = 'Tee Sheet';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final cartCount = ref.watch(cartProvider).items.length;
    final user = ref.watch(authProvider).user;

    // Use golf course name from user or fallback
    final courseName = user?.golfCourse?.name ?? 'Golf Course';
    if (_selectedCourse.isEmpty) _selectedCourse = courseName;

    return Scaffold(
      appBar: _buildAppBar(user, courseName),
      body: widget.child,
      bottomNavigationBar: _NotchedNavBar(
        selectedIndex: index,
        tabs: _tabs,
        cartCount: cartCount,
        onTap: (i) => context.go(_tabs[i].path),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic user, String courseName) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),

            // Logo
            SizedBox(
              height: 52,
              child: Image.asset(
                'assets/images/drvrpos_tablogo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.golf_course,
                  color: Color(0xFF244065),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Flag + course name dropdown
            SizedBox(
              width: 24,
              height: 24,
              child: Image.asset(
                'assets/images/drvrpos_tabflg.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.flag,
                  color: Color(0xFF244065),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              offset: const Offset(-20, 48),
              onOpened: () =>
                  setState(() => _isCourseMenuOpen = true),
              onCanceled: () =>
                  setState(() => _isCourseMenuOpen = false),
              onSelected: (v) => setState(() {
                _selectedCourse = v;
                _isCourseMenuOpen = false;
              }),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: courseName,
                  child: Text(courseName,
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF244065))),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCourse,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF244065),
                    ),
                  ),
                  Icon(
                    _isCourseMenuOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF244065),
                    size: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Tee sheet dropdown pill
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onOpened: () =>
                  setState(() => _isTeeSheetMenuOpen = true),
              onCanceled: () =>
                  setState(() => _isTeeSheetMenuOpen = false),
              onSelected: (v) => setState(() {
                _selectedTeeSheet = v;
                _isTeeSheetMenuOpen = false;
              }),
              itemBuilder: (_) => [
                'Regular Tee Sheet',
                'VIP Tee Sheet',
                'Practice Tee Sheet',
              ].map((item) => PopupMenuItem<String>(
                    value: item,
                    child: Text(item,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: const Color(0xFF244065))),
                  )).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedTeeSheet,
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: const Color(0xFF212529),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isTeeSheetMenuOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF212529),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Date + time pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3EC),
                border: Border.all(color: const Color(0xFFD0D5DD)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF799C74)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d').format(_now),
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF212529),
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    DateFormat('hh:mm a').format(_now),
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF212529),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Weather placeholder
            const Icon(Icons.wb_sunny_rounded,
                color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text('°F',
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF212529),
                    fontWeight: FontWeight.w600)),

            const SizedBox(width: 10),
            const Icon(Icons.edit_outlined,
                color: Color(0xFF244065), size: 20),
            const SizedBox(width: 10),
            const Icon(Icons.open_in_new_rounded,
                color: Color(0xFF244065), size: 20),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => ref.invalidate(cartProvider),
              child: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF244065), size: 20),
            ),
            const SizedBox(width: 12),

            // User avatar + dropdown
            PopupMenuButton<String>(
              offset: const Offset(0, 56),
              color: Colors.white,
              elevation: 4,
              constraints: const BoxConstraints(
                  minWidth: 200, maxWidth: 200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onOpened: () =>
                  setState(() => _isProfileMenuOpen = true),
              onCanceled: () =>
                  setState(() => _isProfileMenuOpen = false),
              onSelected: (v) {
                setState(() => _isProfileMenuOpen = false);
                if (v == 'logout') {
                  ref.read(authProvider.notifier).logout();
                }
                if (v == 'terminal') {
                  context.push('/terminal-settings');
                }
              },
              itemBuilder: (_) => [
                _profileMenuItem('terminal', 'Terminal Setup'),
                _profileMenuItem('logout', 'Logout'),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF9ECF9A),
                    child: Text(
                      _initials(user?.name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF212529)),
                      ),
                      Text(
                        user?.role ?? 'Staff',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  Icon(
                    _isProfileMenuOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF212529),
                    size: 18,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _profileMenuItem(String value, String title) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF9ECF9A),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Notched animated bottom nav ───────────────────────────────────────────────

class _NotchedNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavTab> tabs;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _NotchedNavBar({
    required this.selectedIndex,
    required this.tabs,
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double barHeight = 64.0;
    const double circleRadius = 26.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double totalHeight = barHeight + circleRadius + bottomPadding;

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double itemWidth = totalWidth / tabs.length;
          final double activeCenter =
              itemWidth * selectedIndex + itemWidth / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Notched green bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: barHeight + bottomPadding,
                child: ClipPath(
                  clipper: _NotchedClipper(
                    activeCenter: activeCenter,
                    notchRadius: circleRadius + 8,
                    totalWidth: totalWidth,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFA4C49F),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),

              // Tab items
              Positioned(
                bottom: bottomPadding,
                left: 0,
                right: 0,
                height: barHeight,
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final isSelected = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: isSelected
                            ? const SizedBox.shrink()
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(tabs[i].icon,
                                          size: 22,
                                          color: Colors.white),
                                      if (i == 1 && cartCount > 0)
                                        Positioned(
                                          right: -6,
                                          top: -4,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$cartCount',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tabs[i].label,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  }),
                ),
              ),

              // Floating active circle
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                bottom: barHeight + bottomPadding - circleRadius,
                left: activeCenter - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2,
                child: GestureDetector(
                  onTap: () => onTap(selectedIndex),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF799C74),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD0E8CE),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF799C74).withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0.85, end: 1.0),
                      curve: Curves.easeOutBack,
                      builder: (_, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            tabs[selectedIndex].icon,
                            size: 24,
                            color: Colors.white,
                          ),
                          if (selectedIndex == 1 && cartCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$cartCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Active label inside bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                bottom: bottomPadding + 6,
                left: activeCenter - itemWidth / 2,
                width: itemWidth,
                child: Text(
                  tabs[selectedIndex].label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Notched path clipper ──────────────────────────────────────────────────────

class _NotchedClipper extends CustomClipper<Path> {
  final double activeCenter;
  final double notchRadius;
  final double totalWidth;

  const _NotchedClipper({
    required this.activeCenter,
    required this.notchRadius,
    required this.totalWidth,
  });

  @override
  Path getClip(Size size) {
    const double cornerRadius = 18.0;
    const double extra = 10.0;

    final path = Path();
    path.moveTo(cornerRadius, 0);

    final double notchLeft = activeCenter - notchRadius - extra;
    final double notchRight = activeCenter + notchRadius + extra;

    path.lineTo(notchLeft, 0);
    path.arcToPoint(
      Offset(notchRight, 0),
      radius: Radius.circular(notchRadius + extra * 0.5),
      clockwise: false,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_NotchedClipper old) =>
      old.activeCenter != activeCenter;
}

// ── Nav tab model ─────────────────────────────────────────────────────────────

class _NavTab {
  final String label;
  final IconData icon;
  final String path;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.path,
  });
}
