import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget buildLongTermProjectionChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
  // Project 18 months based on current average
  final avgMonthly = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (sum, e) => sum + e.amount);

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
