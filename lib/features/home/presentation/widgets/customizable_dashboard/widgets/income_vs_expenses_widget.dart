import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import '../dashboard_config.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

/// Income vs Expenses Widget
/// Answers: "Am I saving money?"
class IncomeVsExpensesWidget extends ConsumerWidget {
  final List<ExpenseEntry> expenses;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DashboardWidgetConfig config;

  const IncomeVsExpensesWidget({
    super.key,
    required this.expenses,
    required this.recurringTransactions,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Get date range
    final range = getDateRangeFromFilter(config.dateRange, config.customStartDate, config.customEndDate);
    
    // Calculate income from transactions
    final incomeFromTransactions = expenses
        .where((e) =>
            e.currency == currency &&
            e.date.isAfter(range['from']!.subtract(const Duration(days: 1))) &&
            e.date.isBefore(range['to']!.add(const Duration(days: 1))) &&
            e.type == 'income')
        .fold<double>(0, (sum, e) => sum + e.amount);
    
    // Calculate income from recurring
    final incomeFromRecurring = recurringTransactions
        .where((t) => t.type == 'income' && t.currency == currency && t.isActive)
        .fold<double>(0, (sum, t) => sum + _convertToMonthly(t.amount, t.recurrenceRule?.frequency));
    
    final totalIncome = incomeFromTransactions + incomeFromRecurring;
    
    // Calculate expenses
    final totalExpenses = expenses
        .where((e) =>
            e.currency == currency &&
            e.date.isAfter(range['from']!.subtract(const Duration(days: 1))) &&
            e.date.isBefore(range['to']!.add(const Duration(days: 1))) &&
            e.type != 'income')
        .fold<double>(0, (sum, e) => sum + e.amount);
    
    final net = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (net / totalIncome * 100) : 0.0;
    final expenseRatio = totalIncome > 0 ? (totalExpenses / totalIncome).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'incomeVsExpenses',
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
              Text(
                context.l10n.incomeVsExpenses,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              
              // Income vs Expenses
              Row(
                children: [
                  Expanded(
                    child: _buildColumn(
                      context,
                      colorScheme,
                      context.l10n.earned,
                      totalIncome,
                      currency,
                      AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildColumn(
                      context,
                      colorScheme,
                      context.l10n.spent,
                      totalExpenses,
                      currency,
                      colorScheme.destructive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Net
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (net >= 0 ? AppTheme.success : colorScheme.destructive)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          net >= 0 ? context.l10n.surplus : context.l10n.deficit,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: net >= 0 ? AppTheme.success : colorScheme.destructive,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(net.abs(), currency),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: net >= 0 ? AppTheme.success : colorScheme.destructive,
                          ),
                        ),
                      ],
                    ),
                    if (totalIncome > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            context.l10n.savingsRate,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          Text(
                            '${savingsRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: net >= 0 ? AppTheme.success : colorScheme.destructive,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: expenseRatio,
                  minHeight: 8,
                  backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    expenseRatio > 0.9 ? colorScheme.destructive : colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    double amount,
    String currency,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatCurrency(amount, currency),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  double _convertToMonthly(double amount, String? frequency) {
    switch (frequency) {
      case 'daily':
        return amount * 30;
      case 'weekly':
        return amount * 4.33;
      case 'biweekly':
        return amount * 2.17;
      case 'monthly':
        return amount;
      case 'yearly':
        return amount / 12;
      default:
        return amount;
    }
  }
}
