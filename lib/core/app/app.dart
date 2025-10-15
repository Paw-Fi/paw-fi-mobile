import 'package:flutter/material.dart' hide ThemeMode;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

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
        _deepLinkService.initialize(ref, context);
        _deepLinkInitialized = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Try to initialize as early as possible once context is available
    if (!_deepLinkInitialized && mounted) {
      _deepLinkService.initialize(ref, context);
      _deepLinkInitialized = true;
    }
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

    return shadcnui.ShadcnApp.router(
      title: 'Moneko',
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}