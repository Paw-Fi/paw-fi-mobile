import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/utils/date_formatter.dart';

/// Get localized frequency text for a recurring transaction
String getLocalizedFrequencyText(BuildContext context, RecurringTransaction transaction) {
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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';
    final categoryColor = getCategoryColor(transaction.category);
    final categoryIcon = getCategoryIcon(transaction.category);

    // Use the currency utility for proper symbol display
    final currencySymbol = resolveCurrencySymbol(transaction.currency);
    final currencyFormat = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );

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
              backgroundColor: const Color(0xFFFE4A49),
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: context.l10n.delete,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.border.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Category icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category name
                          Text(
                            getCategoryTranslation(context, transaction.category),
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Frequency and next occurrence
                          Row(
                            children: [
                              // Frequency badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.muted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  getLocalizedFrequencyText(context, transaction),
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              const Icon(Icons.repeat, size: 12),
                              const SizedBox(width: 2),
                              // Next occurrence
                              Flexible(
                                child: Text(
                                  formatLocalizedDate(context, transaction.getNextOccurrence()),
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Amount and actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Amount
                        Text(
                          '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                          style: TextStyle(
                            color: isIncome
                                ? const Color(0xFF10B981)
                                : colorScheme.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),

                        // Status indicator
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: transaction.isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : colorScheme.muted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.isActive ? context.l10n.active : context.l10n.ended,
                            style: TextStyle(
                              color: transaction.isActive
                                  ? const Color(0xFF10B981)
                                  : colorScheme.mutedForeground,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isExpense = type == 'expense';

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
              isExpense ? context.l10n.noRecurringExpenses : context.l10n.noRecurringIncome,
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
                  : context.l10n.setupAutomaticIncomeTracking,
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
