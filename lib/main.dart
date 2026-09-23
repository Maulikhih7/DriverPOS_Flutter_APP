import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/logging/app_logger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/notification_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // File logging first so every startup step (including a Firebase
    // failure below) lands in the persisted log, not just the console.
    await AppLogger.instance.init();

    // Route framework errors (widget build/layout/paint errors) through the
    // same zone handler instead of letting an uncaught one hard-crash.
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      AppLogger.instance.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    // Errors from outside the Flutter framework's build/layout/paint zone
    // (e.g. platform channel callbacks) don't go through FlutterError.onError.
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.instance.e('PlatformDispatcher', 'Uncaught platform error', error, stack);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    GoogleFonts.config.allowRuntimeFetching = false;

    // A Firebase/notification init failure shouldn't block app launch —
    // cash/check payments and most of the app don't depend on it.
    try {
      await Firebase.initializeApp();
      await NotificationService.instance.init();
      AppLogger.instance.i('Startup', 'Firebase + notifications initialized');
    } catch (e, st) {
      AppLogger.instance.w('Startup', 'Startup init failed (continuing without it)', e, st);
    }

    runApp(const ProviderScope(child: GolfPosApp()));
  }, (error, stack) {
    AppLogger.instance.e('Zone', 'Uncaught zone error', error, stack);
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class GolfPosApp extends ConsumerWidget {
  const GolfPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DriverPOS IO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
