import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';

Widget buildNetCashflowCard(
  BuildContext context,
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
  
  final title = _netCashflowTitleForFilter(context, filter);

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
                isNegative ? context.l10n.negative : context.l10n.positive,
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

String _netCashflowTitleForFilter(BuildContext context, DateRangeFilter filter) {
  final l10n = context.l10n;
  switch (filter) {
    case DateRangeFilter.today:
      return l10n.netCashflowToday;
    case DateRangeFilter.yesterday:
      return l10n.netCashflowYesterday;
    case DateRangeFilter.thisWeek:
      return l10n.netCashflowThisWeek;
    case DateRangeFilter.lastWeek:
      return l10n.netCashflowLastWeek;
    case DateRangeFilter.thisMonth:
      return l10n.netCashflowThisMonth;
    case DateRangeFilter.last30Days:
      return l10n.netCashflowLast30Days;
    case DateRangeFilter.allTime:
      // Use generic label to avoid adding new l10n keys across locales
      return l10n.netCashflowCustom;
    case DateRangeFilter.custom:
      return l10n.netCashflowCustom;
  }
}
