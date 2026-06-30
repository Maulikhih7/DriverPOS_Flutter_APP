import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/payment/checkout_screen.dart';
import '../../screens/pos/hold_carts_screen.dart';
import '../../screens/pos/pos_screen.dart';
import '../../screens/pos/refund_screen.dart';
import '../../screens/settings/dvpaylite_settings_screen.dart';
import '../../screens/settings/terminal_settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/tee_sheet/tee_sheet_screen.dart';
import '../../screens/transactions/transactions_screen.dart';
import '../../widgets/main_shell.dart';

// Bridges Riverpod auth state changes into go_router's ChangeNotifier refresh
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 220),
}) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      final loc = state.matchedLocation;

      // Always let splash render itself — it will navigate after its timer
      if (loc == '/splash') return null;

      if (!isAuthenticated && loc != '/login') return '/login';
      if (isAuthenticated && loc == '/login') return '/tee-sheet';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _fadePage(
            key: state.pageKey,
            child: CheckoutScreen(
              total: (extra['total'] as num).toDouble(),
              subtotal: (extra['subtotal'] as num).toDouble(),
              tax: (extra['tax'] as num).toDouble(),
              customerId: extra['customerId'] as String,
              customerName: extra['customerName'] as String,
              discountAmount: extra['discountAmount'] != null
                  ? (extra['discountAmount'] as num).toDouble()
                  : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/terminal-settings',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const TerminalSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/dvpay-settings',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const DvPayLiteSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/refund',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const RefundScreen(),
        ),
      ),
      GoRoute(
        path: '/hold-orders',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const HoldCartsScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/pos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PosScreen(),
            ),
          ),
          GoRoute(
            path: '/tee-sheet',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeeSheetScreen(),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransactionsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
