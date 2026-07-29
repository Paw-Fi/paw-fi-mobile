import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:home_widget/home_widget.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/fallback_localizations.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/app_version/presentation/widgets/version_check_wrapper.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/pages/app_lock_page.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_visual_shell.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/ai_share_intent_listener.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/core/ui/pages/splash_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _deepLinkInitialized = false;
  bool _shouldObscureForLifecycle = false;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        debugPrint('[OnboardingAnalytics] app lifecycle state=$state');
        final skipAppLockForImagePicker = isImagePickerActive;
        if (state == AppLifecycleState.resumed) {
          if (!skipAppLockForImagePicker) {
            ref.read(appLockControllerProvider.notifier).handleResumed();
          }
          _setLifecycleObscured(false);
          unawaited(
            ref.read(subscriptionManagementProvider.notifier).refresh(),
          );
          unawaited(_syncPendingIosWalletCapturesOnResume());
          unawaited(_syncPendingAndroidNotificationCapturesOnResume());
        } else if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          if (!skipAppLockForImagePicker && _shouldUseLifecyclePrivacyCover()) {
            _setLifecycleObscured(true);
          }
          if (!skipAppLockForImagePicker) {
            ref.read(appLockControllerProvider.notifier).markBackgrounded();
          }
        }
        unawaited(
          ref.read(onboardingFlowAnalyticsServiceProvider).handleLifecycleState(
                state,
              ),
        );
      },
    );
    // Initialize deep link service immediately to catch cold start links
    // Context will be available after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_deepLinkInitialized && mounted) {
        try {
          _deepLinkService.initialize(ref, context);
        } catch (e, s) {
          try {
            FirebaseCrashlytics.instance
                .recordError(e, s, fatal: false, reason: 'deeplink_init_error');
          } catch (_) {}
          debugPrint('DeepLink initialization error: $e');
          debugPrint(s.toString());
        }
        _deepLinkInitialized = true;
      }
    });

    // Check for widget launch
    _checkForWidgetLaunch();
    _widgetClickSubscription ??=
        HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  bool _shouldUseLifecyclePrivacyCover() {
    if (kIsWeb) {
      return false;
    }
    if (ref.read(authProvider).isEmpty) {
      return false;
    }
    return ref.read(appLockControllerProvider).isConfigured;
  }

  void _setLifecycleObscured(bool value) {
    if (!mounted || _shouldObscureForLifecycle == value) {
      return;
    }
    setState(() {
      _shouldObscureForLifecycle = value;
    });
  }

  void _checkForWidgetLaunch() {
    HomeWidget.setAppGroupId('group.moneko.mobile');
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  Future<void> _syncPendingIosWalletCapturesOnResume() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null ||
        Constants.supabaseUrl.isEmpty ||
        Constants.supabaseAnon.isEmpty) {
      return;
    }

    try {
      await SiriShortcutAuthService.instance
          .syncAuthContextAndPendingWalletCaptures(
        supabaseUrl: Constants.supabaseUrl,
        supabaseAnonKey: Constants.supabaseAnon,
        accessToken: session.accessToken,
        userId: session.user.id,
        expiresAt: session.expiresAt,
      );
    } on MissingPluginException {
      return;
    } catch (error, stackTrace) {
      try {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: false,
          reason: 'ios_wallet_pending_resume_sync_error',
        );
      } catch (_) {}
    }
  }

  Future<void> _syncPendingAndroidNotificationCapturesOnResume() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.isExpired) return;

    try {
      await NotificationCaptureService.instance.syncAuthContext(
        supabaseUrl: Constants.supabaseUrl,
        supabaseAnonKey: Constants.supabaseAnon,
        accessToken: session.accessToken,
        userId: session.user.id,
        expiresAt: session.expiresAt ?? 0,
      );
      await NotificationCaptureService.instance.syncPendingCaptures();
    } on MissingPluginException {
      return;
    } catch (error, stackTrace) {
      try {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: false,
          reason: 'android_notification_pending_resume_sync_error',
        );
      } catch (_) {}
    }
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      debugPrint('🚀 Launched from widget: $uri');
      if (uri.scheme == 'moneko') {
        if (uri.host == 'text') {
          ref.read(widgetLaunchProvider.notifier).state =
              const WidgetLaunchEvent(type: WidgetLaunchActionType.textInput);
        } else if (uri.host == 'camera') {
          ref.read(widgetLaunchProvider.notifier).state =
              const WidgetLaunchEvent(type: WidgetLaunchActionType.cameraInput);
        } else if (uri.host == 'configure_widget') {
          final widgetId = uri.queryParameters['widgetId'];
          if (widgetId != null) {
            ref.read(widgetLaunchProvider.notifier).state = WidgetLaunchEvent(
              type: WidgetLaunchActionType.configure,
              params: {'widgetId': widgetId},
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    _widgetClickSubscription?.cancel();
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    //final themeMode=ThemeMode.dark;
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authProvider);
    final appLockState = ref.watch(appLockControllerProvider);
    final shouldShowAppLockOverlay =
        !kIsWeb && !auth.isEmpty && appLockState.shouldBlockApp;
    final shouldShowLifecyclePrivacyCover = !shouldShowAppLockOverlay &&
        _shouldObscureForLifecycle &&
        !kIsWeb &&
        !auth.isEmpty &&
        appLockState.isConfigured;
    final localizationsDelegates = <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      const FallbackMaterialLocalizationDelegate(),
      const FallbackCupertinoLocalizationDelegate(),
    ];

    return AdaptiveApp.router(
      routerConfig: router,
      title: 'Moneko',
      themeMode: themeMode,
      materialLightTheme: AppTheme.lightTheme(),
      materialDarkTheme: AppTheme.darkTheme(),
      cupertinoLightTheme: AppTheme.cupertinoLightTheme(),
      cupertinoDarkTheme: AppTheme.cupertinoDarkTheme(),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localeResolutionCallback: localeResolutionCallback,
      builder: (context, child) {
        final brightness = themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context)
            : (themeMode == ThemeMode.dark
                ? Brightness.dark
                : Brightness.light);
        final themeData = brightness == Brightness.dark
            ? AppTheme.darkTheme()
            : AppTheme.lightTheme();
        final colorScheme = themeData.colorScheme;
        final overlayStyle = colorScheme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

        // Never render an empty child on first frames; fallback to SplashScreen
        return Theme(
          data: themeData,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle.copyWith(
              statusBarColor: colorScheme.surface.withValues(alpha: 0.0),
            ),
            child: Localizations.override(
              context: context,
              locale: locale,
              delegates: localizationsDelegates,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AiShareIntentListener(
                    child: VersionCheckWrapper(
                      child: child ?? const SplashScreen(),
                    ),
                  ),
                  if (shouldShowLifecyclePrivacyCover)
                    const _AppLifecyclePrivacyCover(),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        if (child.key == const ValueKey('app-lock-overlay')) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0, -1),
                            end: Offset.zero,
                          ).animate(animation);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      child: shouldShowAppLockOverlay
                          ? AppLockPage(
                              key: const ValueKey('app-lock-overlay'),
                              onUnlocked: () => _setLifecycleObscured(false),
                              renderAsOverlay: true,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('app-lock-empty')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppLifecyclePrivacyCover extends StatelessWidget {
  const _AppLifecyclePrivacyCover();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: AppLockBackground(child: SizedBox.expand()),
    );
  }
}
