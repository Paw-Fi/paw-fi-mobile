import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';

Widget buildNetCashflowCard(shadcnui.ColorScheme colorScheme, List<DailyBudgetEntry> budgets, List<ExpenseEntry> expenses, UserContact? contact) {
  final totalBudget = _getTotalBudget(budgets);
  final totalSpent = _getTotalSpent(expenses);
  final currencySymbol = _getCurrencySymbol(contact);
  final netCashflow = totalBudget - totalSpent;
  final isNegative = netCashflow < 0;

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
            'Net cashflow',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isNegative ? '-' : ''}$currencySymbol${netCashflow.abs().toStringAsFixed(0)}',
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
  return expenses.where((e) => e.amountCents > 0).fold(0.0, (sum, e) => sum + e.amount);
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
