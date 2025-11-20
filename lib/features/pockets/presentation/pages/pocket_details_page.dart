import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/liquid_pocket.dart';
import 'package:moneko/features/utils/currency.dart';

import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';

class PocketDetailsPage extends HookConsumerWidget {
  const PocketDetailsPage({
    super.key,
    required this.pocketId,
    required this.scopeParams,
  });

  final String pocketId;
  final PocketsScopeParams scopeParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final colorScheme = Theme.of(context).colorScheme;

    // If state is loading (e.g., after invalidation), show loading indicator
    if (state.isLoading && state.editing.isEmpty && state.saved.isEmpty) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: 'Loading...'),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      );
    }

    // Try to find the pocket in editing or saved lists
    final pocket = _findPocket(state, pocketId);

    // If pocket not found, show error screen
    if (pocket == null) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: 'Pocket Not Found'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pocket not found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This pocket may have been deleted',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalBudget = state.totalBudget;
    final limit = pocket.getLimit(totalBudget);
    final progress = pocket.getProgress(totalBudget);
    final isOverBudget = pocket.isOverBudget(totalBudget);

    // Calculate unallocated budget for the edit sheet
    final totalPercentage =
        state.editing.fold<double>(0, (sum, p) => sum + p.percentage);
    final unallocatedBudget = totalBudget * ((100 - totalPercentage) / 100);

    // Animation for the liquid level
    final animatedProgress = useAnimationController(
      duration: const Duration(milliseconds: 1500),
      initialValue: 0,
    );

    useEffect(() {
      animatedProgress.animateTo(progress, curve: Curves.easeOutCubic);
      return null;
    }, [progress]);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: pocket.name,
        actions: [
          AdaptiveAppBarAction(
            onPressed: () {
              // Combine both saved and editing pockets for complete rebalancing
              // Remove duplicates by ID (editing takes precedence over saved)
              final seenIds = <String>{};
              final allPockets = <PocketEnvelope>[
                ...state.editing.where((p) {
                  if (seenIds.contains(p.id)) return false;
                  seenIds.add(p.id);
                  return true;
                }),
                ...state.saved.where((p) {
                  if (seenIds.contains(p.id)) return false;
                  seenIds.add(p.id);
                  return true;
                }),
              ];
              
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => EditPocketEnvelopeSheet(
                  scopeParams: scopeParams,
                  existingEnvelope: pocket,
                  totalBudget: totalBudget,
                  unallocatedBudget: unallocatedBudget,
                  budgetId: state.budgetId,
                  allPockets: allPockets,
                ),
              );
            },
            iosSymbol: "pencil",
            icon: Icons.edit,
          ),
        ],
      ),
      body: Material(
        child: Padding(
          padding:
              EdgeInsets.only(top: PlatformInfo.isIOS26OrHigher() ? 100.0 : 10),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Liquid Jar Visualization
                  Center(
                    child: Container(
                      height: 300,
                      width: 220,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: (pocket.color != null
                                    ? Color(int.parse(
                                        pocket.color!.replaceAll('#', '0xff')))
                                    : colorScheme.primary)
                                .withOpacity(0.2),
                            blurRadius: 60,
                            spreadRadius: -10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Glass reflection effect
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(38),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // The Liquid
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: LiquidPocket(
                              fillLevel: progress,
                              color: pocket.color != null
                                  ? Color(int.parse(
                                      pocket.color!.replaceAll('#', '0xff')))
                                  : colorScheme.primary,
                            ),
                          ),
                          // Labels inside the jar
                          Positioned(
                            bottom: 30,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: isOverBudget
                                        ? colorScheme.error
                                        : colorScheme.foreground
                                            .withOpacity(0.8),
                                    shadows: [
                                      Shadow(
                                        color: colorScheme.surface
                                            .withOpacity(0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Used',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        colorScheme.foreground.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                        label: 'Spent',
                        value: formatCurrency(pocket.spent, pocket.currency),
                        color: colorScheme.foreground,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: colorScheme.outlineVariant,
                      ),
                      _StatItem(
                        label: 'Budget',
                        value: formatCurrency(limit, pocket.currency),
                        color: colorScheme.primary,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: colorScheme.outlineVariant,
                      ),
                      _StatItem(
                        label: 'Remaining',
                        value: formatCurrency(
                            limit - pocket.spent, pocket.currency),
                        color: (limit - pocket.spent) < 0
                            ? colorScheme.error
                            : colorScheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Transactions List
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Consumer(
                    builder: (context, ref, child) {
                      final detailsAsync = ref.watch(
                        pocketDetailsProvider(
                          PocketTransactionsParams(
                            pocketId: pocketId,
                            scopeParams: scopeParams,
                          ),
                        ),
                      );

                      return detailsAsync.when(
                        data: (data) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Insights Section
                              if (data.transactions.isNotEmpty) ...[
                                Text(
                                  'Insights',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.foreground,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _InsightRow(
                                        label: 'Daily Average',
                                        value: formatCurrency(
                                            data.dailyAverage, pocket.currency),
                                        icon: Icons.calendar_today_rounded,
                                        colorScheme: colorScheme,
                                      ),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      _InsightRow(
                                        label: 'Projected End of Month',
                                        value: formatCurrency(
                                            data.projectedSpend,
                                            pocket.currency),
                                        icon: Icons.trending_up_rounded,
                                        colorScheme: colorScheme,
                                        valueColor: data.projectedSpend > limit
                                            ? colorScheme.error
                                            : null,
                                      ),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      _InsightRow(
                                        label: 'Last Month Total',
                                        value: formatCurrency(
                                            data.totalSpentLastMonth,
                                            pocket.currency),
                                        icon: Icons.history_rounded,
                                        colorScheme: colorScheme,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Daily Spending Chart
                                if (data.dailySpending.isNotEmpty) ...[
                                  Text(
                                    'Daily Spending Trend',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.foreground,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 200,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 24, 16, 0),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: _DailySpendingChart(
                                      dailySpending: data.dailySpending,
                                      colorScheme: colorScheme,
                                      primaryColor: pocket.color != null
                                          ? Color(int.parse(pocket.color!
                                              .replaceAll('#', '0xff')))
                                          : colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ],

                              // Category Breakdown
                              if (data.categorySpending.isNotEmpty) ...[
                                Text(
                                  'Spending Breakdown',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.foreground,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.categorySpending.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final item = data.categorySpending[index];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.category,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.foreground,
                                              ),
                                            ),
                                            Text(
                                              formatCurrency(
                                                  item.amount, pocket.currency),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.foreground,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: item.percentage,
                                            backgroundColor: colorScheme
                                                .surfaceContainerHighest,
                                            valueColor: AlwaysStoppedAnimation(
                                              pocket.color != null
                                                  ? Color(int.parse(pocket
                                                      .color!
                                                      .replaceAll('#', '0xff')))
                                                  : colorScheme.primary,
                                            ),
                                            minHeight: 8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(item.percentage * 100).toStringAsFixed(1)}% of pocket',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                              ],

                              // Transactions List
                              Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.foreground,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (data.transactions.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded,
                                          size: 48,
                                          color: colorScheme.outlineVariant,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No transactions yet',
                                          style: TextStyle(
                                            color: colorScheme.mutedForeground,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.transactions.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final tx = data.transactions[index];
                                    final amount =
                                        (tx['amount_cents'] as num).toDouble() /
                                            100.0;
                                    final date = DateTime.parse(tx['date']);
                                    final description =
                                        tx['description'] ?? 'Expense';

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withOpacity(0.4),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.shadow
                                                .withOpacity(0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 20,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  description,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.foreground,
                                                  ),
                                                ),
                                                Text(
                                                  '${date.month}/${date.day} • ${date.year}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme
                                                        .mutedForeground,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            formatCurrency(
                                                amount, pocket.currency),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: colorScheme.foreground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                        loading: () => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation(colorScheme.primary),
                            ),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Failed to load details: $err',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.colorScheme,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colorScheme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.foreground,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? colorScheme.foreground,
          ),
        ),
      ],
    );
  }
}

class _DailySpendingChart extends StatelessWidget {
  const _DailySpendingChart({
    required this.dailySpending,
    required this.colorScheme,
    required this.primaryColor,
  });

  final List<DailySpend> dailySpending;
  final ColorScheme colorScheme;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final maxSpend = dailySpending.fold<double>(
        0, (max, e) => e.amount > max ? e.amount : max);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxSpend * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                TextStyle(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day % 5 == 0 || day == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: dailySpending.map((spend) {
          return BarChartGroupData(
            x: spend.day,
            barRods: [
              BarChartRodData(
                toY: spend.amount,
                color: primaryColor,
                width: 4,
                borderRadius: BorderRadius.circular(2),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxSpend * 1.2,
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Helper function to find a pocket by ID in either editing or saved lists
PocketEnvelope? _findPocket(PocketsState state, String pocketId) {
  try {
    return state.editing.firstWhere((p) => p.id == pocketId);
  } catch (_) {
    try {
      return state.saved.firstWhere((p) => p.id == pocketId);
    } catch (_) {
      return null;
    }
  }
}
