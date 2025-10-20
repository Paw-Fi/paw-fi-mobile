import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget build30DayProjectionChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
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
      gridData: FlGridData(show: false),
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
                'Day ${value.toInt() + 1}',
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
          color: const Color(0xFF10B981),
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withOpacity(0.2),
                const Color(0xFF10B981).withOpacity(0.0),
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
