import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';

Widget buildBudgetCard(
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
  final currencySymbol = resolveCurrencySymbol(selectedCurrency ?? 'USD');
  final displayText = '$currencySymbol${totalBudget.toStringAsFixed(0)}';
  
  final title = _budgetTitleForFilter(filter);

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
              '${expenses.length} transactions',
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

String _budgetTitleForFilter(DateRangeFilter filter) {
  switch (filter) {
    case DateRangeFilter.today:
      return "Today's budget";
    case DateRangeFilter.yesterday:
      return "Yesterday's budget";
    case DateRangeFilter.thisWeek:
      return 'Sum of daily budgets this week';
    case DateRangeFilter.lastWeek:
      return 'Sum of daily budgets last week';
    case DateRangeFilter.thisMonth:
      return 'Sum of daily budgets this month';
    case DateRangeFilter.last30Days:
      return 'Sum of daily budgets over the last 30 days';
    case DateRangeFilter.custom:
      return 'Sum of daily budgets for the selected range';
  }
}

