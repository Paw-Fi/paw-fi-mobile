import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';

class BudgetProgressCard extends ConsumerWidget {
  final SharedBudget budget;
  final String householdId;

  const BudgetProgressCard({
    super.key,
    required this.budget,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    // Calculate date range based on budget period
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (budget.period) {
      case BudgetPeriod.daily:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case BudgetPeriod.weekly:
        final weekDay = now.weekday;
        startDate = now.subtract(Duration(days: weekDay - 1)); // Monday
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case BudgetPeriod.monthly:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case BudgetPeriod.yearly:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }

    // Get summary to calculate actual spending
    final summaryAsync = ref.watch(householdSummaryProvider(
      HouseholdSummaryParams(
        householdId: householdId,
        currency: budget.currency,
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      ),
    ));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    budget.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Text(
                  _formatPeriod(budget.period),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              data: (summary) {
                final spentCents = summary?.totals.totalExpensesCents ?? 0;
                final percentageUsed = budget.amountCents > 0
                    ? (spentCents / budget.amountCents).clamp(0.0, 1.0)
                    : 0.0;

                Color progressColor = colorScheme.primary;
                if (percentageUsed >= budget.alertThreshold) {
                  progressColor = colorScheme.destructive;
                } else if (percentageUsed >= budget.warnThreshold) {
                  progressColor = Colors.orange;
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatMoney(spentCents)} / ${_formatMoney(budget.amountCents)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '${(percentageUsed * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percentageUsed,
                      backgroundColor: colorScheme.muted,
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text('Error loading data', style: TextStyle(color: colorScheme.destructive)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeriod(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.daily:
        return 'Daily';
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  String _formatMoney(int cents) {
    final amount = cents / 100;
    return budget.currency + ' ' + amount.toStringAsFixed(2);
  }
}
