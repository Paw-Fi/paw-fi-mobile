import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AccountChartData {
  final String id;
  final String name;
  final double expense;
  final double income;
  final List<double> dailyExpenses;

  const AccountChartData({
    required this.id,
    required this.name,
    required this.expense,
    required this.income,
    required this.dailyExpenses,
  });
}

class AccountSpendListChart extends StatelessWidget {
  final List<AccountChartData> data;
  final String? currencyCode;

  const AccountSpendListChart({
    super.key,
    required this.data,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppTheme.pocketChartPalette;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;
    final formatter = NumberFormat.compactSimpleCurrency(name: displayCurrency);
    final maxValue = data.fold<double>(
        0.0, (max, item) => item.expense > max ? item.expense : max);
    final denom = maxValue > 0 ? maxValue : 1.0;

    Widget buildRow(AccountChartData item, int index) {
      final color = palette[index % palette.length];
      final percent = (item.expense / denom).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatter.format(item.expense),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemBuilder: (context, index) => buildRow(data[index], index),
          );
        }

        return Column(
          children: List.generate(
            data.length,
            (index) => buildRow(data[index], index),
          ),
        );
      },
    );
  }
}

class AccountIncomeExpenseChart extends StatelessWidget {
  final List<AccountChartData> data;
  final String? currencyCode;

  const AccountIncomeExpenseChart({
    super.key,
    required this.data,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;
    final formatter = NumberFormat.compactSimpleCurrency(name: displayCurrency);
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = data[index];
          final net = item.income - item.expense;
          final netLabel = net >= 0
              ? '+${formatter.format(net)}'
              : '-${formatter.format(net.abs())}';
          final netColor = net >= 0 ? colorScheme.success : colorScheme.error;

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 210, maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.border.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: netColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: netColor.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          netLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: netColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AccountStatChip(
                        label: context.l10n.accountIncome,
                        value: formatter.format(item.income),
                        color: colorScheme.success,
                        icon: Icons.arrow_downward_rounded,
                      ),
                      _AccountStatChip(
                        label: context.l10n.accountSpendLabel,
                        value: formatter.format(item.expense),
                        color: colorScheme.error,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccountStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AccountStatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSpendDonutChart extends StatelessWidget {
  final List<AccountChartData> data;

  const AccountSpendDonutChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppTheme.pocketChartPalette;
    final total = data.fold<double>(0.0, (sum, item) => sum + item.expense);
    final chartSections = <PieChartSectionData>[];

    if (total <= 0) {
      chartSections.add(
        PieChartSectionData(
          value: 1,
          color: colorScheme.mutedForeground.withValues(alpha: 0.2),
          radius: 40,
          title: '',
        ),
      );
    } else {
      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        if (item.expense <= 0) continue;
        chartSections.add(
          PieChartSectionData(
            value: item.expense,
            color: palette[i % palette.length],
            radius: 40,
            title: '',
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PieChart(
            PieChartData(
              sections: chartSections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(data.length, (index) {
            final item = data[index];
            final color = palette[index % palette.length];
            final percent = total > 0 ? (item.expense / total) * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class AccountTrendGrid extends StatelessWidget {
  final List<AccountChartData> data;

  const AccountTrendGrid({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppTheme.pocketChartPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(data.length, (index) {
            final item = data[index];
            final color = palette[index % palette.length];
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: _max(item.dailyExpenses),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildSpots(item.dailyExpenses),
                            isCurved: true,
                            color: color,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  double _max(List<double> values) {
    if (values.isEmpty) return 1.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue * 1.2 : 1.0;
  }

  List<FlSpot> _buildSpots(List<double> values) {
    if (values.isEmpty) return [const FlSpot(0, 0)];
    return List.generate(values.length, (index) {
      return FlSpot((index + 1).toDouble(), values[index]);
    });
  }
}

class AccountChartLegend extends StatelessWidget {
  final List<AccountChartData> data;
  final bool showTotals;
  final String? currencyCode;

  const AccountChartLegend({
    super.key,
    required this.data,
    this.showTotals = false,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.pocketChartPalette;
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;
    final formatter = NumberFormat.compactSimpleCurrency(name: displayCurrency);

    return Column(
      children: List.generate(data.length, (index) {
        final item = data[index];
        final color = palette[index % palette.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (showTotals)
                Text(
                  formatter.format(item.expense),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
