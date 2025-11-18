import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Analytics data refresh will be handled by analyticsProvider
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.l10n.insights,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: colorScheme.foreground,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(text: context.l10n.runningTab),
                    Tab(text: context.l10n.day30Tab),
                    Tab(text: context.l10n.longTermTab),
                    Tab(text: context.l10n.scenarioTab),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    buildRunningBalanceTab(context, colorScheme, analyticsData, selectedCurrency: filterState.selectedCurrency),
                    build30DayLookAheadTab(context, colorScheme, analyticsData, selectedCurrency: filterState.selectedCurrency),
                    buildLongTermProjectionTab(context, colorScheme, analyticsData, selectedCurrency: filterState.selectedCurrency),
                    _buildScenarioPlanningTabWithProvider(colorScheme, analyticsData, filterState.selectedCurrency),
                  ],
                ),
              ),
            ],
          ),
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
