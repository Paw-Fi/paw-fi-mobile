import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import '../dashboard_config.dart';

/// Recurring Expenses Summary Widget
/// Answers: "What are my recurring costs?"
class RecurringExpensesSummaryWidget extends ConsumerWidget {
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DashboardWidgetConfig config;

  const RecurringExpensesSummaryWidget({
    super.key,
    required this.recurringTransactions,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Filter active recurring expenses in selected currency
    final activeRecurring = recurringTransactions
        .where((t) => t.type == 'expense' && t.currency == currency && t.isActive)
        .toList();
    
    // Calculate monthly equivalent
    final monthlyTotal = activeRecurring.fold<double>(0, (sum, t) {
      switch (t.recurrenceRule?.frequency) {
        case 'daily':
          return sum + (t.amount * 30);
        case 'weekly':
          return sum + (t.amount * 4.33);
        case 'biweekly':
          return sum + (t.amount * 2.17);
        case 'monthly':
          return sum + t.amount;
        case 'yearly':
          return sum + (t.amount / 12);
        default:
          return sum + t.amount;
      }
    });
    
    // Get top 3 by monthly amount
    final sortedRecurring = List<RecurringTransaction>.from(activeRecurring)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topThree = sortedRecurring.take(3).toList();
    
    // Check for upcoming items (next 7 days)
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    final upcomingCount = activeRecurring.where((t) {
      final nextDate = t.getNextOccurrence(now);
      return nextDate.isBefore(sevenDaysFromNow);
    }).length;

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'recurringExpensesSummary',
          'config': config,
          'currency': currency,
        });
      },
      child: Card(
        color: colorScheme.cardSurface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.recurringExpenses,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (upcomingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$upcomingCount upcoming',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Monthly total
              Text(
                formatCurrency(monthlyTotal, currency),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                  height: 1.1,
                ),
              ),
              Text(
                context.l10n.perMonth,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              
              // Count
              Text(
                '${activeRecurring.length} ${context.l10n.activeSubscriptions}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              
              // Top 3 list
              if (topThree.isEmpty)
                Center(
                  child: Text(
                    context.l10n.noRecurringExpenses,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                )
              else
                ...topThree.map((transaction) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.description ?? transaction.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                transaction.frequencyText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCurrency(transaction.amount, currency),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
