import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CategoryPieChart extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final String? selectedCurrency;
  final bool showCenterSummary;
  final double chartSize;
  final double centerSpaceRadius;
  final double sectionRadius;
  final double touchedSectionRadius;
  final WrapAlignment legendAlignment;
  final int legendItemLimit;
  final EdgeInsetsGeometry legendPadding;
  final double? legendViewportHeight;

  const CategoryPieChart({
    super.key,
    required this.colorScheme,
    required this.expenses,
    this.selectedCurrency,
    this.showCenterSummary = false,
    this.chartSize = 200,
    this.centerSpaceRadius = 60,
    this.sectionRadius = 52,
    this.touchedSectionRadius = 58,
    this.legendAlignment = WrapAlignment.start,
    this.legendItemLimit = 6,
    this.legendPadding = const EdgeInsets.only(top: 24),
    this.legendViewportHeight,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _touchedIndex;

  @override
  void dispose() {
    super.dispose();
  }

  List<CategorySummary> _buildChartSummaries(
    BuildContext context,
    ColorScheme colorScheme,
    List<ExpenseEntry> expenses,
  ) {
    final summaries = _getCategorySummaries(expenses);
    if (summaries.length <= widget.legendItemLimit) {
      return summaries;
    }

    final visibleCount = widget.legendItemLimit - 1;
    final visible = summaries.take(visibleCount).toList(growable: true);
    final otherItems = summaries.skip(visibleCount);
    final otherAmount =
        otherItems.fold<double>(0, (sum, item) => sum + item.amount);
    final otherCount =
        otherItems.fold<int>(0, (sum, item) => sum + item.transactionCount);

    visible.add(
      CategorySummary(
        category: 'other',
        amount: otherAmount,
        transactionCount: otherCount,
        color: colorScheme.muted,
      ),
    );
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final spendOnly = widget.expenses
        .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
        .toList();
    final categorySummaries =
        _buildChartSummaries(context, colorScheme, spendOnly);
    final totalSpent = _getTotalSpent(spendOnly);
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

    if (!hasData && !widget.showCenterSummary) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(color: colorScheme.mutedForeground),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: widget.chartSize,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: widget.chartSize,
                  height: widget.chartSize,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapDownEvent) {
                            if (response?.touchedSection != null) {
                              setState(() {
                                final nextIndex =
                                    response!.touchedSection!.touchedSectionIndex;
                                _touchedIndex =
                                    _touchedIndex == nextIndex ? null : nextIndex;
                              });
                            }
                          } else if (event is FlTapUpEvent || event is FlTapCancelEvent) {
                            setState(() => _touchedIndex = null);
                          }
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: widget.centerSpaceRadius,
                      sections: hasData
                          ? categorySummaries.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final category = entry.value;
                              final isTouched = idx == _touchedIndex;
                              final percent = totalSpent > 0
                                  ? (category.amount / totalSpent) * 100
                                  : 0.0;
                              return PieChartSectionData(
                                color: category.color,
                                value: category.amount,
                                title: percent > 4
                                    ? '${percent.toStringAsFixed(0)}%'
                                    : '',
                                radius: isTouched
                                    ? widget.touchedSectionRadius
                                    : widget.sectionRadius,
                                titleStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onPrimary,
                                ),
                              );
                            }).toList()
                          : [
                              PieChartSectionData(
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.15),
                                value: 1,
                                title: '',
                                radius: widget.sectionRadius,
                              ),
                            ],
                    ),
                  ),
                ),
              ),
              if (widget.showCenterSummary)
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: hasData
                        ? selected != null
                            ? SizedBox(
                                width: 110,
                                child: Column(
                                  key: const ValueKey('selected'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      getCategoryTranslation(
                                          context, selected.category),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        displayAmount(selected.amount),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.8,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                width: 110,
                                child: Column(
                                  key: const ValueKey('total'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        displayAmount(totalSpent),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1.0,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      context.l10n.spent,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                        : Column(
                            key: const ValueKey('empty'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.noData,
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
        _buildLegend(context, colorScheme, categorySummaries),
      ],
    );
  }

  Widget _buildLegend(
    BuildContext context,
    ColorScheme colorScheme,
    List<CategorySummary> categorySummaries,
  ) {
    final legend = Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: widget.legendAlignment,
      children: categorySummaries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final isSelected = _touchedIndex == index;
        return GestureDetector(
          onTap: () {
            setState(() {
              _touchedIndex = isSelected ? null : index;
            });
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _touchedIndex == null || isSelected ? 1 : 0.55,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    getCategoryTranslation(context, category.category),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: colorScheme.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (widget.legendViewportHeight == null) {
      return Padding(
        padding: widget.legendPadding,
        child: legend,
      );
    }

    return Padding(
      padding: widget.legendPadding,
      child: SizedBox(
        height: widget.legendViewportHeight,
        child: SingleChildScrollView(
          child: legend,
        ),
      ),
    );
  }
}

class SpendingBreakdownChart extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
  final UserContact? contact;
  final DateRangeFilter dateRangeFilter;
  final String? selectedCurrency;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const SpendingBreakdownChart({
    super.key,
    required this.colorScheme,
    required this.expenses,
    required this.budgets,
    required this.contact,
    required this.dateRangeFilter,
    this.selectedCurrency,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  State<SpendingBreakdownChart> createState() => _SpendingBreakdownChartState();
}

class _SpendingBreakdownChartState extends State<SpendingBreakdownChart> {
  @override
  Widget build(BuildContext context) {
    // Resolve this card's date range and filter the full lists locally.
    final range = getDateRangeFromFilter(
      widget.dateRangeFilter,
      widget.customStartDate,
      widget.customEndDate,
    );
    final from = range['from']!;
    final to = range['to']!;
    final selectedCode = widget.selectedCurrency?.toUpperCase();

    final filteredExpenses = widget.expenses.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final dateOk = !d.isBefore(from) && !d.isAfter(to);
      final rawCode = (e.currency ?? '').trim().toUpperCase();
      final currencyOk =
          selectedCode == null || rawCode.isEmpty || rawCode == selectedCode;
      final type = (e.type ?? 'expense').toLowerCase();
      final isSpend = type != 'income';
      return dateOk && currencyOk && isSpend;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spendingBreakdown.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: widget.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.dateRangeFilter.getLabel(context),
            style: TextStyle(
              fontSize: 13,
              color: widget.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          CategoryPieChart(
            colorScheme: widget.colorScheme,
            expenses: filteredExpenses,
            selectedCurrency: widget.selectedCurrency,
            showCenterSummary: true,
          ),
        ],
      ),
    );
  }
}

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

/// Backward-compatible function wrapper
Widget buildSpendingBreakdownChart(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  List<DailyBudgetEntry> budgets,
  UserContact? contact,
  DateRangeFilter dateRangeFilter, {
  String? selectedCurrency,
  DateTime? customStartDate,
  DateTime? customEndDate,
}) {
  return SpendingBreakdownChart(
    colorScheme: colorScheme,
    expenses: expenses,
    budgets: budgets,
    contact: contact,
    dateRangeFilter: dateRangeFilter,
    selectedCurrency: selectedCurrency,
    customStartDate: customStartDate,
    customEndDate: customEndDate,
  );
}
