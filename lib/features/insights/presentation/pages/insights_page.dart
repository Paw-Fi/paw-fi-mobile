import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import '../widgets/tabs/tabs.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';

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
          final user = ref.read(authProvider);
          if (user.uid.isEmpty) return;
          await ref.read(analyticsProvider.notifier).loadData(user.uid);
        },
        child: SizedBox(
          width: double.infinity,
          child: MonekoTabBarView(
            tabs: [
              // Scenario first, then Running
              context.l10n.scenarioTab,
              context.l10n.runningTab,
            ],
            children: [
              _buildScenarioPlanningTabWithProvider(
                colorScheme,
                analyticsData,
                filterState.selectedCurrency,
              ),
              buildRunningBalanceTab(
                context,
                colorScheme,
                analyticsData,
                selectedCurrency: filterState.selectedCurrency,
              ),
            ],
            onTabChanged: (_) {},
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioPlanningTabWithProvider(ColorScheme colorScheme,
      AnalyticsData analyticsData, String? selectedCurrency) {
    return ProviderScope(
      overrides: const [
        // Override any providers if needed
      ],
      child: buildScenarioPlanningTab(
        context,
        analyticsData,
        selectedCurrency: selectedCurrency,
      ),
    );
  }
}
