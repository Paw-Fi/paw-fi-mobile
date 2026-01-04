import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/theme/app_theme.dart';
Widget build30DayProjectionChart(BuildContext context, ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
  // Calculate trailing 30-day average
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  
  // Filter to last 30 days only
  final recentExpenses = expenses.where((e) => 
    e.date.isAfter(thirtyDaysAgo) && e.date.isBefore(now)
  ).toList();
  
  // Calculate average daily spend from last 30 days
  final totalRecent = recentExpenses.fold(0.0, (sum, e) => sum + e.amount);
  final avgDaily = recentExpenses.isEmpty ? 0.0 : totalRecent / 30;

  // Project next 30 days
  final projectionSpots = List.generate(30, (i) {
    return FlSpot(i.toDouble(), avgDaily * (i + 1));
  });

  return LineChart(
    LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (value, meta) {
              return Text(
                '${context.l10n.day} ${value.toInt() + 1}',
                style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: projectionSpots,
          isCurved: true,
          color: AppTheme.insightsProjection,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.insightsProjection.withValues(alpha: 0.2),
                AppTheme.insightsProjection.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ),
  );
}
