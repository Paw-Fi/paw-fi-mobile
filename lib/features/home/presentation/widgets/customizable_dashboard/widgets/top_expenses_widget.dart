import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../dashboard_config.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Top Expenses Widget
/// Answers: "What are my biggest expenses?"
class TopExpensesWidget extends ConsumerWidget {
  final List<ExpenseEntry> expenses;
  final String currency;
  final DashboardWidgetConfig config;

  const TopExpensesWidget({
    super.key,
    required this.expenses,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Get date range
    final range = getDateRangeFromFilter(config.dateRange, config.customStartDate, config.customEndDate);
    final from = range['from']!;
    final to = range['to']!;
    
    // Filter expenses by currency, date, and type
    final filteredExpenses = expenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(from.subtract(const Duration(days: 1))) &&
        e.date.isBefore(to.add(const Duration(days: 1))) &&
        e.type != 'income').toList();
    
    // Sort by amount descending
    filteredExpenses.sort((a, b) => b.amount.compareTo(a.amount));
    
    // Get top 5
    final topFive = filteredExpenses.take(5).toList();
    final totalOfTopFive = topFive.fold<double>(0, (sum, e) => sum + e.amount);
    final totalAll = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final percentageOfTotal = totalAll > 0 ? (totalOfTopFive / totalAll * 100) : 0.0;

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'topExpenses',
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
                    context.l10n.topExpenses,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    config.dateRange.getLabel(context),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Top 3 expenses
              if (topFive.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      context.l10n.noExpensesInPeriod,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                )
              else
                ...topFive.take(3).map((expense) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        // Category icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCategoryIcon(expense.category),
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.rawText ?? expense.category ?? context.l10n.unknown,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                DateFormat('MMM d').format(expense.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Text(
                          formatCurrency(expense.amount, currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              
              if (topFive.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                
                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top 5 expenses',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          formatCurrency(totalOfTopFive, currency),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          ' (${percentageOfTotal.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'groceries':
      case 'food':
        return Icons.shopping_cart;
      case 'transport':
      case 'transportation':
        return Icons.directions_car;
      case 'entertainment':
      case 'fun':
        return Icons.movie;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long;
      case 'health':
      case 'healthcare':
        return Icons.local_hospital;
      default:
        return Icons.attach_money;
    }
  }
}
