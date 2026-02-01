import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

class DashboardTransactionsList extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final String? currency;
  final VoidCallback? onViewAll;

  const DashboardTransactionsList({
    super.key,
    required this.transactions,
    this.currency,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter
    final filtered = transactions;

    final recent = filtered.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text('See All'),
                ),
            ],
          ),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No recent transactions',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 56,
                color: colorScheme.onSurface.withOpacity(0.05),
              ),
              itemBuilder: (context, index) {
                final tx = recent[index];
                final categoryId = tx.entry.category ?? 'uncategorized';
                final isIncome = tx.entry.type == 'income';
                final categoryName =
                    getCategoryTranslation(context, categoryId);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TransactionListTile(
                    category: categoryId,
                    title: tx.entry.rawText ?? categoryName,
                    amount: tx.entry.amountCents / 100.0,
                    currency: tx.entry.currency ?? 'USD',
                    isIncome: isIncome,
                    date: tx.entry.date,
                    subtitleWidget: Row(
                      children: [
                        if (tx.accountLabel != 'Personal')
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.accountLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        Text(
                          _formatDate(context, tx.entry.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Navigate or show details
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    // Simple formatter, Tile has its own but we overrode subtitle.
    // Actually Tile's _formatDate is private.
    // We can just use standard DateFormat.
    return DateFormat.MMMd().format(date);
  }
}
