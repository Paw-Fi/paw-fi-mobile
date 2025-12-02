import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:home_widget/home_widget.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/fallback_localizations.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
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

        // Store in global container for FCM integration
        DeepLinkContainer.deepLinkService = _deepLinkService;
        DeepLinkContainer.ref = ref;
      }
    });

    // Check for widget launch
    _checkForWidgetLaunch();
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
              WidgetLaunchAction.textInput;
        } else if (uri.host == 'camera') {
          ref.read(widgetLaunchProvider.notifier).state =
              WidgetLaunchAction.cameraInput;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deep link initialization happens post-frame to avoid early platform-channel churn
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return AdaptiveApp.router(
      routerConfig: router,
      title: 'Moneko',
      themeMode: themeMode,
      materialLightTheme: AppTheme.lightTheme(),
      materialDarkTheme: AppTheme.darkTheme(),
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppTheme.monekoPrimary,
        // Match Material light background (near-white) for all iOS scaffolds
        scaffoldBackgroundColor: AppTheme.lightBackground,
        barBackgroundColor: AppTheme.lightBackground,
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF8B70FF),
        // Match Material dark background so dark mode is consistently black-ish
        scaffoldBackgroundColor: AppTheme.darkBackground,
        barBackgroundColor: AppTheme.darkBackground,
      ),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Important!
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localeResolutionCallback: localeResolutionCallback,
      builder: (context, child) {
        // Never render an empty child on first frames; fallback to SplashScreen
        return VersionCheckWrapper(child: child ?? const SplashScreen());
      },
    );
  }
}
