import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';

class DashboardTrendChart extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  const DashboardTrendChart({
    super.key,
    required this.transactions,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final amountFormatter = NumberFormat.compact();

    // Group by Date for the current month
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final dailyTotals = List.filled(daysInMonth, 0.0);

    // Simple filter for current month
    // NOTE: In a real app, currency conversion should happen if currencies differ.
    // For now we sum all currencies globally as requested.
    final currentMonthTx = transactions.where((tx) {
      final date = tx.entry.date;
      return date.year == now.year &&
          date.month == now.month &&
          tx.entry.type != 'income' &&
          (tx.entry.amount > 0);
    }).toList();

    for (final tx in currentMonthTx) {
      final day = tx.entry.date.day;
      if (day >= 1 && day <= daysInMonth) {
        final baseAmount = tx.entry.amount;
        final resolvedAmount = amountResolver?.call(tx) ?? baseAmount;
        dailyTotals[day - 1] += resolvedAmount;
      }
    }

    final spots = <FlSpot>[];
    double maxAmount = 0;

    for (int i = 0; i < daysInMonth; i++) {
      // Don't show future zeros if today is before end of month?
      // Or show 0. Let's show up to today.
      if (i + 1 > now.day) break;

      final amount = dailyTotals[i];
      spots.add(FlSpot((i + 1).toDouble(), amount));
      if (amount > maxAmount) maxAmount = amount;
    }

    if (spots.isEmpty) {
      for (int i = 0; i < now.day; i++) {
        spots.add(FlSpot((i + 1).toDouble(), 0));
      }
    }

    // Smooth out the chart visuals
    final maxY = maxAmount > 0 ? maxAmount * 1.2 : 1.0;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
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
                interval: 5,
                getTitlesWidget: (value, meta) {
                  final val = value.toInt();
                  if (val % 5 == 0 && val > 0 && val <= daysInMonth) {
                    return Text(
                      val.toString(),
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 1,
          maxX: now.day.toDouble(),
          minY: 0,
          maxY: maxY > 0 ? maxY : 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
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
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => colorScheme.card,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    amountFormatter.format(spot.y),
                    TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
