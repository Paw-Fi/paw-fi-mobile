import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:moneko/core/theme/theme.dart'; // Unnecessary (covered by core.dart)

import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';

import 'package:moneko/features/home/presentation/state/state.dart';

import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/home_page_command_provider.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/thai_language_prompt_logic.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/home/presentation/widgets/mom_trend_bar.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/services/preferred_language_sync_service.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_banner.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_lazy_widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

// ============================================================================
// HOME PAGE
// ============================================================================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hasCompletedThaiLanguagePromptCheck = false;
  bool _isCheckingThaiLanguagePrompt = false;

  late final SpotlightTourController _fabTourController;
  late final ProviderSubscription<HomePageCommand?>
      _homePageCommandSubscription;
  late final HomeDebugTrace _homeTrace;
  String? _lastHomeDebugSignature;
  String? _lastHomePerfSignature;
  String? _lastPersonalRepoSignature;
  String? _lastPersonalDashboardSignature;
  bool _didLogFirstUsefulPaint = false;

  static const bool _enableDebugLogs =
      bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);
  static const double _dashboardScrollCacheExtent = 1600;

  void _debugPrint(String? message, {int? wrapWidth}) {
    if (foundation.kDebugMode && _enableDebugLogs) {
      foundation.debugPrint(message, wrapWidth: wrapWidth);
    }
  }

  @override
  void initState() {
    super.initState();

    _fabTourController = ref.read(homeSpotlightControllerProvider);
    _homeTrace = HomeDebugTrace(
      label: 'HomePageOpen',
      enabled: ref.read(homeDebugLoggingEnabledProvider),
      logSink: ref.read(homeDebugLogSinkProvider),
    );
    _homeTrace.mark('page-mounted');

    // Initialize filters on first mount
    // NOTE: Analytics data is loaded by app_initialization_provider - no need to trigger here
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final isPreview = ref.read(previewModeProvider).isActive;
      if (isPreview) {
        final preferredCurrency =
            PreviewMockData.contact.preferredCurrency?.toUpperCase();
        if (preferredCurrency != null && preferredCurrency.isNotEmpty) {
          ref
              .read(homeFilterProvider.notifier)
              .bootstrapSelectedCurrency(preferredCurrency);
        }
      }
      // Initialize date range filter from local storage
    });

    _homePageCommandSubscription = ref.listenManual<HomePageCommand?>(
      homePageCommandProvider,
      (previous, next) {
        if (next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!identical(ref.read(homePageCommandProvider), next)) return;
          ref.read(homePageCommandProvider.notifier).state = null;
          unawaited(_handleHomePageCommand(next));
        });
      },
      fireImmediately: true,
    );
  }

  void _maybeLogHomeDebugSnapshot({
    required HouseholdScope householdScope,
    required Set<String> portfolioHouseholdIds,
    required String? selectedCurrency,
  }) {
    if (!_enableDebugLogs) return;
    final selected = ref.read(selectedHouseholdProvider);
    final selectedHouseholdId =
        selected.householdId ?? selected.household?.id ?? 'null';
    final selectedHouseholdName = selected.household?.name ?? 'null';

    final signature = [
      'vm=${householdScope.viewMode}',
      'selected=$selectedHouseholdId',
      'portfolios=${portfolioHouseholdIds.length}',
      'cur=${selectedCurrency ?? "null"}',
      'portfolioIds=${portfolioHouseholdIds.length}',
    ].join('|');

    if (_lastHomeDebugSignature == signature) return;
    _lastHomeDebugSignature = signature;

    _debugPrint('🧭 [HomePageDebug] ===== Snapshot =====');
    _debugPrint('🧭 [HomePageDebug] viewMode=${householdScope.viewMode}');
    _debugPrint(
        '🧭 [HomePageDebug] selectedHouseholdId=$selectedHouseholdId name=$selectedHouseholdName');
    _debugPrint(
        '🧭 [HomePageDebug] isPortfolioSelected=${householdScope.isPortfolioSelected}');
    _debugPrint(
        '🧭 [HomePageDebug] isHouseholdView=${householdScope.isHouseholdView}');
    _debugPrint(
        '🧭 [HomePageDebug] portfolioHouseholdIds(${portfolioHouseholdIds.length})=$portfolioHouseholdIds');
    _debugPrint(
        '🧭 [HomePageDebug] selectedCurrency=${selectedCurrency ?? "null"}');
    _debugPrint('🧭 [HomePageDebug] ====================');
  }

  void _scheduleThaiLanguagePromptCheck(UserContact? contact) {
    if (_hasCompletedThaiLanguagePromptCheck || _isCheckingThaiLanguagePrompt) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _hasCompletedThaiLanguagePromptCheck ||
          _isCheckingThaiLanguagePrompt) {
        return;
      }

      unawaited(_maybeShowThaiLanguagePrompt(contact));
    });
  }

  Future<void> _maybeShowThaiLanguagePrompt(UserContact? contact) async {
    if (_hasCompletedThaiLanguagePromptCheck || _isCheckingThaiLanguagePrompt) {
      return;
    }

    if (ref.read(previewModeProvider).isActive) {
      _hasCompletedThaiLanguagePromptCheck = true;
      return;
    }

    _isCheckingThaiLanguagePrompt = true;

    try {
      final currentLocale = Localizations.localeOf(context);
      final route = ModalRoute.of(context);
      final authUserId = ref.read(authProvider).uid;
      final promptScopeId = authUserId.isNotEmpty
          ? authUserId
          : (contact?.userId?.trim().isNotEmpty == true
              ? contact!.userId!.trim()
              : contact?.id ?? 'anonymous');
      final prefs = ref.read(sharedPreferencesProvider);
      final checkedPrefsKey =
          thaiLanguagePromptCheckedPrefsKeyForUser(promptScopeId);
      final decision = evaluateThaiLanguagePrompt(
        hasChecked: prefs.getBool(checkedPrefsKey) ?? false,
        contact: contact,
        currentLocale: currentLocale,
      );

      switch (decision.action) {
        case ThaiLanguagePromptAction.waitForContact:
          return;
        case ThaiLanguagePromptAction.skipForNow:
          _hasCompletedThaiLanguagePromptCheck = true;
          return;
        case ThaiLanguagePromptAction.markCheckedAndSkip:
          await prefs.setBool(checkedPrefsKey, true);
          _hasCompletedThaiLanguagePromptCheck = true;
          return;
        case ThaiLanguagePromptAction.showPrompt:
          break;
      }

      if (!mounted || route == null || !route.isCurrent) {
        return;
      }

      final result = await MonekoAlertDialog.show(
        context: context,
        title: 'สวัสดี!',
        description:
            'ตอนนี้ Moneko รองรับภาษาไทยแล้วนะ อยากเปลี่ยนแอปเป็นภาษาไทยเลยไหม',
        confirmLabel: 'เปลี่ยนเป็นภาษาไทย',
        cancelLabel: 'ไว้ก่อน',
      );

      await prefs.setBool(checkedPrefsKey, true);
      _hasCompletedThaiLanguagePromptCheck = true;

      if (result?.confirmed != true || !mounted) {
        return;
      }

      const thaiLocale = Locale('th');
      await ref.read(localeProvider.notifier).setLocale(thaiLocale);

      final userId = ref.read(authProvider).uid;
      if (userId.isEmpty) {
        return;
      }

      await ref.read(preferredLanguageSyncServiceProvider).syncForUserSafely(
            userId: userId,
            locale: normalizeAppLocale(thaiLocale),
            force: true,
          );
    } finally {
      _isCheckingThaiLanguagePrompt = false;
    }
  }

  @override
  void dispose() {
    _homePageCommandSubscription.close();
    super.dispose();
  }

  Future<void> _handleHomePageCommand(HomePageCommand command) async {
    if (!mounted) return;
    switch (command.type) {
      case HomePageCommandType.showLogExpenseDrawer:
      case HomePageCommandType.showAiTextInputDrawer:
        await handleAiFreeFormText(context, ref);
        return;
      case HomePageCommandType.captureAiReceipt:
        await handleAiCameraCapture(context, ref);
        return;
    }
  }

  Future<void> _startFabTourIfNeeded() async {
    final user = ref.read(authProvider);
    if (user.isEmpty) return;

    final location = GoRouterState.of(context).uri.path;
    if (location != '/dashboard') return;

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    await _fabTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ref.watch(userCategoryConfigProvider);
    final initUserContact = ref
        .watch(appInitializationV2Provider.select((state) => state.data?.user));
    final filterState = ref.watch(homeFilterProvider);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final householdScope = ref.watch(householdScopeProvider);
    final portfolioHouseholdIds = householdScope.portfolioHouseholdIds;

    // Global currency remains shared; date ranges move to per-card filters
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final shouldShowFab = _shouldShowFAB(householdScope, householdsAsync);

    final homePerfSignature = [
      'scope=${householdScope.activeAccountType.name}',
      'householdsLoading=${householdsAsync.isLoading}',
      'householdsHasError=${householdsAsync.hasError}',
      'householdsCount=${householdsAsync.valueOrNull?.length ?? 0}',
      'shouldShowFab=$shouldShowFab',
      'selectedCurrency=${selectedCurrency ?? '<none>'}',
      'user=${user.uid.isEmpty ? '<empty>' : user.uid}',
    ].join('|');
    if (_lastHomePerfSignature != homePerfSignature) {
      _lastHomePerfSignature = homePerfSignature;
      _homeTrace.mark('page-state', {
        'scope': householdScope.activeAccountType.name,
        'householdsLoading': householdsAsync.isLoading,
        'householdsHasError': householdsAsync.hasError,
        'householdsCount': householdsAsync.valueOrNull?.length,
        'shouldShowFab': shouldShowFab,
        'selectedCurrency': selectedCurrency,
        'user': user.uid.isEmpty ? '<empty>' : user.uid,
      });
    }

    _maybeLogHomeDebugSnapshot(
      householdScope: householdScope,
      portfolioHouseholdIds: portfolioHouseholdIds,
      selectedCurrency: selectedCurrency,
    );

    const isInitialAnalyticsLoading = false;

    _scheduleThaiLanguagePromptCheck(initUserContact);

    if (!_didLogFirstUsefulPaint &&
        !isInitialAnalyticsLoading &&
        (!householdScope.isHouseholdView || !householdsAsync.isLoading)) {
      _didLogFirstUsefulPaint = true;
      _homeTrace.mark('first-useful-paint', {
        'scope': householdScope.activeAccountType.name,
        'selectedCurrency': selectedCurrency,
      });
    }

    if (shouldShowFab && !user.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startFabTourIfNeeded();
      });
    }

    final scrollView = CustomScrollView(
      key: PageStorageKey<String>(
        'home_page_${householdScope.activeAccountType.name}_${householdScope.activeAccountHouseholdId ?? 'personal'}',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: _dashboardScrollCacheExtent,
      slivers: [
        if (householdScope.isHouseholdView) ...[
          const HouseholdHomeContent(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ] else ...[
          // Personal mode - show customizable dashboard
          const SliverToBoxAdapter(child: ConnectSocialBanner()),
          Consumer(
            builder: (context, ref, _) {
              final repoAsync = ref.watch(dashboardRepositoryFutureProvider);
              final repoSignature = [
                'loading=${repoAsync.isLoading}',
                'hasError=${repoAsync.hasError}',
                'hasValue=${repoAsync.hasValue}',
              ].join('|');
              if (_lastPersonalRepoSignature != repoSignature) {
                _lastPersonalRepoSignature = repoSignature;
                _homeTrace.mark('personal-repository-async-state', {
                  'loading': repoAsync.isLoading,
                  'hasError': repoAsync.hasError,
                  'hasValue': repoAsync.hasValue,
                });
              }

              return repoAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child:
                      Text('${context.l10n.errorInitializingRepository}: $e'),
                ),
                data: (_) {
                  final dashboardContact =
                      ref.watch(dashboardUserContactProvider).valueOrNull;
                  final dashboardBudgets =
                      ref.watch(dashboardPersonalBudgetsProvider).valueOrNull ??
                          const <DailyBudgetEntry>[];
                  final selectedCurrencyFilter = selectedCurrency;
                  final timezoneOffsetMinutes =
                      resolveUserTimezoneOffsetMinutes(
                    dashboardContact?.preferredTimezone,
                  );
                  final userNow =
                      userNowFromOffsetMinutes(timezoneOffsetMinutes);
                  final netFilterState = ref.watch(
                    cardDateFilterProvider(HomeCardFilterId.netCashflow),
                  );
                  final netRange = getDateRangeFromFilter(
                    netFilterState.dateRangeFilter,
                    netFilterState.customStartDate,
                    netFilterState.customEndDate,
                    now: userNow,
                  );
                  final netFrom = netRange['from']!;
                  final netTo = netRange['to']!;
                  final netBudgets = dashboardBudgets.where((budget) {
                    final d = DateTime(
                        budget.date.year, budget.date.month, budget.date.day);
                    final dateOk = !d.isBefore(netFrom) && !d.isAfter(netTo);
                    final currencyOk = selectedCurrencyFilter == null ||
                        (budget.currency?.toUpperCase() ==
                            selectedCurrencyFilter);
                    return dateOk && currencyOk;
                  }).toList();
                  final dashboardAsync =
                      ref.watch(personalDashboardProvider(user.uid));
                  final dashboardSignature = [
                    'loading=${dashboardAsync.isLoading}',
                    'hasError=${dashboardAsync.hasError}',
                    'hasValue=${dashboardAsync.hasValue}',
                    'count=${dashboardAsync.valueOrNull?.length ?? 0}',
                  ].join('|');
                  if (_lastPersonalDashboardSignature != dashboardSignature) {
                    _lastPersonalDashboardSignature = dashboardSignature;
                    _homeTrace.mark('personal-dashboard-async-state', {
                      'loading': dashboardAsync.isLoading,
                      'hasError': dashboardAsync.hasError,
                      'hasValue': dashboardAsync.hasValue,
                      'widgetCount': dashboardAsync.valueOrNull?.length,
                    });
                  }

                  return dashboardAsync.when(
                    loading: () => const SliverToBoxAdapter(
                        child: SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()))),
                    error: (e, st) => SliverToBoxAdapter(
                        child:
                            Text('${context.l10n.errorLoadingDashboard}: $e')),
                    data: (configs) {
                      return DraggableDashboardList(
                        configs: configs,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .reorder(oldIndex, newIndex);
                        },
                        onToggleVisibility: (id) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .toggleVisibility(id);
                        },
                        onUpdateConfig: (id,
                            {dateRange, viewMode, start, end}) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .updateConfig(id,
                                  dateRange: dateRange,
                                  viewMode: viewMode,
                                  start: start,
                                  end: end);
                        },
                        widgetBuilders: {
                          DashboardWidgetType.spendingSummary:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardSpendingSummaryCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      contact: dashboardContact,
                                      userNow: userNow,
                                    ),
                                  ),
                          DashboardWidgetType.netCashflow: (context, config) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: SizedBox(
                                  height: 180,
                                  child: Row(
                                    children: [
                                      const Expanded(child: MoMTrendBar()),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: LazyDashboardNetCashflowCard(
                                          config: config,
                                          colorScheme: colorScheme,
                                          contact: dashboardContact,
                                          userNow: userNow,
                                          budgets: netBudgets,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          DashboardWidgetType.financialCalendar:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardFinancialCalendarCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      fallbackCurrency: selectedCurrency ??
                                          dashboardContact?.preferredCurrency ??
                                          'USD',
                                    ),
                                  ),
                          DashboardWidgetType.recentTransactions:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardRecentTransactionsCard(
                                      colorScheme: colorScheme,
                                      contact: dashboardContact,
                                    ),
                                  ),
                          DashboardWidgetType.spendingBreakdownChart:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardSpendingBreakdownCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      userNow: userNow,
                                    ),
                                  ),
                          DashboardWidgetType.whereTheMoneyWent:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardWhereTheMoneyWentCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      userNow: userNow,
                                    ),
                                  ),
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          // Edit Button
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ], // end of else block for Personal mode
      ],
    );

    final scrollContent = householdScope.isPersonalView
        ? Skeletonizer(
            enabled: isInitialAnalyticsLoading,
            effect: ShimmerEffect(
              baseColor: colorScheme.skeletonBase,
              highlightColor: colorScheme.skeletonHighlight,
            ),
            child: scrollView,
          )
        : scrollView;

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              final user = ref.read(authProvider);
              if (user.uid.isEmpty) return;

              if (!ref.read(previewModeProvider).isActive) {
                try {
                  await ref
                      .read(transactionsFeedServiceProvider)
                      .refreshFromRemote(
                        dashboardTransactionsQuery(
                          DashboardScopeQuery(
                            userId: user.uid,
                            householdId: householdScope.activeAccountType ==
                                    ActiveWalletType.personal
                                ? null
                                : householdScope.activeAccountHouseholdId,
                            selectedCurrency: selectedCurrency,
                            startDate: null,
                            endDate: null,
                          ),
                          pageSize: 120,
                        ),
                      );
                  ref
                      .read(transactionsFeedRefreshSignalProvider.notifier)
                      .state += 1;
                } catch (_) {}
              }

              // Refresh based on current view mode
              if (householdScope.isHouseholdView) {
                final householdId = householdScope.activeAccountHouseholdId;
                _debugPrint('🔄 Pull-to-refresh: Refreshing household data');
                if (householdId != null && householdId.isNotEmpty) {
                  ref
                      .read(cacheInvalidatorProvider)
                      .invalidateHouseholdData(householdId);
                }
              } else {
                await ref.read(analyticsProvider.notifier).loadData(user.uid);
              }

              ref.read(dashboardRefreshSignalProvider.notifier).state += 1;

              // Keep other tabs and selectors consistent.
              ref.invalidate(currencyTransactionCountsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: scrollContent,
          ),
        ],
      ),
      floatingActionButton: _shouldShowFAB(householdScope, householdsAsync)
          ? SpotlightTarget(
              controller: _fabTourController,
              id: 'home_unified_fab',
              title: context.l10n.homeFabTourTitle,
              description: context.l10n.homeFabTourDescription,
              placement: SpotlightPlacement.top,
              padding: 6,
              borderRadius: 34,
              child: const Padding(
                padding: EdgeInsets.all(0),
                child: HomeAiExpandableFab(),
              ),
            )
          : null,
    ));
  }

  /// Determine if FAB should be shown
  /// Hide FAB when in household mode with no households (showing onboarding)
  bool _shouldShowFAB(
    HouseholdScope scope,
    AsyncValue<List<Household>> householdsAsync,
  ) {
    // Always show FAB in personal mode (includes portfolios).
    if (scope.isPersonalView) {
      return true;
    }

    // In household mode, hide FAB if households are empty (showing onboarding).
    return householdsAsync.maybeWhen(
      data: (households) => households.isNotEmpty,
      orElse: () => true, // Show FAB during loading or error states
    );
  }

  // Global date helpers have been removed; per-card filters now own all
  // date-range logic, and analytics loads all-time data.
}
