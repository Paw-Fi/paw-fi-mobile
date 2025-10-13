import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget buildRunningBalanceChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
  // Group by date
  final Map<String, double> dailySpent = {};
  final Map<String, double> dailyBudget = {};

  for (final expense in expenses) {
    final dateKey = expense.date.toIso8601String().substring(0, 10);
    dailySpent[dateKey] = (dailySpent[dateKey] ?? 0) + expense.amount;
  }

  for (final budget in budgets) {
    final dateKey = budget.date.toIso8601String().substring(0, 10);
    dailyBudget[dateKey] = (dailyBudget[dateKey] ?? 0) + budget.amount;
  }

  final dates = {...dailySpent.keys, ...dailyBudget.keys}.toList()..sort();

  if (dates.isEmpty) {
    return Center(
      child: Text('No data available', style: TextStyle(color: colorScheme.mutedForeground)),
    );
  }

  // Calculate running balance
  double runningBalance = 0;
  final spots = <FlSpot>[];
  final budgetSpots = <FlSpot>[];
  final spentSpots = <FlSpot>[];

  for (int i = 0; i < dates.length; i++) {
    final date = dates[i];
    final spent = dailySpent[date] ?? 0;
    final budget = dailyBudget[date] ?? 0;
    runningBalance += (budget - spent);

    spots.add(FlSpot(i.toDouble(), runningBalance));
    budgetSpots.add(FlSpot(i.toDouble(), budget));
    spentSpots.add(FlSpot(i.toDouble(), spent));
  }

  return LineChart(
    LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: runningBalance.abs() / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colorScheme.border.withOpacity(0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: dates.length > 10 ? 5 : 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= dates.length) return const SizedBox();
              final date = DateTime.parse(dates[value.toInt()]);
              return Text(
                '${date.month}/${date.day}',
                style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFF8B5CF6), // Purple for running
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: budgetSpots,
          isCurved: true,
          color: const Color(0xFF3B82F6), // Blue for budget
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: spentSpots,
          isCurved: true,
          color: const Color(0xFFEF4444), // Red for spent
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ),
  );
}
