import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/theme/app_theme.dart';

import 'package:moneko/shared/widgets/transaction_list_tile.dart';

/// Get localized frequency text for a recurring transaction
String getLocalizedFrequencyText(
    BuildContext context, RecurringTransaction transaction) {
  final l10n = context.l10n;

  if (transaction.recurrenceRule == null) return l10n.oneTime;

  final rule = transaction.recurrenceRule!;
  switch (rule.frequency) {
    case 'daily':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXDays(rule.interval!)
          : l10n.daily;
    case 'weekly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXWeeks(rule.interval!)
          : l10n.weekly;
    case 'biweekly':
      return l10n.every2Weeks;
    case 'monthly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXMonths(rule.interval!)
          : l10n.monthly;
    case 'yearly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXYears(rule.interval!)
          : l10n.yearly;
    case 'custom':
      return l10n.custom;
    default:
      return l10n.unknown;
  }
}

/// Modern, Apple-inspired recurring transaction card with slidable actions
class RecurringTransactionCard extends ConsumerWidget {
  final RecurringTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const RecurringTransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(transaction.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) async {
                if (onDelete != null) {
                  onDelete!();
                }
              },
              backgroundColor: colorScheme.destructive,
              foregroundColor: colorScheme.onError,
              icon: Icons.delete,
              label: context.l10n.delete,
              borderRadius: BorderRadius.circular(24),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.homeCardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.homeCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.homeCardShadow,
                blurRadius: 32,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: colorScheme.surface.withValues(alpha: 0.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: TransactionListTile(
                onTap: onTap,
                category: transaction.category,
                title: transaction.description ??
                    getCategoryTranslation(context, transaction.category),
                description: transaction.description,
                date: transaction.date,
                amount: transaction.amount,
                currency: transaction.currency,
                isIncome: isIncome,
                subtitleWidget: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        getLocalizedFrequencyText(context, transaction),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        formatLocalizedDate(
                            context, transaction.getNextOccurrence()),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: transaction.isActive
                        ? colorScheme.success.withValues(alpha: 0.1)
                        : colorScheme.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.isActive
                        ? context.l10n.active
                        : context.l10n.ended,
                    style: TextStyle(
                      color: transaction.isActive
                          ? colorScheme.success
                          : colorScheme.mutedForeground,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for when there are no recurring transactions
class EmptyRecurringState extends StatelessWidget {
  final String type; // 'expense' or 'income'
  final VoidCallback? onAddPressed;

  const EmptyRecurringState({
    super.key,
    required this.type,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedType = type.trim().toLowerCase();
    final isExpense =
        normalizedType == 'expense' || normalizedType == 'expenses';
    final isIncome = normalizedType == 'income' || normalizedType == 'incomes';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense ? Icons.autorenew : Icons.trending_up,
                size: 48,
                color: colorScheme.mutedForeground,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              isExpense
                  ? context.l10n.noRecurringExpenses
                  : isIncome
                      ? context.l10n.noRecurringIncome
                      : context.l10n.noRecurringExpenses,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              isExpense
                  ? context.l10n.setupAutomaticExpenseTracking
                  : isIncome
                      ? context.l10n.setupAutomaticIncomeTracking
                      : context.l10n.setupAutomaticExpenseTracking,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
