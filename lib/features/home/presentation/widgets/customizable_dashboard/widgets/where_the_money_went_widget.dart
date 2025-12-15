import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

class WhereTheMoneyWentWidget extends StatelessWidget {
  final List<ExpenseEntry> expenses;
  final String? currency;
  final VoidCallback? onHelpTap;
  final DateRangeFilter dateRange;

  const WhereTheMoneyWentWidget({
    super.key,
    required this.expenses,
    this.currency,
    this.onHelpTap,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter expenses by selected currency if applicable
    var filteredExpenses = expenses;
    if (currency != null) {
      final curr = currency!.toUpperCase();
      filteredExpenses =
          expenses.where((e) => e.currency?.toUpperCase() == curr).toList();
    }

    // Aggregate by category for quick stats/legends
    final Map<String, double> categoryTotals = {};
    for (final expense in filteredExpenses) {
      final cat = expense.category ?? 'uncategorized';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount.abs();
    }

    final totalSpent = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String formatAmount(double amount) {
      final symbol = resolveCurrencySymbol(currency ?? 'USD');
      return '$symbol${formatLocalizedNumber(context, amount)}';
    }

    String percent(double amount) =>
        totalSpent == 0 ? '0%' : '${((amount / totalSpent) * 100).toStringAsFixed(0)}%';

    return Material(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.chartBackground,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.whereTheMoneyWent.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateRange.getLabel(context),
                      style: WidgetTextStyles.dateLabel(
                          colorScheme.mutedForeground),
                    ),
                  ],
                ),
                if (onHelpTap != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: colorScheme.mutedForeground,
                    ),
                    onPressed: onHelpTap,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredExpenses.isEmpty)
              _EmptyState(colorScheme: colorScheme)
            else ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 300,
                child: buildCategoryBarChart(
                    context, colorScheme, filteredExpenses),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: sortedCategories.take(6).map((entry) {
                  final name = getCategoryTranslation(context, entry.key);
                  return _LegendChip(
                    label: name,
                    value: '${formatAmount(entry.value)} · ${percent(entry.value)}',
                    color: getCategoryColor(entry.key),
                    colorScheme: colorScheme,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  const _LegendChip({
    required this.label,
    required this.value,
    required this.color,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.foreground,
                ),
              ),
             
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stacked_bar_chart_outlined,
            color: colorScheme.mutedForeground,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noData,
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}
