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
  List<ExpenseEntry> transactions,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
}) {
  // Net cashflow = income - expenses (budget not used in calculation)
  final totals = _getIncomeAndExpenses(transactions);
  final totalIncome = totals.$1;
  final totalSpent = totals.$2;
  final netCashflow = totalIncome - totalSpent;
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

/// Returns (income, expenses)
(double, double) _getIncomeAndExpenses(List<ExpenseEntry> transactions) {
  double income = 0;
  double spend = 0;
  for (final t in transactions) {
    final ttype = (t.type ?? 'expense').toLowerCase();
    if (ttype == 'income') {
      income += t.amount.abs();
    } else {
      spend += t.amount.abs();
    }
  }
  return (income, spend);
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
