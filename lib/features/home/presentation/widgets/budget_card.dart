import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildBudgetCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> expenses,
  UserContact? contact,
  DateRangeFilter filter, {
  VoidCallback? onTap,
  String? selectedCurrency,
}) {
  final totalBudget = _getTotalBudget(budgets);

  // selectedCurrency is never null (defaults to USD)
  final displayText = formatCurrency(totalBudget, selectedCurrency ?? 'USD');

  final title = _budgetTitleForFilter(context, filter);

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                color: colorScheme.foreground,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 16, color: colorScheme.mutedForeground),
                const SizedBox(width: 6),
                Text(
                  '${expenses.length} ${context.l10n.transactions}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

double _getTotalBudget(List<DailyBudgetEntry> budgets) {
  return budgets.fold(0.0, (sum, b) => sum + b.amount);
}

String _budgetTitleForFilter(BuildContext context, DateRangeFilter filter) {
  final l10n = context.l10n;
  switch (filter) {
    case DateRangeFilter.today:
      return l10n.todaysBudget;
    case DateRangeFilter.yesterday:
      return l10n.yesterdaysBudget;
    case DateRangeFilter.thisWeek:
      return l10n.sumOfDailyBudgetsThisWeek;
    case DateRangeFilter.lastWeek:
      return l10n.sumOfDailyBudgetsLastWeek;
    case DateRangeFilter.last7Days:
      return l10n.sumOfDailyBudgetsForSelectedRange;
    case DateRangeFilter.thisMonth:
      return l10n.sumOfDailyBudgetsThisMonth;
    case DateRangeFilter.lastMonth:
      return l10n.sumOfDailyBudgetsForSelectedRange;
    case DateRangeFilter.last30Days:
      return l10n.sumOfDailyBudgetsLast30Days;
    case DateRangeFilter.thisYear:
      return l10n.sumOfDailyBudgetsForSelectedRange;
    case DateRangeFilter.allTime:
      // Use generic label to avoid introducing new l10n keys per locale
      return l10n.sumOfDailyBudgetsForSelectedRange;
    case DateRangeFilter.custom:
      return l10n.sumOfDailyBudgetsForSelectedRange;
  }
}
