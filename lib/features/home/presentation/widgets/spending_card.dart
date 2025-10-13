import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

Widget buildSpendingCard(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact, DateRangeFilter dateFilter) {
  // Calculate cumulative spending by day
  final Map<DateTime, double> dailyTotals = {};
  final totalSpent = _getTotalSpent(expenses);
  final currencySymbol = _getCurrencySymbol(contact);

  for (final expense in expenses) {
    final dateOnly = DateTime(expense.date.year, expense.date.month, expense.date.day);
    dailyTotals[dateOnly] = (dailyTotals[dateOnly] ?? 0) + expense.amount;
  }

  final sortedDates = dailyTotals.keys.toList()..sort();

  if (sortedDates.isEmpty) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Text('No spending data', style: TextStyle(color: colorScheme.mutedForeground)),
    );
  }

  // Calculate cumulative spending
  double cumulative = 0;
  final cumulativeData = sortedDates.map((date) {
    cumulative += dailyTotals[date] ?? 0;
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
          dateFilter.spentLabel,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$currencySymbol${totalSpent.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 120,
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
                      interval: sortedDates.length > 10 ? 5 : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedDates.length) return const SizedBox();
                        final date = sortedDates[value.toInt()];
                        return Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 12,
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
                maxY: cumulative > 0 ? (cumulative * 1.2).ceilToDouble() : 100,
              ),
            ),
          ),
        ],
      ),  
    );
  }

double _getTotalSpent(List<ExpenseEntry> expenses) {
  return expenses.where((e) => e.amountCents > 0).fold(0.0, (sum, e) => sum + e.amount);
}

String _getCurrencySymbol(UserContact? contact) {
  final cur = contact?.preferredCurrency ?? 'USD';
  switch (cur.toUpperCase()) {
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'USD':
    default:
      return '\$';
  }
}
