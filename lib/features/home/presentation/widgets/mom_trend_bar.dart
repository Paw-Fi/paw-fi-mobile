import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/core/core.dart';

class MoMTrendBar extends ConsumerWidget {
  const MoMTrendBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // This widget is only shown in personal mode; always scope to personal data
    const String? householdId = null;

    // NOTE: Recurring transactions are loaded by app_initialization_provider
    // Just watch the data here - no need to trigger load
    // ignore: unused_local_variable
    final recState = ref.watch(recurringTransactionsProvider(householdId));
    final map = ref.watch(momTrendProvider);
    appLog('widget_viewed: mom_trend_bar');

    if (map.isEmpty) {
      return _wrap(context, colorScheme,
          Center(child: Text(context.l10n.noSpendingData)));
    }
    final labels = map.keys.toList();
    final values = labels.map((k) => map[k] ?? 0).toList();
    final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b) * 1.25)
        .clamp(10.0, double.infinity);

    return _wrap(
      context,
      colorScheme,
      SizedBox(
        height: 90,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => colorScheme.card,
                tooltipBorder: BorderSide(color: colorScheme.border, width: 1),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    rod.toY.toStringAsFixed(2),
                    TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (int i = 0; i < labels.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: values[i],
                      color: colorScheme.primary,
                      width: 16,
                      borderRadius: BorderRadius.circular(4)),
                ])
            ],
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
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    final parts = labels[i].split('-');
                    final year = int.tryParse(parts[0]) ?? 2000;
                    final month = int.tryParse(parts[1]) ?? 1;
                    final date = DateTime(year, month, 1);
                    final label =
                        formatLocalizedMonth(context, date, abbreviated: true);
                    return Text(label,
                        style: TextStyle(
                            fontSize: 10, color: colorScheme.mutedForeground));
                  },
                ),
              ),
            ),
            maxY: maxY,
          ),
        ),
      ),
      title: context.l10n.monthOverMonthSpending,
      subtitle: context.l10n.last3Months,
    );
  }

  Widget _wrap(BuildContext context, ColorScheme colorScheme, Widget child,
      {String? title, String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.chartBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: colorScheme.mutedForeground,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
