import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';

import 'package:moneko/core/util/logger.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CashflowSparklineCard extends ConsumerWidget {
  const CashflowSparklineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final series = ref.watch(homeCashflowSeriesProvider);

    // Fire analytics-like event
    appLog('widget_viewed: cashflow_sparkline');

    if (series.isEmpty) {
      return _wrapCard(colorScheme, const Center(child: Text('No cashflow yet')));
    }

    // Build cumulative net cashflow
    final dates = series.keys.toList()..sort();
    double cum = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < dates.length; i++) {
      cum += series[dates[i]]!;
      spots.add(FlSpot(i.toDouble(), cum));
    }

    return _wrapCard(
      colorScheme,
      SizedBox(
        height: 96,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (spots.length / 4).clamp(1, 7).toDouble(),
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                    final d = dates[idx];
                    return Text('${d.month}/${d.day}', style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: colorScheme.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.25),
                      colorScheme.primary.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      title: 'Cashflow trend',
      subtitle: 'Cumulative net over time',
    );
  }

  Widget _wrapCard(ColorScheme colorScheme, Widget child, {String? title, String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: colorScheme.mutedForeground)),
            ],
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }
}
