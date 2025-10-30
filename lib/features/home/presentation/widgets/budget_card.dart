import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';

Widget buildBudgetCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
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

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const Spacer(),
            Text(
              '${expenses.length} ${context.l10n.transactions}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
              ),
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
    case DateRangeFilter.thisMonth:
      return l10n.sumOfDailyBudgetsThisMonth;
    case DateRangeFilter.last30Days:
      return l10n.sumOfDailyBudgetsLast30Days;
    case DateRangeFilter.custom:
      return l10n.sumOfDailyBudgetsForSelectedRange;
  }
}

