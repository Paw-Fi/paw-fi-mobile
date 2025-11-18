import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
            FirebaseCrashlytics.instance.recordError(e, s, fatal: false, reason: 'deeplink_init_error');
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deep link initialization happens post-frame to avoid early platform-channel churn
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
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF8B70FF),
      ),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
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
