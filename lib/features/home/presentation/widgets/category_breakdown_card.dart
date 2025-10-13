import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
Widget buildCategoryBreakdownCard(BuildContext context, shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact) {
  final categorySummaries = _getCategorySummaries(expenses);
  final totalSpent = _getTotalSpent(expenses);
  final currencySymbol = _getCurrencySymbol(contact);

  return GestureDetector(
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TransactionsPage(),
        ),
      );
    },
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
            'By Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...categorySummaries.take(5).map((category) {
            final percentage = category.getPercentage(totalSpent);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getCategoryIcon(category.category),
                      color: category.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.category.substring(0, 1).toUpperCase() + 
                              category.category.substring(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '${category.transactionCount} transaction${category.transactionCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-$currencySymbol${category.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    ),
  );
}

List<CategorySummary> _getCategorySummaries(List<ExpenseEntry> expenses) {
  final Map<String, double> categoryTotals = {};
  final Map<String, int> categoryCounts = {};

  for (final expense in expenses) {
    if (expense.amountCents > 0) {
      final cat = (expense.category ?? 'uncategorized').toLowerCase();
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
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
