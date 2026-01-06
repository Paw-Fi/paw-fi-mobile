import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../dashboard_config.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

/// Spending Rate Widget
/// Answers: "How much am I spending per day/week on average?"
class SpendingRateWidget extends ConsumerWidget {
  final List<ExpenseEntry> expenses;
  final String currency;
  final DashboardWidgetConfig config;

  const SpendingRateWidget({
    super.key,
    required this.expenses,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Get date range (default to last 30 days if not configured)
    final range = getDateRangeFromFilter(config.dateRange, config.customStartDate, config.customEndDate);
    
    // Filter expenses
    final filteredExpenses = expenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(range['from']!.subtract(const Duration(days: 1))) &&
        e.date.isBefore(range['to']!.add(const Duration(days: 1))) &&
        e.type != 'income').toList();
    
    final totalSpent = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final daysInRange = range['to']!.difference(range['from']!).inDays + 1;
    final dailyAverage = daysInRange > 0 ? totalSpent / daysInRange : 0.0;
    final weeklyAverage = dailyAverage * 7;
    
    // Get last 7 days for sparkline
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final dailySpending = last7Days.map((day) {
      return filteredExpenses
          .where((e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .fold<double>(0, (sum, e) => sum + e.amount);
    }).toList();
    
    // Calculate trend (compare current period vs previous)
    final previousRange = (
      range['from']!.subtract(Duration(days: daysInRange)),
      range['from']!.subtract(const Duration(days: 1)),
    );
    final previousExpenses = expenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(previousRange.$1.subtract(const Duration(days: 1))) &&
        e.date.isBefore(previousRange.$2.add(const Duration(days: 1))) &&
        e.type != 'income').toList();
    final previousTotal = previousExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final previousDaily = daysInRange > 0 ? previousTotal / daysInRange : 0.0;
    final trendPercentage = previousDaily > 0 ? ((dailyAverage - previousDaily) / previousDaily * 100) : 0.0;

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'spendingRate',
          'config': config,
          'currency': currency,
        });
      },
      child: Card(
        color: colorScheme.cardSurface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.spendingRate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (trendPercentage != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (trendPercentage > 0 ? colorScheme.destructive : AppTheme.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendPercentage > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: trendPercentage > 0 ? colorScheme.destructive : AppTheme.success,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${trendPercentage.abs().toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: trendPercentage > 0 ? colorScheme.destructive : AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Daily average
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatCurrency(dailyAverage, currency),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '/${context.l10n.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatCurrency(weeklyAverage, currency)}/${context.l10n.week}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              
              // Sparkline for last 7 days
              SizedBox(
                height: 40,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: dailySpending.reduce((a, b) => a > b ? a : b) * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          7,
                          (i) => FlSpot(i.toDouble(), dailySpending[i]),
                        ),
                        isCurved: true,
                        color: colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
