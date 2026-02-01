import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:collection/collection.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

class DashboardCategoryList extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final String currency;

  const DashboardCategoryList({
    super.key,
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Filter and Group
    final validTx = transactions.where((tx) =>
        tx.entry.date
            .isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
        tx.entry.type != 'income');

    final grouped = validTx.groupListsBy((tx) => tx.entry.category);

    // Calculate totals
    final categoryTotals = grouped.entries.map((entry) {
      final catId = entry.key;
      final txs = entry.value;
      final total = txs.fold<int>(0, (sum, tx) => sum + tx.entry.amountCents);

      final name = getCategoryTranslation(context, catId);

      return _CategoryTotal(
        id: catId ?? 'uncategorized',
        name: name,
        amount: total / 100.0,
        transactionCount: txs.length,
      );
    }).toList();

    // Sort descending
    categoryTotals.sort((a, b) => b.amount.compareTo(a.amount));

    final topCategories = categoryTotals.take(5).toList();
    final maxAmount = topCategories.isNotEmpty ? topCategories.first.amount : 0;

    final currencySymbol =
        NumberFormat.simpleCurrency(name: currency).currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Top Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        if (topCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No spending this month',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          )
        else
          ...topCategories.map((cat) {
            final percent = maxAmount > 0 ? cat.amount / maxAmount : 0.0;
            final color = getCategoryColor(cat.id);

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  // Icon placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(getCategoryIcon(cat.id), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Text(
                              '$currencySymbol${cat.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Stack(
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor:
                                  percent, // Relative to max for visual scaling, or relative to budget?
                              // "Spent vs planned" - usually relative to budget.
                              // If no budget, visually scaling relative to highest category is a good fallback for distribution.
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _CategoryTotal {
  final String id;
  final String name;
  final double amount;
  final int transactionCount;

  _CategoryTotal(
      {required this.id,
      required this.name,
      required this.amount,
      required this.transactionCount});
}
