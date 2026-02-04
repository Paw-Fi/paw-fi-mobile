import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

class DashboardPieChart extends StatefulWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;

  const DashboardPieChart({
    super.key,
    required this.transactions,
    this.amountResolver,
  });

  @override
  State<DashboardPieChart> createState() => _DashboardPieChartState();
}

class _DashboardPieChartState extends State<DashboardPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.compactSimpleCurrency();

    // 1. Filter expenses (no income)
    final expenses =
        widget.transactions.where((tx) => tx.entry.type != 'income');

    // 2. Group by category
    final grouped = expenses.groupListsBy((tx) => tx.entry.category);

    // 3. Sum amounts
    final data = grouped.entries.map((entry) {
      final categoryId = entry.key ?? 'uncategorized';
      final total = entry.value.fold<double>(0.0, (sum, tx) {
        final resolved =
            widget.amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
        return sum + resolved;
      });
      return _PieData(
        categoryId: categoryId,
        amount: total,
        color: getCategoryColor(categoryId),
        name: getCategoryTranslation(context, categoryId),
      );
    }).toList();

    // 4. Sort descending
    data.sort((a, b) => b.amount.compareTo(a.amount));

    // 5. Take top 5, group rest as "Other"
    final topData = data.take(5).toList();
    if (data.length > 5) {
      final otherAmount =
          data.skip(5).fold<double>(0.0, (sum, d) => sum + d.amount);
      if (otherAmount > 0) {
        topData.add(_PieData(
          categoryId: 'other',
          amount: otherAmount,
          color: colorScheme.muted,
          name: 'Other',
        ));
      }
    }

    // 6. Calculate total for percentage
    final totalExpense = topData.fold<double>(0.0, (sum, d) => sum + d.amount);

    if (totalExpense == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No expenses to display',
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(topData.length, (i) {
                final isTouched = i == touchedIndex;
                final fontSize = isTouched ? 16.0 : 12.0;
                final radius = isTouched ? 60.0 : 50.0;
                final item = topData[i];
                final percent = (item.amount / totalExpense * 100).round();

                return PieChartSectionData(
                  color: item.color,
                  value: item.amount,
                  title: '$percent%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xffffffff),
                  ),
                  badgeWidget: isTouched
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Text(
                            currencyFormatter.format(item.amount),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        )
                      : null,
                  badgePositionPercentageOffset: .98,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: topData.map((d) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: d.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  d.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PieData {
  final String categoryId;
  final String name;
  final double amount;
  final Color color;

  _PieData({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.color,
  });
}
