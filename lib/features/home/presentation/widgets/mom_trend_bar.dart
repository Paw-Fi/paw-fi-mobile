import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/util/logger.dart';

class MoMTrendBar extends ConsumerWidget {
  const MoMTrendBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final map = ref.watch(momTrendProvider);
    appLog('widget_viewed: mom_trend_bar');

    if (map.isEmpty) {
      return _wrap(colorScheme, const Center(child: Text('No monthly data yet')));
    }
    final labels = map.keys.toList();
    final values = labels.map((k) => map[k] ?? 0).toList();
    final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b) * 1.25).clamp(10.0, double.infinity);

    return _wrap(
      colorScheme,
      SizedBox(
        height: 100,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (int i = 0; i < labels.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: values[i], color: colorScheme.primary, width: 16, borderRadius: BorderRadius.circular(4)),
                ])
            ],
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    final parts = labels[i].split('-');
                    return Text('${parts[1]}/${parts[0].substring(2)}', style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground));
                  },
                ),
              ),
            ),
            maxY: maxY,
          ),
        ),
      ),
      title: 'MoM spend',
      subtitle: 'Last 3 months',
    );
  }

  Widget _wrap(shadcnui.ColorScheme colorScheme, Widget child, {String? title, String? subtitle}) {
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
