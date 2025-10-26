import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';

Widget buildSpendingCard(BuildContext context, shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact, DateRangeFilter dateFilter, {String? selectedCurrency}) {
  final intervalType = getChartIntervalTypeFromFilter(dateFilter);
  
  // Group expenses by appropriate interval
  final periodTotals = groupExpensesByInterval(expenses, intervalType);
  final sortedDates = periodTotals.keys.toList()..sort();

  // Compute total spent robustly: prefer bucket sum, fallback to direct sum
  final bucketsTotal = periodTotals.values.fold(0.0, (a, b) => a + b);
  final directTotal = _getTotalSpent(expenses);
  final totalSpent = bucketsTotal > 0 ? bucketsTotal : directTotal;
  
  // selectedCurrency is never null (defaults to USD)
  final displayText = formatCurrency(totalSpent, selectedCurrency ?? 'USD');

  if (sortedDates.isEmpty) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Text(context.l10n.noSpendingData, style: TextStyle(color: colorScheme.mutedForeground)),
    );
  }

  // Calculate cumulative spending
  double cumulative = 0;
  final cumulativeData = sortedDates.map((date) {
    cumulative += periodTotals[date] ?? 0;
    return FlSpot(
      sortedDates.indexOf(date).toDouble(),
      cumulative,
    );
  }).toList();

  return Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.border, width: 1),
    ),
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFilter.getSpentLabel(context),
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: cumulative > 0 ? cumulative / 4 : 100,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.border.withValues(alpha: 0.3),
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
                        interval: 1, // Show all data points (already bucketed to 6-7 points)
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sortedDates.length) return const SizedBox();
                          final date = sortedDates[value.toInt()];
                          return Text(
                            formatDateForInterval(date, intervalType),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.mutedForeground,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: cumulativeData,
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.3),
                            const Color(0xFF10B981).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: cumulative > 0 ? (cumulative * 1.25).ceilToDouble() : 100,
                ),
              ),
            ),
          ),
        ],
      ),  
    );
  }

double _getTotalSpent(List<ExpenseEntry> expenses) {
  // Treat all rows in expenses as spend; sum absolute to tolerate legacy signs
  return expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
}
