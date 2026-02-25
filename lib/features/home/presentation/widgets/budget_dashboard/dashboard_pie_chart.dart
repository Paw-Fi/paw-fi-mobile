import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

class DashboardPieChart extends StatefulWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String? currencyCode;

  const DashboardPieChart({
    super.key,
    required this.transactions,
    this.amountResolver,
    this.currencyCode,
  });

  @override
  State<DashboardPieChart> createState() => _DashboardPieChartState();
}

class _DashboardPieChartState extends State<DashboardPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency = widget.currencyCode?.trim().isNotEmpty == true
        ? widget.currencyCode!.trim()
        : null;
    final currencyFormatter =
        NumberFormat.compactSimpleCurrency(name: displayCurrency);

    // 1. Filter expenses (no income)
    final expenses = widget.transactions
        .where((tx) => (tx.entry.type ?? 'expense').toLowerCase() != 'income');

    String normalizeCategoryId(String? categoryId) {
      final trimmed = categoryId?.trim();
      final normalized =
          (trimmed == null || trimmed.isEmpty) ? 'uncategorized' : trimmed;
      return normalizeCategory(normalized);
    }

    // 2. Group by category
    final grouped =
        expenses.groupListsBy((tx) => normalizeCategoryId(tx.entry.category));

    // 3. Sum amounts
    final data = grouped.entries.map((entry) {
      final categoryId = entry.key;
      final total = entry.value.fold<double>(0.0, (sum, tx) {
        final resolved =
            widget.amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
        return sum + resolved.abs();
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
          name: context.l10n.other,
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
            context.l10n.noExpensesDisplay,
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.totalSpent,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormatter.format(totalExpense),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              PieChart(
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
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 4,
                  centerSpaceRadius: 65,
                  sections: List.generate(topData.length, (i) {
                    final isTouched = i == touchedIndex;
                    final radius = isTouched ? 35.0 : 30.0;
                    final item = topData[i];

                    return PieChartSectionData(
                      color: item.color,
                      value: item.amount,
                      title: '',
                      radius: radius,
                      badgeWidget: isTouched
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Text(
                                currencyFormatter.format(item.amount),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            )
                          : null,
                      badgePositionPercentageOffset: 1.1,
                    );
                  }),
                ),
              ),
            ],
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
