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
  int? _touchedIndex;

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

    final categorySummaries = _getCategorySummaries(filteredExpenses);
    final totalSpent = _getTotalSpent(filteredExpenses);

    // selectedCurrency is never null (defaults to USD)
    final currencyCode = widget.selectedCurrency ?? 'USD';
    final symbol = resolveCurrencySymbol(currencyCode);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasData = totalSpent > 0 && categorySummaries.isNotEmpty;
    final selected = (_touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < categorySummaries.length)
        ? categorySummaries[_touchedIndex!]
        : null;

    String displayAmount(double amount) =>
        '$symbol${formatLocalizedNumber(context, amount)}';

    String percentOfTotal(double amount) {
      if (totalSpent <= 0) return '0%';
      return '${((amount / totalSpent) * 100).toStringAsFixed(0)}%';
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.colorScheme.outline.withValues(alpha: 0.05),
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
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              setState(() => _touchedIndex = null);
                              return;
                            }
                            setState(() =>
                                _touchedIndex = response!.touchedSection!.touchedSectionIndex);
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
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
                                  title: percent > 4 ? '${percent.toStringAsFixed(0)}%' : '',
                                  radius: isTouched ? 58 : 52,
                                  titleStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: widget.colorScheme.onPrimary,
                                  ),
                                );
                              }).toList()
                            : [
                                PieChartSectionData(
                                  color: widget.colorScheme.mutedForeground
                                      .withValues(alpha: 0.15),
                                  value: 1,
                                  title: '',
                                  radius: 52,
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: hasData
                        ? selected != null
                            ? Column(
                                key: const ValueKey('selected'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    getCategoryTranslation(context, selected.category),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.colorScheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayAmount(selected.amount),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.8,
                                      color: widget.colorScheme.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    percentOfTotal(selected.amount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('total'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayAmount(totalSpent),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1.0,
                                      color: widget.colorScheme.foreground,
                                    ),
                                  ),
                                  Text(
                                    context.l10n.spent,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: widget.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              )
                        : Column(
                            key: const ValueKey('empty'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                color:
                                    widget.colorScheme.mutedForeground.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.noData,
                                style: TextStyle(
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
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: categorySummaries.take(6).map((category) {
              final percent = percentOfTotal(category.amount);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.colorScheme.surface,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getCategoryTranslation(context, category.category),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.colorScheme.foreground,
                        ),
                      ),
                      
                    ],
                  ),
                ],
              );
            }).toList(),
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
