import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget buildLongTermProjectionChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
  // Calculate average monthly spend from historical data
  double avgMonthly = 0.0;
  
  if (expenses.isNotEmpty) {
    // Group expenses by month
    final Map<String, double> monthlyTotals = {};
    for (final expense in expenses) {
      final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + expense.amount;
    }
    
    // Calculate average from available months
    avgMonthly = monthlyTotals.isEmpty 
      ? 0.0 
      : monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length;
  }

  // Project 18 months using the calculated average
  final projectionSpots = List.generate(18, (i) {
    return FlSpot(i.toDouble(), avgMonthly * (i + 1));
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
            interval: 3,
            getTitlesWidget: (value, meta) {
              return Text(
                'M${value.toInt() + 1}',
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
        ),
      ],
    ),
  );
}
