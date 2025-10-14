import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';

Widget buildSpendingBreakdownChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact) {
  final categorySummaries = _getCategorySummaries(expenses);
  final totalSpent = _getTotalSpent(expenses);
  final currencySymbol = getCurrencySymbol(contact);
  // Calculate budget remaining (using a simple calculation based on total budget)
  final totalBudget = totalSpent * 1.5; // Assume budget is 1.5x of spent for demo
  final remaining = totalBudget - totalSpent;

  if (categorySummaries.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.border, width: 1),
    ),
    padding: const EdgeInsets.all(24.0),
    child: Column(
      children: [
        Text(
          'Spending Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This Year',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: categorySummaries.map((category) {
                    return PieChartSectionData(
                      color: category.color,
                      value: category.amount,
                      title: '',
                      radius: 50,
                    );
                  }).toList(),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: categorySummaries.take(4).map((category) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  category.category.substring(0, 1).toUpperCase() + category.category.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currencySymbol${remaining.toStringAsFixed(0)} left',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
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
