import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import '../dashboard_config.dart';

/// Budget Remaining Widget
/// Answers: "How much do I have left to spend this month?"
class BudgetRemainingWidget extends ConsumerWidget {
  final List<ExpenseEntry> expenses;
  final List<PocketEnvelope> pockets;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DashboardWidgetConfig config;

  const BudgetRemainingWidget({
    super.key,
    required this.expenses,
    required this.pockets,
    required this.recurringTransactions,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Calculate total budget from pockets
    final totalBudget = _calculateTotalBudget(pockets);
    
    // Calculate spent so far this month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final spentThisMonth = expenses
        .where((e) =>
            e.currency == currency &&
            e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            e.type != 'income')
        .fold<double>(0, (sum, e) => sum + e.amount);
    
    // Calculate recurring committed for this month
    final recurringCommitted = _calculateRecurringForMonth(recurringTransactions, currency);
    
    // Calculate remaining
    final remaining = totalBudget - spentThisMonth - recurringCommitted;
    
    // Calculate days remaining in month
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDayOfMonth.difference(now).inDays + 1;
    
    // Calculate progress percentage
    final progress = totalBudget > 0 ? (spentThisMonth / totalBudget).clamp(0.0, 1.0) : 0.0;
    
    // Determine color based on remaining budget
    Color statusColor;
    String statusText;
    if (remaining < 0) {
      statusColor = colorScheme.destructive;
      statusText = context.l10n.overBudget;
    } else if (remaining / totalBudget < 0.2) {
      statusColor = AppTheme.warning;
      statusText = context.l10n.lowBudget;
    } else if (remaining / totalBudget < 0.5) {
      statusColor = AppTheme.warning.withValues(alpha: 0.7);
      statusText = context.l10n.onTrack;
    } else {
      statusColor = AppTheme.success;
      statusText = context.l10n.healthy;
    }

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'budgetRemaining',
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
                    context.l10n.budgetRemaining,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Remaining Amount
              Text(
                formatCurrency(remaining.abs(), currency),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: remaining >= 0 ? colorScheme.foreground : colorScheme.destructive,
                  height: 1.1,
                ),
              ),
              if (remaining < 0)
                Text(
                  context.l10n.overBudget,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.destructive,
                  ),
                ),
              const SizedBox(height: 16),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 12),
              
              // Secondary Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSecondaryValue(
                    context,
                    colorScheme,
                    context.l10n.spent,
                    formatCurrency(spentThisMonth, currency),
                  ),
                  _buildSecondaryValue(
                    context,
                    colorScheme,
                    context.l10n.daysLeft,
                    '$daysRemaining',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryValue(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ],
    );
  }

  double _calculateTotalBudget(List<PocketEnvelope> pockets) {
    if (pockets.isEmpty) return 0;
    // Get budget from first pocket's budgetId (assuming all pockets share same budget)
    // This is a simplification - in reality we'd need to fetch the actual budget amount
    // For now, we'll calculate from pocket allocations
    final totalPercentage = pockets.fold<double>(0, (sum, p) => sum + p.percentage);
    if (totalPercentage == 0) return 0;
    
    // Estimate total budget from spent amounts and percentages
    double estimatedBudget = 0;
    for (final pocket in pockets) {
      if (pocket.percentage > 0) {
        final pocketBudget = (pocket.spent / pocket.percentage) * 100;
        if (pocketBudget > estimatedBudget) {
          estimatedBudget = pocketBudget;
        }
      }
    }
    return estimatedBudget;
  }

  double _calculateRecurringForMonth(
    List<RecurringTransaction> transactions,
    String currency,
  ) {
    return transactions
        .where((t) =>
            t.type == 'expense' &&
            t.currency == currency &&
            t.isActive)
        .fold<double>(0, (sum, t) {
      // Convert to monthly equivalent
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
          return sum;
      }
    });
  }
}
