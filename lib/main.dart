import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/app/app.dart';
import 'package:moneko/core/app/init.dart';
import 'package:moneko/firebase_options.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:moneko/core/theme/app_theme.dart';

/// Top-level background message handler for Firebase Cloud Messaging
/// Must be a top-level function for iOS background execution
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Title: ${message.notification?.title}');
  debugPrint('🔔 Body: ${message.notification?.body}');
  debugPrint('🔔 Data: ${message.data}');

  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Handle the message (e.g., update local database, show notification)
  // Note: Don't do heavy processing here, just handle the notification
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase and Crashlytics first
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Only initialize Crashlytics on non-web platforms
    if (!kIsWeb) {
      const enableCrashlyticsInDebug =
          bool.fromEnvironment('ENABLE_CRASHLYTICS_DEBUG', defaultValue: false);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode || enableCrashlyticsInDebug);
      FirebaseCrashlytics.instance.log('startup: firebase_initialized');
    }

    // Record Flutter framework errors as fatal in Crashlytics (only on non-web)
    if (!kIsWeb) {
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        FlutterError.presentError(details);
      };
    } else {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
      };
    }

    // Show a friendly UI on build errors instead of a blank screen in release
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Record non-fatal to Crashlytics as well (only on non-web)
      if (!kIsWeb) {
        try {
          FirebaseCrashlytics.instance.recordError(
            details.exception,
            details.stack ?? StackTrace.empty,
            reason: 'ErrorWidget',
            fatal: false,
          );
        } catch (_) {}
      }

      String shortFingerprint(String s) {
        // Simple FNV-1a 32-bit hash for a short, repeatable ID
        int hash = 0x811C9DC5;
        for (final codeUnit in s.codeUnits) {
          hash ^= codeUnit;
          hash = (hash * 0x01000193) & 0xFFFFFFFF;
        }
        return hash.toRadixString(16).padLeft(8, '0');
      }

      String errorType = details.exception.runtimeType.toString();
      String topFrame = '';
      try {
        final lines =
            (details.stack ?? StackTrace.current).toString().split('\n');
        if (lines.isNotEmpty) topFrame = lines.first.trim();
      } catch (_) {}

      final now = DateTime.now();
      const env = Constants.environment;
      String route = '';
      try {
        // May throw if router not available in this context
        route = GoRouterState.of(details.context as BuildContext).uri.path;
      } catch (_) {}

      final fid =
          'E-${now.millisecondsSinceEpoch.toRadixString(36)}-${shortFingerprint('$errorType|$topFrame')}';
      const message = 'Something went wrong. Please restart the app.';

      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: AppTheme.darkBackground,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Moneko encountered an error',
                    style: TextStyle(
                        color: AppTheme.darkForeground,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.darkMutedForeground,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Minimal diagnostic info for screenshots
                  Text(
                    'ID: $fid\nEnv: $env\nRoute: ${route.isEmpty ? '-' : route}\nType: $errorType\nTop: ${topFrame.isEmpty ? '-' : topFrame}',
                    style: const TextStyle(
                      color: AppTheme.darkMutedForeground,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // Record platform dispatcher errors (only on non-web)
    if (!kIsWeb) {
      ui.PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true; // handled
      };
    }

    // Catch isolate-level errors (e.g., background isolates) - only on non-web
    if (!kIsWeb) {
      final errorPort = RawReceivePort((dynamic pair) {
        final List<dynamic> errorAndStackTrace = pair as List<dynamic>;
        final Object err = errorAndStackTrace.first as Object;
        final StackTrace st = errorAndStackTrace.last is StackTrace
            ? (errorAndStackTrace.last as StackTrace)
            : StackTrace.fromString(errorAndStackTrace.last.toString());
        FirebaseCrashlytics.instance.recordError(err, st, fatal: true);
      });
      Isolate.current.addErrorListener(errorPort.sendPort);
    }

    // Register background message handler (only on non-web)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      FirebaseCrashlytics.instance
          .log('startup: fcm_background_handler_registered');
    }

    // Initialize Supabase and other app dependencies (dotenv + Supabase)
    try {
      await initApp();
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.log('startup: supabase_initialized');
      }
    } catch (e, s) {
      debugPrint('❌ initApp failed: $e');
      debugPrint(s.toString());
      if (!kIsWeb) {
        FirebaseCrashlytics.instance
            .recordError(e, s, reason: 'initApp failed', fatal: false);
      }
      // Continue; router/splash will still render and can show error UI later
    }

    // Initialize Intl date formatting for the device locale
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    final localeName = deviceLocale.toString();
    try {
      intl.Intl.defaultLocale = localeName;
      await initializeDateFormatting(localeName, null);
    } catch (e, s) {
      debugPrint('❌ initializeDateFormatting failed for $localeName: $e');
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(
          e,
          s,
          reason: 'initializeDateFormatting',
          fatal: false,
        );
      }
      try {
        intl.Intl.defaultLocale = 'en_US';
        await initializeDateFormatting('en_US', null);
      } catch (_) {}
    }

    // Initialize SharedPreferences for persistent state
    final sharedPreferences = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('startup: shared_prefs_ready');
    }

    runApp(
      ProviderScope(
        overrides: [
          // Provide SharedPreferences instance to selected household provider
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const App(),
      ),
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('startup: runApp_called');
    }
  }, (error, stack) {
    // Record uncaught zone errors as fatal (only on non-web)
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}
