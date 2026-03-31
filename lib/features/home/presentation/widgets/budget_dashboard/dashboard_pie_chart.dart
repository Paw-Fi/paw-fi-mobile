import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_pie_chart.dart';

class DashboardPieChart extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String? currencyCode;

  const DashboardPieChart({
    super.key,
    required this.transactions,
    this.amountResolver,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency = currencyCode?.trim().isNotEmpty == true
        ? currencyCode!.trim()
        : null;

    // Filter expenses (no income) and convert to ExpenseEntry
    final expenses = transactions
        .where((tx) => (tx.entry.type ?? 'expense').toLowerCase() != 'income')
        .map((tx) => tx.entry)
        .toList();

    if (expenses.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            context.l10n.noExpensesDisplay,
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ),
      );
    }

    return TransactionsPieChart(
      colorScheme: colorScheme,
      expenses: expenses,
      selectedCurrency: displayCurrency ?? 'USD',
      periodLabel: context.l10n.spendingBreakdown,
    );
  }
}
