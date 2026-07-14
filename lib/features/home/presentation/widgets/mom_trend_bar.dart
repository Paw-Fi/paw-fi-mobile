import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class MoMTrendBar extends ConsumerWidget {
  const MoMTrendBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final mapAsync = ref.watch(momTrendProvider);
    final map = mapAsync.valueOrNull;

    if (map == null) {
      if (mapAsync.hasError) {
        return _wrap(
          context,
          colorScheme,
          Center(child: Text(context.l10n.noSpendingData)),
        );
      }
      return _wrap(
        context,
        colorScheme,
        Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(
            baseColor: colorScheme.skeletonBase,
            highlightColor: colorScheme.skeletonHighlight,
          ),
          child: Center(child: Text(context.l10n.noSpendingData)),
        ),
        title: context.l10n.monthOverMonthSpending,
        subtitle: context.l10n.last3Months,
      );
    }

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
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, animationValue, child) {
            return BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => colorScheme.card,
                    tooltipBorder:
                        BorderSide(color: colorScheme.border, width: 1),
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
                          toY: values[i] * animationValue,
                          color: colorScheme.primary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4)),
                    ])
                ],
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
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = labels[i].split('-');
                        final year = int.tryParse(parts[0]) ?? 2000;
                        final month = int.tryParse(parts[1]) ?? 1;
                        final date = DateTime(year, month, 1);
                        final label = formatLocalizedMonth(context, date,
                            abbreviated: true);
                        return Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.mutedForeground));
                      },
                    ),
                  ),
                ),
                maxY: maxY,
              ),
            );
          },
        ),
      ),
      title: context.l10n.monthOverMonthSpending,
      subtitle: context.l10n.last3Months,
    );
  }

  Widget _wrap(BuildContext context, ColorScheme colorScheme, Widget child,
      {String? title, String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
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
