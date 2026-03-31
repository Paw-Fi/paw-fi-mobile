import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_pie_chart.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

class DailyFinancialDetailsPage extends StatelessWidget {
  final DateTime date;
  final List<ExpenseEntry> transactions;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;

  const DailyFinancialDetailsPage({
    super.key,
    required this.date,
    required this.transactions,
    required this.recurringTransactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    // Filter transactions for this specific day
    final dailyTransactions = transactions.where((t) {
      return t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day &&
          !t.isRecurring &&
          (t.currency ?? '').trim().toUpperCase() == currency;
    }).toList();

    final projectedRecurringEntriesForDay =
        projectRecurringTransactionsAsExpenseEntries(
      recurringTransactions: recurringTransactions,
      rangeStart: date,
      rangeEnd: date,
      selectedCurrency: currency,
    );

    String? tryExtractRecurringId(String syntheticId) {
      final d = DateTime(date.year, date.month, date.day);
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final key = '$y$m$day';
      const prefix = 'recurring_';
      final suffix = '_$key';

      if (!syntheticId.startsWith(prefix)) return null;
      if (!syntheticId.endsWith(suffix)) return null;

      final endIndex = syntheticId.length - suffix.length;
      if (endIndex <= prefix.length) return null;
      return syntheticId.substring(prefix.length, endIndex);
    }

    final recurringIdsForDay = projectedRecurringEntriesForDay
        .map((e) => tryExtractRecurringId(e.id))
        .whereType<String>()
        .toSet();

    // Filter recurring transactions for this specific day
    final dailyRecurring = recurringTransactions
        .where((r) => recurringIdsForDay.contains(r.id))
        .toList();

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in dailyTransactions) {
      final amount = t.amountCents.abs() / 100.0;
      if ((t.type ?? 'expense').toLowerCase() == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    for (final e in projectedRecurringEntriesForDay) {
      final amount = e.amountCents.abs() / 100.0;
      if ((e.type ?? 'expense').toLowerCase() == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    final net = totalIncome - totalExpense;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: DateFormat.yMMMMd().format(date),
      ),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  top: getSubPageTopPadding(context),
                  left: 16,
                  right: 16,
                  bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  _SummaryCard(
                    income: totalIncome,
                    expense: totalExpense,
                    net: net,
                    currency: currency,
                  ),
                  const SizedBox(height: 24),

                  // Spending Breakdown Chart
                  if (dailyTransactions.any((t) =>
                      (t.type ?? 'expense').toLowerCase() != 'income')) ...[
                    _DailySpendingChart(
                      transactions: [
                        ...dailyTransactions,
                        ...projectedRecurringEntriesForDay,
                      ],
                      currency: currency,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Actual Transactions Section
                  if (dailyTransactions.isNotEmpty) ...[
                    Text(
                      l10n.transactions,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dailyTransactions.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 3),
                              child: TransactionListTile(
                                category: t.category ?? 'Uncategorized',
                                title: t.rawText ?? t.category ?? 'Transaction',
                                amount: t.amountCents.abs() / 100.0,
                                currency: t.currency ?? currency,
                                isIncome: (t.type ?? 'expense').toLowerCase() ==
                                    'income',
                                date: t.date,
                                onTap: () {
                                  showUnifiedTransactionSheet(
                                    context,
                                    existingExpense: t,
                                  );
                                },
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Recurring Transactions Section
                  if (dailyRecurring.isNotEmpty) ...[
                    Text(
                      l10n.recurring,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dailyRecurring.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RecurringTransactionTile(
                            transaction: r,
                            currency: currency,
                          ),
                        )),
                  ],

                  if (dailyTransactions.isEmpty && dailyRecurring.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          l10n.noTransactionsFound,
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

class _SummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final String currency;

  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.net,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: context.l10n.income,
                  amount: income,
                  currency: currency,
                  color: AppTheme.success,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _StatItem(
                  label: context.l10n.expenses,
                  amount: expense,
                  currency: currency,
                  color: AppTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.net,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              Text(
                _formatLocalizedCurrency(context, net, currency),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: net >= 0 ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _StatItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatLocalizedCurrency(context, amount, currency),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RecurringTransactionTile extends StatelessWidget {
  final RecurringTransaction transaction;
  final String currency;

  const _RecurringTransactionTile({
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';

    return Container(
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
          ),
        ),
      ),
    );
  }
}

class _DailySpendingChart extends StatelessWidget {
  final List<ExpenseEntry> transactions;
  final String currency;

  const _DailySpendingChart({
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter for expenses only
    final expenses = transactions.where((t) {
      final type = (t.type ?? 'expense').toLowerCase();
      return type != 'income';
    }).toList();

    if (expenses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spendingBreakdown.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          TransactionsPieChart(
            colorScheme: colorScheme,
            expenses: expenses,
            selectedCurrency: currency,
            periodLabel: context.l10n.today,
          ),
        ],
      ),
    );
  }
}
