import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import '../widgets/tabs/tabs.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _insightsTourController =
        SpotlightTourController(tourId: 'insights_ai_scenario_v1');
  }

  Future<void> _startInsightsTourIfNeeded(int currentTabIndex) async {
    if (currentTabIndex != 3) return;
    if (ref.read(insightsTabIndexProvider) != 0) return;
    if (ref.read(authProvider).uid.isEmpty) return;

    await _insightsTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final currentInsightsTabIndex = ref.watch(insightsTabIndexProvider);

    if (currentTabIndex == 3 && currentInsightsTabIndex == 0) {
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
          if (user.uid.isEmpty) return;
          await ref.read(analyticsProvider.notifier).loadData(user.uid);
        },
        child: SizedBox(
          width: double.infinity,
          child: MonekoTabBarView(
            tabs: [
              context.l10n.scenarioTab,
              context.l10n.runningTab,
              context.l10n.day30Tab,
              context.l10n.longTermTab,
            ],
            children: [
              _buildScenarioPlanningTabWithProvider(
                colorScheme,
                analyticsData,
                filterState.selectedCurrency,
                _insightsTourController,
              ),
              buildRunningBalanceTab(
                context,
                colorScheme,
                analyticsData,
                householdScope: householdScope,
                selectedCurrency: filterState.selectedCurrency,
              ),
              build30DayLookAheadTab(
                context,
                colorScheme,
                analyticsData,
                householdScope: householdScope,
                selectedCurrency: filterState.selectedCurrency,
              ),
              buildLongTermProjectionTab(
                context,
                colorScheme,
                analyticsData,
                householdScope: householdScope,
                selectedCurrency: filterState.selectedCurrency,
              ),
            ],
            onTabChanged: (index) {
              if (ref.read(insightsTabIndexProvider) == index) return;
              ref.read(insightsTabIndexProvider.notifier).state = index;
            },
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
    return ProviderScope(
      overrides: const [
        // Override any providers if needed
      ],
      child: buildScenarioPlanningTab(
        context,
        analyticsData,
        selectedCurrency: selectedCurrency,
        spotlightController: spotlightController,
      ),
    );
  }
}
