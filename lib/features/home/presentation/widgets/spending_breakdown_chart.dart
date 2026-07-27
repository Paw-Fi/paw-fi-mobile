import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/animated_amount_text.dart';

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
  final int? legendItemLimit;
  final EdgeInsetsGeometry legendPadding;
  final double? legendViewportHeight;

  const CategoryPieChart({
    super.key,
    required this.colorScheme,
    required this.expenses,
    this.selectedCurrency,
    this.showCenterSummary = false,
    this.chartSize = 200,
    this.centerSpaceRadius = 75,
    this.sectionRadius = 30,
    this.touchedSectionRadius = 35,
    this.legendAlignment = WrapAlignment.start,
    this.legendItemLimit,
    this.legendPadding = const EdgeInsets.only(top: 24),
    this.legendViewportHeight,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _touchedIndex;
  _CategoryPieChartCacheKey? _cachedKey;
  _CategoryPieChartDerivedData? _cachedData;

  @override
  void dispose() {
    super.dispose();
  }

  List<CategorySummary> _buildChartSummaries(
    BuildContext context,
    ColorScheme colorScheme,
    List<ExpenseEntry> expenses,
  ) {
    final summaries = _getCategorySummaries(context, expenses);
    final limit = widget.legendItemLimit;
    if (limit == null || summaries.length <= limit) {
      return summaries;
    }

    final visibleCount = limit - 1;
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
    final derivedData = _derivedDataFor(context, colorScheme);
    final categorySummaries = derivedData.categorySummaries;
    final totalSpent = derivedData.totalSpent;
    final hasData = totalSpent > 0 && categorySummaries.isNotEmpty;
    final selected = (_touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < categorySummaries.length)
        ? categorySummaries[_touchedIndex!]
        : null;

    final currencyCode = widget.selectedCurrency ?? 'USD';
    final symbol = resolveCurrencySymbol(currencyCode);

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
                                final nextIndex = response!
                                    .touchedSection!.touchedSectionIndex;
                                _touchedIndex = _touchedIndex == nextIndex
                                    ? null
                                    : nextIndex;
                              });
                            }
                          } else if (event is FlTapUpEvent ||
                              event is FlTapCancelEvent) {
                            setState(() => _touchedIndex = null);
                          }
                        },
                      ),
                      sectionsSpace: 4,
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
                                title: '',
                                badgePositionPercentageOffset: 0.5,
                                badgeWidget: percent > 4
                                    ? AnimatedAmountText(
                                        value: percent,
                                        symbol: '',
                                        suffix: '%',
                                        decimalDigits: 0,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : null,
                                radius: isTouched
                                    ? widget.touchedSectionRadius
                                    : widget.sectionRadius,
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
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
              if (widget.showCenterSummary)
                Center(
                  child: hasData
                      ? SizedBox(
                          width: 110,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 18,
                                child: Text(
                                  selected == null
                                      ? ''
                                      : getCategoryTranslation(
                                          context,
                                          selected.category,
                                        ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedAmountText(
                                  value: selected?.amount ?? totalSpent,
                                  symbol: symbol,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.9,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 18,
                                child: Text(
                                  selected == null ? context.l10n.spent : '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
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
      children: categorySummaries.asMap().entries.map((entry) {
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

  _CategoryPieChartDerivedData _derivedDataFor(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final expensesIdentity = identityHashCode(widget.expenses);
    final cached = _cachedData;
    final cachedKey = _cachedKey;
    if (cached != null &&
        cachedKey != null &&
        cachedKey.expensesIdentity == expensesIdentity &&
        cachedKey.legendItemLimit == widget.legendItemLimit &&
        cachedKey.otherColor == colorScheme.muted) {
      return cached;
    }

    final key = _CategoryPieChartCacheKey(
      expensesIdentity: expensesIdentity,
      expensesSignature: _expenseListSignature(widget.expenses),
      legendItemLimit: widget.legendItemLimit,
      otherColor: colorScheme.muted,
    );
    if (cached != null && _cachedKey == key) {
      return cached;
    }

    final spendOnly = widget.expenses
        .where((expense) => expense.effectiveSpendingMultiplier != 0)
        .toList(growable: false);
    final next = _CategoryPieChartDerivedData(
      categorySummaries: _buildChartSummaries(context, colorScheme, spendOnly),
      totalSpent: _getTotalSpent(spendOnly),
    );
    _cachedKey = key;
    _cachedData = next;
    return next;
  }
}

class SpendingBreakdownChart extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
  final UserContact? contact;
  final DateRangeFilter dateRangeFilter;
  final DateTime? referenceNow;
  final String? selectedCurrency;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final int financialMonthStartDay;

  const SpendingBreakdownChart({
    super.key,
    required this.colorScheme,
    required this.expenses,
    required this.budgets,
    required this.contact,
    required this.dateRangeFilter,
    this.referenceNow,
    this.selectedCurrency,
    this.customStartDate,
    this.customEndDate,
    this.financialMonthStartDay = 1,
  });

  @override
  State<SpendingBreakdownChart> createState() => _SpendingBreakdownChartState();
}

class _SpendingBreakdownChartState extends State<SpendingBreakdownChart> {
  _SpendingBreakdownCacheKey? _cachedKey;
  List<ExpenseEntry>? _cachedFilteredExpenses;

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _filteredExpensesFor();

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

  List<ExpenseEntry> _filteredExpensesFor() {
    final now = widget.referenceNow ?? DateTime.now();
    final expensesIdentity = identityHashCode(widget.expenses);
    final referenceDayKey =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final selectedCurrency = widget.selectedCurrency?.trim().toUpperCase();
    final customStartDateKey = widget.customStartDate?.microsecondsSinceEpoch;
    final customEndDateKey = widget.customEndDate?.microsecondsSinceEpoch;
    final cached = _cachedFilteredExpenses;
    final cachedKey = _cachedKey;
    if (cached != null &&
        cachedKey != null &&
        cachedKey.expensesIdentity == expensesIdentity &&
        cachedKey.dateRangeFilter == widget.dateRangeFilter &&
        cachedKey.referenceDayKey == referenceDayKey &&
        cachedKey.selectedCurrency == selectedCurrency &&
        cachedKey.customStartDateKey == customStartDateKey &&
        cachedKey.customEndDateKey == customEndDateKey &&
        cachedKey.financialMonthStartDay == widget.financialMonthStartDay) {
      return cached;
    }

    final key = _SpendingBreakdownCacheKey(
      expensesIdentity: expensesIdentity,
      expensesSignature: _expenseListSignature(widget.expenses),
      dateRangeFilter: widget.dateRangeFilter,
      referenceDayKey: referenceDayKey,
      selectedCurrency: selectedCurrency,
      customStartDateKey: customStartDateKey,
      customEndDateKey: customEndDateKey,
      financialMonthStartDay: widget.financialMonthStartDay,
    );
    if (cached != null && _cachedKey == key) {
      return cached;
    }

    final range = getDateRangeFromFilter(
      widget.dateRangeFilter,
      widget.customStartDate,
      widget.customEndDate,
      now: now,
      financialMonthStartDay: widget.financialMonthStartDay,
    );
    final from = range['from']!;
    final to = range['to']!;
    final selectedCode = widget.selectedCurrency?.toUpperCase();

    final next = widget.expenses.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final dateOk = !d.isBefore(from) && !d.isAfter(to);
      final rawCode = (e.currency ?? '').trim().toUpperCase();
      final currencyOk =
          selectedCode == null || rawCode.isEmpty || rawCode == selectedCode;
      final isSpend = e.effectiveSpendingMultiplier != 0;
      return dateOk && currencyOk && isSpend;
    }).toList(growable: false);
    _cachedKey = key;
    _cachedFilteredExpenses = next;
    return next;
  }
}

class _CategoryPieChartDerivedData {
  const _CategoryPieChartDerivedData({
    required this.categorySummaries,
    required this.totalSpent,
  });

  final List<CategorySummary> categorySummaries;
  final double totalSpent;
}

class _CategoryPieChartCacheKey {
  const _CategoryPieChartCacheKey({
    required this.expensesIdentity,
    required this.expensesSignature,
    required this.legendItemLimit,
    required this.otherColor,
  });

  final int expensesIdentity;
  final int expensesSignature;
  final int? legendItemLimit;
  final Color otherColor;

  @override
  bool operator ==(Object other) {
    return other is _CategoryPieChartCacheKey &&
        other.expensesSignature == expensesSignature &&
        other.legendItemLimit == legendItemLimit &&
        other.otherColor == otherColor;
  }

  @override
  int get hashCode => Object.hash(
        expensesSignature,
        legendItemLimit,
        otherColor,
      );
}

class _SpendingBreakdownCacheKey {
  const _SpendingBreakdownCacheKey({
    required this.expensesIdentity,
    required this.expensesSignature,
    required this.dateRangeFilter,
    required this.referenceDayKey,
    required this.selectedCurrency,
    required this.customStartDateKey,
    required this.customEndDateKey,
    required this.financialMonthStartDay,
  });

  final int expensesIdentity;
  final int expensesSignature;
  final DateRangeFilter dateRangeFilter;
  final int referenceDayKey;
  final String? selectedCurrency;
  final int? customStartDateKey;
  final int? customEndDateKey;
  final int financialMonthStartDay;

  @override
  bool operator ==(Object other) {
    return other is _SpendingBreakdownCacheKey &&
        other.expensesSignature == expensesSignature &&
        other.dateRangeFilter == dateRangeFilter &&
        other.referenceDayKey == referenceDayKey &&
        other.selectedCurrency == selectedCurrency &&
        other.customStartDateKey == customStartDateKey &&
        other.customEndDateKey == customEndDateKey &&
        other.financialMonthStartDay == financialMonthStartDay;
  }

  @override
  int get hashCode => Object.hash(
        expensesSignature,
        dateRangeFilter,
        referenceDayKey,
        selectedCurrency,
        customStartDateKey,
        customEndDateKey,
        financialMonthStartDay,
      );
}

List<CategorySummary> _getCategorySummaries(
    BuildContext context, List<ExpenseEntry> expenses) {
  final Map<String, double> categoryTotals = {};
  final Map<String, int> categoryCounts = {};

  for (final expense in expenses) {
    final cat = canonicalizeCategoryKey(expense.category);
    categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.spendingEffect;
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
  }

  return categoryTotals.entries.where((entry) => entry.value > 0).map((e) {
    return CategorySummary(
      category: e.key,
      amount: e.value,
      transactionCount: categoryCounts[e.key] ?? 0,
      color: getCategoryColor(e.key, context),
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

double _getTotalSpent(List<ExpenseEntry> expenses) {
  return expenses.fold(0.0, (sum, e) => sum + e.spendingEffect);
}

int _expenseListSignature(List<ExpenseEntry> expenses) {
  var hash = expenses.length;
  for (final expense in expenses) {
    hash = Object.hash(
      hash,
      expense.date.millisecondsSinceEpoch,
      expense.amountCents,
      expense.amount,
      expense.currency,
      expense.type,
      expense.category,
      expense.analyticsClass,
      expense.analyticsIsFinal,
      expense.analyticsSpendingMultiplier,
      expense.analyticsCountsTowardIncome,
    );
  }
  return hash;
}

/// Backward-compatible function wrapper
Widget buildSpendingBreakdownChart(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  List<DailyBudgetEntry> budgets,
  UserContact? contact,
  DateRangeFilter dateRangeFilter, {
  Key? key,
  DateTime? referenceNow,
  String? selectedCurrency,
  DateTime? customStartDate,
  DateTime? customEndDate,
  int financialMonthStartDay = 1,
}) {
  return SpendingBreakdownChart(
    key: key,
    colorScheme: colorScheme,
    expenses: expenses,
    budgets: budgets,
    contact: contact,
    dateRangeFilter: dateRangeFilter,
    referenceNow: referenceNow,
    selectedCurrency: selectedCurrency,
    customStartDate: customStartDate,
    customEndDate: customEndDate,
    financialMonthStartDay: financialMonthStartDay,
  );
}
