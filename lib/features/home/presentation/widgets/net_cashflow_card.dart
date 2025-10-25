import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';

Widget buildNetCashflowCard(
  shadcnui.ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> expenses,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
}) {
  final totalBudget = _getTotalBudget(budgets);
  final totalSpent = _getTotalSpent(expenses);
  final netCashflow = totalBudget - totalSpent;
  final isNegative = netCashflow < 0;
  
  // selectedCurrency is never null (defaults to USD)
  final absAmount = netCashflow.abs();
  final formattedAmount = formatCurrency(absAmount, selectedCurrency ?? 'USD');
  final displayText = isNegative ? '-$formattedAmount' : formattedAmount;
  
  final title = _netCashflowTitleForFilter(filter);

  return Container(
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
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.circle,
                color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 8,
              ),
              const SizedBox(width: 4),
              Text(
                isNegative ? 'Negative' : 'Positive',
                style: TextStyle(
                  fontSize: 12,
                  color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

double _getTotalBudget(List<DailyBudgetEntry> budgets) {
  return budgets.fold(0.0, (sum, b) => sum + b.amount);
}

double _getTotalSpent(List<ExpenseEntry> expenses) {
  // Treat all rows as spending and sum absolute values for consistency
  return expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
}

String _netCashflowTitleForFilter(DateRangeFilter filter) {
  switch (filter) {
    case DateRangeFilter.today:
      return "Net cashflow today";
    case DateRangeFilter.yesterday:
      return "Net cashflow yesterday";
    case DateRangeFilter.thisWeek:
      return 'Net cashflow this week';
    case DateRangeFilter.lastWeek:
      return 'Net cashflow last week';
    case DateRangeFilter.thisMonth:
      return 'Net cashflow this month';
    case DateRangeFilter.last30Days:
      return 'Net cashflow (last 30 days)';
    case DateRangeFilter.custom:
      return 'Net cashflow (custom)';
  }
}

