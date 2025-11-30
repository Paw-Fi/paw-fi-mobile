import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildSpendingBreakdownChart(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  List<DailyBudgetEntry> budgets,
  UserContact? contact,
  DateRangeFilter dateRangeFilter, {
  String? selectedCurrency,
}) {
  // Resolve this card's date range and filter the full lists locally.
  final range = getDateRangeFromFilter(dateRangeFilter, null, null);
  final from = range['from']!;
  final to = range['to']!;
  final selectedCode = selectedCurrency?.toUpperCase();

  final filteredExpenses = expenses.where((e) {
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
  final displayText = formatCurrency(totalSpent, selectedCurrency ?? 'USD');

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    decoration: BoxDecoration(
      color: colorScheme.cardSurface,
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
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateRangeFilter.getLabel(context),
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: categorySummaries.map((category) {
                    return PieChartSectionData(
                      color: category.color,
                      value: category.amount,
                      title: '',
                      radius: 50,
                    );
                  }).toList(),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: colorScheme.foreground,
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: categorySummaries.take(4).map((category) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  getCategoryTranslation(context, category.category),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    ),
  );
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
