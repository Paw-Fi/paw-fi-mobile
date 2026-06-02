import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';

class DashboardTrendChart extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String? currencyCode;
  final bool isLoading;
  const DashboardTrendChart({
    super.key,
    required this.transactions,
    this.amountResolver,
    this.currencyCode,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;
    final amountFormatter =
        NumberFormat.compactSimpleCurrency(name: displayCurrency);

    DateTime resolveStartMonth(List<ConsolidatedTransaction> txs) {
      if (txs.isEmpty) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, 1);
      }
      DateTime minDate = txs.first.entry.date;
      for (final tx in txs) {
        if (tx.entry.date.isBefore(minDate)) {
          minDate = tx.entry.date;
        }
      }
      return DateTime(minDate.year, minDate.month, 1);
    }

    DateTime resolveEndMonth(List<ConsolidatedTransaction> txs) {
      if (txs.isEmpty) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, 1);
      }
      DateTime maxDate = txs.first.entry.date;
      for (final tx in txs) {
        if (tx.entry.date.isAfter(maxDate)) {
          maxDate = tx.entry.date;
        }
      }
      return DateTime(maxDate.year, maxDate.month, 1);
    }

    final expenses = transactions.where((tx) {
      return (tx.entry.type ?? 'expense').toLowerCase() != 'income';
    }).toList();

    const maxChartMonths = 6;
    var startMonth = resolveStartMonth(expenses);
    final endMonth = resolveEndMonth(expenses);

    if (isLoading && expenses.isEmpty) {
      startMonth = DateTime(endMonth.year, endMonth.month - 5, 1);
    }

    var monthsCount = (endMonth.year - startMonth.year) * 12 +
        endMonth.month -
        startMonth.month +
        1;
    final isCapped = monthsCount > maxChartMonths;
    if (isCapped) {
      startMonth = DateTime(
        endMonth.year,
        endMonth.month - (maxChartMonths - 1),
        1,
      );
      monthsCount = maxChartMonths;
    }
    final monthlyTotals = List.filled(monthsCount, 0.0);

    for (final tx in expenses) {
      final monthIndex = (tx.entry.date.year - startMonth.year) * 12 +
          tx.entry.date.month -
          startMonth.month;
      if (monthIndex < 0 || monthIndex >= monthsCount) continue;
      final baseAmount = tx.entry.amountCents / 100.0;
      final resolvedAmount = amountResolver?.call(tx) ?? baseAmount;
      monthlyTotals[monthIndex] += resolvedAmount.abs();
    }

    final spots = <FlSpot>[];
    double maxAmount = 0;

    for (int i = 0; i < monthsCount; i++) {
      final amount = monthlyTotals[i];
      spots.add(FlSpot((i + 1).toDouble(), amount));
      if (amount > maxAmount) maxAmount = amount;
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(1, 0));
    }

    if (isLoading && expenses.isEmpty) {
      spots.clear();
      for (int i = 0; i < monthsCount; i++) {
        spots.add(FlSpot((i + 1).toDouble(), (i + 1) * 10.0));
      }
      maxAmount = 60.0;
    }

    // Smooth out the chart visuals
    final maxY = maxAmount > 0 ? maxAmount * 1.2 : 1.0;

    return Skeletonizer(
      enabled: isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
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
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt() - 1;
                        if (index < 0 || index >= monthsCount) {
                          return const SizedBox();
                        }
                        final interval = (monthsCount / 6)
                            .ceil()
                            .clamp(1, monthsCount)
                            .toInt();
                        if (index % interval != 0 && index != monthsCount - 1) {
                          return const SizedBox();
                        }
                        final monthDate = DateTime(
                          startMonth.year,
                          startMonth.month + index,
                          1,
                        );
                        return Text(
                          DateFormat('MMM yy').format(monthDate),
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: monthsCount.toDouble(),
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
          ),
          if (isCapped)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.last6Months,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
