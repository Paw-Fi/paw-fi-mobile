import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';

class DashboardTrendChart extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final String currency;

  const DashboardTrendChart({
    super.key,
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

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
          (tx.entry.amount > 0);
    }).toList();

    for (final tx in currentMonthTx) {
      final day = tx.entry.date.day;
      if (day >= 1 && day <= daysInMonth) {
        dailyTotals[day - 1] += tx.entry.amount;
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
      return Center(
        child: Text(
          'No data for this month',
          style: TextStyle(color: colorScheme.mutedForeground),
        ),
      );
    }

    // Smooth out the chart visuals
    final maxY = maxAmount * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPENDING TREND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(Icons.show_chart_rounded,
                  color: colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                maxX: daysInMonth.toDouble(),
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
                      color: colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => colorScheme.surface,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          NumberFormat.simpleCurrency(name: currency)
                              .format(spot.y),
                          TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
