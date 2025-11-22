import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import '../widgets/tabs/tabs.dart';
import 'package:moneko/core/theme/app_theme.dart';

// ============================================================================
// ADVANCED ANALYTICS PAGE
// ============================================================================

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: RefreshIndicator(
        onRefresh: () async {
          // Analytics data refresh will be handled by analyticsProvider
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: AdaptiveTabBarView(
          tabs: [
            context.l10n.runningTab,
            context.l10n.day30Tab,
            context.l10n.longTermTab,
            context.l10n.scenarioTab,
          ],
          children: [
            buildRunningBalanceTab(
              context,
              colorScheme,
              analyticsData,
              selectedCurrency: filterState.selectedCurrency,
            ),
            build30DayLookAheadTab(
              context,
              colorScheme,
              analyticsData,
              selectedCurrency: filterState.selectedCurrency,
            ),
            buildLongTermProjectionTab(
              context,
              colorScheme,
              analyticsData,
              selectedCurrency: filterState.selectedCurrency,
            ),
            _buildScenarioPlanningTabWithProvider(
              colorScheme,
              analyticsData,
              filterState.selectedCurrency,
            ),
          ],
          onTabChanged: (_) {},
        ),
      ),
    );
  }

  Widget _buildScenarioPlanningTabWithProvider(ColorScheme colorScheme, AnalyticsData analyticsData, String? selectedCurrency) {
    return ProviderScope(
      overrides: const [
        // Override any providers if needed
      ],
      child: buildScenarioPlanningTab(context, colorScheme, analyticsData, selectedCurrency: selectedCurrency),
    );
  }
}
