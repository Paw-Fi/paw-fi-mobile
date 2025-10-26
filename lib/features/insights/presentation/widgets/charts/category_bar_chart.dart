import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

Widget buildCategoryBarChart(BuildContext context, shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses) {
  // Group by category
  final Map<String, double> categoryTotals = {};
  for (final expense in expenses) {
    final cat = expense.category ?? 'uncategorized';
    categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
  }

  final categories = categoryTotals.keys.toList()..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));
  final maxValue = categoryTotals.values.isEmpty ? 100.0 : categoryTotals.values.reduce((a, b) => a > b ? a : b);

  if (categories.isEmpty) {
    return Center(
      child: Text(context.l10n.noDataAvailable, style: TextStyle(color: colorScheme.mutedForeground)),
    );
  }

  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue * 1.2,
      barGroups: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final value = categoryTotals[category] ?? 0;
        final color = getCategoryColor(category);

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 40,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= categories.length) return const SizedBox();
              return Text(
                categories[value.toInt()],
                style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ),
  );
}
