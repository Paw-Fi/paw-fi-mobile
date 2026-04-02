import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class TransactionsPieChart extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final String? selectedCurrency;
  final String periodLabel;
  final List<CategorySummary>? categorySummariesOverride;
  final double? totalSpentOverride;

  const TransactionsPieChart({
    super.key,
    required this.colorScheme,
    required this.expenses,
    required this.periodLabel,
    this.selectedCurrency,
    this.categorySummariesOverride,
    this.totalSpentOverride,
  });

  @override
  State<TransactionsPieChart> createState() => _TransactionsPieChartState();
}

class _TransactionsPieChartState extends State<TransactionsPieChart> {
  int? _touchedIndex;

  List<CategorySummary> _getCategorySummaries(List<ExpenseEntry> expenses) {
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};

    for (final expense in expenses) {
      final cat = (expense.category ?? 'uncategorized').toLowerCase();
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount.abs();
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    return categoryTotals.entries.map((e) {
      return CategorySummary(
        category: e.key,
        amount: e.value,
        transactionCount: categoryCounts[e.key] ?? 0,
        color: getCategoryColor(e.key),
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  double _getTotalSpent(List<ExpenseEntry> expenses) {
    return expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
  }

  @override
  Widget build(BuildContext context) {
    final spendOnly = widget.expenses
        .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
        .toList();

    // Take top 5 and group rest into "other" if there are many
    var categorySummaries = widget.categorySummariesOverride != null
        ? List<CategorySummary>.from(widget.categorySummariesOverride!)
        : _getCategorySummaries(spendOnly);
    if (categorySummaries.length > 6) {
      final visible = categorySummaries.take(5).toList(growable: true);
      final otherItems = categorySummaries.skip(5);
      final otherAmount =
          otherItems.fold<double>(0, (sum, item) => sum + item.amount);
      final otherCount =
          otherItems.fold<int>(0, (sum, item) => sum + item.transactionCount);
      visible.add(
        CategorySummary(
          category: 'other',
          amount: otherAmount,
          transactionCount: otherCount,
          color: widget.colorScheme.muted,
        ),
      );
      categorySummaries = visible;
    }

    final totalSpent = widget.totalSpentOverride ?? _getTotalSpent(spendOnly);
    final hasData = totalSpent > 0 && categorySummaries.isNotEmpty;

    final selected = (_touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < categorySummaries.length)
        ? categorySummaries[_touchedIndex!]
        : null;

    final currencyCode = widget.selectedCurrency ?? 'USD';
    final symbol = resolveCurrencySymbol(currencyCode);

    String displayAmount(double amount) =>
        '$symbol${formatLocalizedNumber(context, amount)}';

    if (!hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            context.l10n.noData,
            style: TextStyle(color: widget.colorScheme.mutedForeground),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pie Chart Area
        SizedBox(
          height: 240,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapDownEvent) {
                            if (response?.touchedSection != null) {
                              setState(() {
                                final nextIndex = response!
                                    .touchedSection!.touchedSectionIndex;
                                _touchedIndex = _touchedIndex == nextIndex
                                    ? null
                                    : nextIndex;
                              });
                            }
                          } else if (event is FlTapUpEvent ||
                              event is FlTapCancelEvent) {
                            // Optionally keep selection or clear it
                          }
                        },
                      ),
                      sectionsSpace: 4,
                      centerSpaceRadius:
                          100, // Narrow radius for the donut look
                      sections: categorySummaries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final category = entry.value;
                        final isTouched = idx == _touchedIndex;

                        return PieChartSectionData(
                          color: category.color,
                          value: category.amount,
                          title: '', // No title inside pie section
                          radius: isTouched ? 23 : 15, // Thinner section
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              // Center Text
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected != null
                      ? Column(
                          key: const ValueKey('selected'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              getCategoryTranslation(context, selected.category)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: widget.colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayAmount(selected.amount),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: widget.colorScheme.foreground,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('total'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.totalSpent.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: widget.colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayAmount(totalSpent),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: widget.colorScheme.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.periodLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: widget.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Legend Cards
        SizedBox(
          height: 120, // Increased height to accommodate enhanced shadows
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categorySummaries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categorySummaries[index];
              final percent = (category.amount / totalSpent) * 100;
              final isSelected = _touchedIndex == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _touchedIndex = isSelected ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 180, // Increased width to show it's scrollable
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.colorScheme.homeCardSurface
                        : widget.colorScheme.card, // Fallback to a card surface
                    borderRadius: BorderRadius.circular(
                        10), // Use radius 10 from aesthetics
                    border: Border.all(
                      color: isSelected
                          ? widget.colorScheme.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: Theme.of(context).brightness == Brightness.dark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                              spreadRadius: -1,
                            ),
                            BoxShadow(
                              color: widget.colorScheme.surface
                                  .withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                              spreadRadius: -2,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: widget.colorScheme.homeCardShadow
                                  .withValues(alpha: 0.15),
                              blurRadius: 13,
                              offset: const Offset(0, 2),
                              spreadRadius: -6,
                            ),
                            BoxShadow(
                              color: widget.colorScheme.homeCardShadow
                                  .withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                              spreadRadius: -2,
                            ),
                          ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: category.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              getCategoryTranslation(
                                  context, category.category),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.colorScheme.foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        displayAmount(category.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.colorScheme.foreground,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${percent.toStringAsFixed(0)}% OF TOTAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: widget.colorScheme.mutedForeground,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
