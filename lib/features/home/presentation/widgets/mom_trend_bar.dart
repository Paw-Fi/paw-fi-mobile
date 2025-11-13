import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/util/logger.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/core/core.dart';

class MoMTrendBar extends ConsumerWidget {
  const MoMTrendBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    // Ensure recurring data is loaded when the widget appears
    final recState = ref.watch(recurringTransactionsProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId != null && !recState.hasLoadedOnce && !recState.data.isLoading) {
      Future.microtask(() {
        final s = ref.read(recurringTransactionsProvider);
        if (!s.hasLoadedOnce && !s.data.isLoading) {
          ref.read(recurringTransactionsProvider.notifier).loadRecurringTransactions(userId);
        }
      });
    }
    final map = ref.watch(momTrendProvider);
    appLog('widget_viewed: mom_trend_bar');

    if (map.isEmpty) {
      return _wrap(colorScheme, Center(child: Text(context.l10n.noSpendingData)));
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
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => colorScheme.card,
                tooltipBorder: BorderSide(color: colorScheme.border, width: 1),
              ),
            ),
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
                    final year = int.tryParse(parts[0]) ?? 2000;
                    final month = int.tryParse(parts[1]) ?? 1;
                    final date = DateTime(year, month, 1);
                    final label = formatLocalizedMonth(context, date, abbreviated: true);
                    return Text(label, style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground));
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
