import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget buildBudgetCard(shadcnui.ColorScheme colorScheme, List<DailyBudgetEntry> budgets, List<ExpenseEntry> expenses, UserContact? contact) {
  final totalBudget = _getTotalBudget(budgets);
  final currencySymbol = _getCurrencySymbol(contact);

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
            'Budget',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${totalBudget.toStringAsFixed(0)}',
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
    );
  }

double _getTotalBudget(List<DailyBudgetEntry> budgets) {
  return budgets.fold(0.0, (sum, b) => sum + b.amount);
}

String _getCurrencySymbol(UserContact? contact) {
  final cur = contact?.preferredCurrency ?? 'USD';
  switch (cur.toUpperCase()) {
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'USD':
    default:
      return '\$';
  }
}
