import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildCategoryBarChart(BuildContext context, ColorScheme colorScheme,
    List<ExpenseEntry> expenses) {
  // Group by category
  final Map<String, double> categoryTotals = {};
  for (final expense in expenses) {
    final cat = expense.category ?? 'uncategorized';
    categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
  }

  final categories = categoryTotals.keys.toList()
    ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));
  final maxValue = categoryTotals.values.isEmpty
      ? 100.0
      : categoryTotals.values.reduce((a, b) => a > b ? a : b);

  if (categories.isEmpty) {
    return Center(
      child: Text(context.l10n.noDataAvailable,
          style: TextStyle(color: colorScheme.mutedForeground)),
    );
  }

  // Calculate required width: each bar needs ~60px (40px bar + 20px spacing)
  const barWidth = 60.0;
  final minWidth = categories.length * barWidth;
  final screenWidth =
      MediaQuery.of(context).size.width - 32; // subtract padding

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: minWidth > screenWidth ? minWidth : screenWidth,
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (group) => colorScheme.card,
              tooltipBorder: BorderSide(color: colorScheme.border, width: 1),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final category = categories[group.x.toInt()];
                return BarTooltipItem(
                  '${getCategoryTranslation(context, category)}\n',
                  TextStyle(
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: rod.toY.toStringAsFixed(2),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= categories.length)
                    return const SizedBox();
                  return Text(
                    getCategoryTranslation(context, categories[value.toInt()]),
                    style: TextStyle(
                        fontSize: 10, color: colorScheme.mutedForeground),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    ),
  );
}
