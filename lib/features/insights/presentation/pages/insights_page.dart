import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'monthly_report_page.dart';
import '../widgets/tabs/tabs.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';

// ============================================================================
// ADVANCED ANALYTICS PAGE
// ============================================================================

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

final insightsTabIndexProvider = StateProvider<int>((ref) => 0);

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  late final SpotlightTourController _insightsTourController;
  int? _lastHandledTransactionRefreshSignal;
  int? _lastHandledDashboardRefreshSignal;

  @override
  void initState() {
    super.initState();
    _insightsTourController =
        SpotlightTourController(tourId: 'insights_ai_scenario_v1');
  }

  Future<void> _startInsightsTourIfNeeded(int currentTabIndex) async {
    if (currentTabIndex != 4) return;
    if (ref.read(insightsTabIndexProvider) != 0) return;
    if (ref.read(authProvider).uid.isEmpty) return;

    await _insightsTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final analyticsData = ref.watch(analyticsProvider);
    final transactionRefreshSignal =
        ref.watch(transactionsFeedRefreshSignalProvider);
    final dashboardRefreshSignal = ref.watch(dashboardRefreshSignalProvider);
    final filterState = ref.watch(homeFilterProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final activeHouseholdId =
        householdScope.activeAccountType == ActiveWalletType.personal
            ? null
            : householdScope.activeAccountHouseholdId;
    final activeScopeOptimisticExpenses = ref.watch(
      householdOptimisticExpensesProvider.select(
        (state) => (activeHouseholdId == null || activeHouseholdId.isEmpty)
            ? const <ExpenseEntry>[]
            : state[activeHouseholdId] ?? const <ExpenseEntry>[],
      ),
    );
    final activeScopeDeletedExpenseIds = ref.watch(
      householdOptimisticDeletedExpenseIdsProvider.select(
        (state) => (activeHouseholdId == null || activeHouseholdId.isEmpty)
            ? const <String>{}
            : state[activeHouseholdId] ?? const <String>{},
      ),
    );

    final scopedAnalyticsData = activeScopeOptimisticExpenses.isEmpty &&
            activeScopeDeletedExpenseIds.isEmpty
        ? analyticsData
        : analyticsData.copyWith(
            expenses: mergeHouseholdExpenses(
              analyticsData.expenses,
              activeScopeOptimisticExpenses,
              deletedIds: activeScopeDeletedExpenseIds,
            ),
            allExpenses: mergeHouseholdExpenses(
              analyticsData.allExpenses,
              activeScopeOptimisticExpenses,
              deletedIds: activeScopeDeletedExpenseIds,
            ),
          );
    final currentInsightsTabIndex = ref.watch(insightsTabIndexProvider);
    final preview = ref.watch(previewModeProvider);

    if (!preview.isActive && auth.uid.isNotEmpty) {
      final shouldHydratePendingLocalRows =
          _lastHandledTransactionRefreshSignal != transactionRefreshSignal ||
              _lastHandledDashboardRefreshSignal != dashboardRefreshSignal;
      if (shouldHydratePendingLocalRows) {
        _lastHandledTransactionRefreshSignal = transactionRefreshSignal;
        _lastHandledDashboardRefreshSignal = dashboardRefreshSignal;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(analyticsProvider.notifier).hydrateFromLocalCache(
                auth.uid,
                householdId: activeHouseholdId,
              );
        });
      }
    }

    if (!preview.isActive &&
        auth.uid.isNotEmpty &&
        analyticsData.hasLoadedOnce != true &&
        !analyticsData.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(analyticsProvider.notifier).loadData(auth.uid);
      });
    }

    // Ensure analytics is loaded in preview even without auth
    if (preview.isActive &&
        analyticsData.allExpenses.isEmpty &&
        !analyticsData.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final userId = auth.uid.isNotEmpty
            ? auth.uid
            : (PreviewMockData.contact.userId ?? 'preview-user');
        ref.read(analyticsProvider.notifier).loadData(userId);
      });
    }

    if (currentTabIndex == 4 && currentInsightsTabIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startInsightsTourIfNeeded(currentTabIndex);
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(authProvider);
          final userId = user.uid.isNotEmpty
              ? user.uid
              : (preview.isActive
                  ? PreviewMockData.contact.userId ?? 'preview-user'
                  : '');
          if (userId.isEmpty) return;
          await ref.read(analyticsProvider.notifier).loadData(userId);
        },
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: MonekoTabBarView(
                  tabs: [
                    context.l10n.scenarioTab,
                    context.l10n.runningTab,
                    context.l10n.day30Tab,
                    context.l10n.longTermTab,
                    'Health',
                  ],
                  children: [
                    _buildLazyInsightsTab(
                      index: 0,
                      activeIndex: currentInsightsTabIndex,
                      buildChild: () => _buildScenarioPlanningTabWithProvider(
                        colorScheme,
                        scopedAnalyticsData,
                        filterState.selectedCurrency,
                        _insightsTourController,
                      ),
                    ),
                    _buildLazyInsightsTab(
                      index: 1,
                      activeIndex: currentInsightsTabIndex,
                      buildChild: () => buildRunningBalanceTab(
                        context,
                        colorScheme,
                        scopedAnalyticsData,
                        householdScope: householdScope,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                    _buildLazyInsightsTab(
                      index: 2,
                      activeIndex: currentInsightsTabIndex,
                      buildChild: () => build30DayLookAheadTab(
                        context,
                        colorScheme,
                        scopedAnalyticsData,
                        householdScope: householdScope,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                    _buildLazyInsightsTab(
                      index: 3,
                      activeIndex: currentInsightsTabIndex,
                      buildChild: () => buildLongTermProjectionTab(
                        context,
                        colorScheme,
                        scopedAnalyticsData,
                        householdScope: householdScope,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                    _buildLazyInsightsTab(
                      index: 4,
                      activeIndex: currentInsightsTabIndex,
                      buildChild: () => const MonthlyReportPage(),
                    ),
                  ],
                  onTabChanged: (index) {
                    if (ref.read(insightsTabIndexProvider) == index) return;
                    ref.read(insightsTabIndexProvider.notifier).state = index;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioPlanningTabWithProvider(
    ColorScheme colorScheme,
    AnalyticsData analyticsData,
    String? selectedCurrency,
    SpotlightTourController spotlightController,
  ) {
    return buildScenarioPlanningTab(
      context,
      analyticsData,
      selectedCurrency: selectedCurrency,
      spotlightController: spotlightController,
    );
  }

  Widget _buildLazyInsightsTab({
    required int index,
    required int activeIndex,
    required Widget Function() buildChild,
  }) {
    if (index != activeIndex) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(child: buildChild());
  }
}
