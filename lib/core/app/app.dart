import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/fallback_localizations.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/app_version/presentation/widgets/version_check_wrapper.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/core/ui/pages/splash_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _deepLinkInitialized = false;
  StreamSubscription<Uri?>? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
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

  void _checkForWidgetLaunch() {
    HomeWidget.setAppGroupId('group.moneko.mobile');
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
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
    _widgetClickSubscription?.cancel();
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
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
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        applyThemeToAll: true,
        primaryColor: AppTheme.monekoPrimary,
        primaryContrastingColor: AppTheme.lightButtonText,
        // Match Material light background (near-white) for all iOS scaffolds
        scaffoldBackgroundColor: AppTheme.lightBackground,
        barBackgroundColor: AppTheme.lightBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppTheme.monekoPrimary,
          navActionTextStyle: TextStyle(color: AppTheme.monekoPrimary),
          navTitleTextStyle: TextStyle(color: AppTheme.lightForeground),
          textStyle: TextStyle(color: AppTheme.lightForeground),
        ),
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        applyThemeToAll: true,
        primaryColor: AppTheme.darkPrimary,
        primaryContrastingColor: AppTheme.darkButtonText,
        // Match Material dark background so dark mode is consistently black-ish
        scaffoldBackgroundColor: AppTheme.darkBackground,
        barBackgroundColor: AppTheme.darkBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppTheme.darkPrimary,
          navActionTextStyle: TextStyle(color: AppTheme.darkPrimary),
          navTitleTextStyle: TextStyle(color: AppTheme.darkForeground),
          textStyle: TextStyle(color: AppTheme.darkForeground),
        ),
      ),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localeResolutionCallback: localeResolutionCallback,
      builder: (context, child) {
        // Never render an empty child on first frames; fallback to SplashScreen
        return Localizations.override(
          context: context,
          locale: locale,
          delegates: localizationsDelegates,
          child: VersionCheckWrapper(child: child ?? const SplashScreen()),
        );
      },
    );
  }
}
