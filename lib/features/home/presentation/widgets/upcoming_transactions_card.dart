import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/upcoming_recurring_banner.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

class UpcomingTransactionsCard extends StatelessWidget {
  const UpcomingTransactionsCard({
    super.key,
    required this.upcoming,
    required this.onTap,
    required this.onViewAll,
  });

  final List<UpcomingRecurringTransaction> upcoming;
  final ValueChanged<UpcomingRecurringTransaction> onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(24);
    return Material(
      borderRadius: cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: cardRadius,
          border: Border.all(color: colorScheme.homeCardBorder),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upcoming Transactions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...upcoming.map((item) => _UpcomingTransactionRow(
                    item: item,
                    onTap: () => onTap(item),
                  )),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: onViewAll,
                  child: Text(context.l10n.viewAll),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingTransactionRow extends StatelessWidget {
  const _UpcomingTransactionRow({required this.item, required this.onTap});

  final UpcomingRecurringTransaction item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final isIncome = transaction.type == 'income';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TransactionListTile(
        category: transaction.category,
        title: transaction.category,
        description: transaction.description,
        subtitle: buildUpcomingDueLabel(context, item.daysUntil),
        amount: transaction.amount,
        currency: transaction.currency,
        isIncome: isIncome,
        onTap: onTap,
        showRecurringChip: true,
      ),
    );
  }
}
