import 'package:flutter/material.dart' hide ThemeMode;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/fallback_localizations.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/app_version/presentation/widgets/version_check_wrapper.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
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

    return shadcnui.ShadcnApp.router(
      title: 'Moneko',
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localeResolutionCallback: localeResolutionCallback,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      builder: (context, child) {
        // Apply global Material theme wrapper for TextField styling
        return Theme(
          data: _getMaterialTheme(context, themeMode),
          // Never render an empty child on first frames; fallback to SplashScreen
          child: VersionCheckWrapper(child: child ?? const SplashScreen()),
        );
      },
    );
  }

  /// Get Material theme with proper input decoration for all TextFields
  ThemeData _getMaterialTheme(BuildContext context, shadcnui.ThemeMode themeMode) {
    final shadcnTheme = shadcnui.Theme.of(context);
    final colorScheme = shadcnTheme.colorScheme;
    final isDark = themeMode == shadcnui.ThemeMode.dark ||
        (themeMode == shadcnui.ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      // Global input decoration theme - applies to ALL TextField and TextFormField
      inputDecorationTheme: InputDecorationTheme(
        // Text styles
        labelStyle: TextStyle(
          fontSize: 16,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          fontSize: 16,
          color: colorScheme.mutedForeground,
          fontWeight: FontWeight.w400,
        ),
        prefixStyle: TextStyle(
          fontSize: 16,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w400,
        ),
        suffixStyle: TextStyle(
          fontSize: 16,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w400,
        ),
        // Icon theme for prefix/suffix icons
        prefixIconColor: colorScheme.foreground,
        suffixIconColor: colorScheme.foreground,
        iconColor: colorScheme.foreground,
      ),
      // Global text theme for ALL text input
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: colorScheme.foreground,
          fontWeight: FontWeight.w400,
        ),
      ),
      // Icon theme for consistency
      iconTheme: IconThemeData(
        color: colorScheme.foreground,
      ),
    );
  }
}
