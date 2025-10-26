import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
Widget buildCategoryBreakdownCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  UserContact? contact, {
  String? selectedCurrency,
  String? householdId,
}) {
  final categorySummaries = _getCategorySummaries(expenses);
  final totalSpent = _getTotalSpent(expenses);
  
  // selectedCurrency is never null (defaults to USD)
  String formatCategoryAmount(double amount) => '-${formatCurrency(amount, selectedCurrency ?? 'USD')}';

  return GestureDetector(
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TransactionsPage(householdId: householdId),
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
            context.l10n.byCategory,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          if (categorySummaries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 48,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.noExpensesYet,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.startLoggingExpensesToSeeCategories,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                          getCategoryTranslation(context, category.category),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '${category.transactionCount} ${category.transactionCount != 1 ? context.l10n.transactions : context.l10n.transactions}',
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
                        formatCategoryAmount(category.amount),
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
    // Treat all rows in expenses as spend; use absolute for robustness
    final cat = (expense.category ?? 'uncategorized').toLowerCase();
    categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount.abs();
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
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
  // Sum absolute amounts to align with backend summary (expense-only model)
  return expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
}
