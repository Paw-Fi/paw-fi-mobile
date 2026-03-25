import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/recurring/domain/models/payment_plan.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

class PaymentPlanListItemCard extends StatelessWidget {
  const PaymentPlanListItemCard({
    super.key,
    required this.item,
  });

  final ScheduledListItemDto item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = item.type == 'income';
    final amount = item.displayAmountCents / 100.0;
    final categoryLabel = getCategoryTranslation(context, item.category);
    final planTypeLabel = item.paymentPlanType == PaymentPlanType.installment
        ? 'Installment'
        : context.l10n.recurring;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: TransactionListTile(
          category: item.category,
          title: item.title,
          description: categoryLabel,
          date: item.nextDueDate ?? DateTime.now(),
          amount: amount,
          currency: item.currency,
          isIncome: isIncome,
          subtitleWidget: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  planTypeLabel,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.nextDueDate != null)
                Expanded(
                  child: Text(
                    formatLocalizedDate(context, item.nextDueDate!),
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          trailingWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.status == 'completed'
                  ? colorScheme.success.withValues(alpha: 0.1)
                  : colorScheme.muted,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.paymentPlanType == PaymentPlanType.installment
                  ? (item.progressText ?? item.status)
                  : item.status,
              style: TextStyle(
                color: item.status == 'completed'
                    ? colorScheme.success
                    : colorScheme.mutedForeground,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
