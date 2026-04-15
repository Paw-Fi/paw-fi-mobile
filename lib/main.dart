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
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/firebase_options.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/foundation.dart' as foundation;
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/app/startup_guard.dart';
import 'package:moneko/core/app/flutter_error_reporter.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

/// Top-level background message handler for Firebase Cloud Messaging
/// Must be a top-level function for iOS background execution
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _debugPrint('[FCM] Background message received');

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
        final exception = details.exception;
        if (shouldReportFatalFlutterError(exception)) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } else {
          FirebaseCrashlytics.instance.recordError(
            exception,
            details.stack ?? StackTrace.empty,
            reason: 'flutter_error_non_fatal',
            fatal: false,
          );
        }
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
      // FlutterErrorDetails.context is a DiagnosticsNode, not a BuildContext.
      // Keep this resilient: avoid secondary failures while rendering the error UI.
      const String route = '';

      final fid =
          'E-${now.millisecondsSinceEpoch.toRadixString(36)}-${shortFingerprint('$errorType|$topFrame')}';
      const message = 'Something went wrong. Please restart the app.';

      final diagnosticInfo = kDebugMode
          ? 'ID: $fid\nEnv: $env\nRoute: ${route.isEmpty ? '-' : route}\nType: $errorType\nTop: ${topFrame.isEmpty ? '-' : topFrame}'
          : 'ID: $fid\nEnv: $env';

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
                    diagnosticInfo,
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
        final fatal = shouldReportFatalFlutterError(error);
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: fatal,
          reason: fatal
              ? 'platform_dispatcher_fatal'
              : 'platform_dispatcher_non_fatal',
        );
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
        final fatal = shouldReportFatalFlutterError(err);
        FirebaseCrashlytics.instance.recordError(
          err,
          st,
          fatal: fatal,
          reason: fatal ? 'isolate_fatal' : 'isolate_non_fatal',
        );
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
      _debugPrint('[ERR] initApp failed');
      if (!kIsWeb) {
        FirebaseCrashlytics.instance
            .recordError(e, s, reason: 'initApp failed', fatal: false);
      }
      // Continue; router/splash will still render and can show error UI later
    }

    // Initialize Intl date formatting for the device locale
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    final localeName = intlSafeLocaleName(deviceLocale);
    try {
      intl.Intl.defaultLocale = localeName;
      await initializeDateFormatting(localeName, null);
    } catch (e, s) {
      _debugPrint('[ERR] initializeDateFormatting failed');
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
    final sharedPreferences = await runStartupStep(
      label: 'shared_preferences',
      timeout: const Duration(seconds: 10),
      action: SharedPreferences.getInstance,
      onError: (error, stack) {
        _debugPrint('[ERR] SharedPreferences init failed');
        if (!kIsWeb) {
          try {
            FirebaseCrashlytics.instance.recordError(
              error,
              stack,
              reason: 'shared_preferences_init',
              fatal: false,
            );
          } catch (_) {}
        }
      },
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.log('startup: shared_prefs_ready');
    }

    runApp(
      ProviderScope(
        overrides: [
          // Provide SharedPreferences instance to selected household provider
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          previewModeProvider.overrideWith(
            (ref) => PreviewModeNotifier(
              initiallyActive:
                  sharedPreferences.getBool(kPreviewModeActiveKey) ?? false,
            ),
          ),
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
      final fatal = shouldReportFatalFlutterError(error);
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: fatal ? 'zone_fatal' : 'zone_non_fatal',
      );
    }
  });
}
