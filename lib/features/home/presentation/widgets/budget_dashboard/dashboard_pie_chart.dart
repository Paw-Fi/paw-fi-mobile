import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_pie_chart.dart';

class DashboardPieChart extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String? currencyCode;
  final bool isLoading;

  const DashboardPieChart({
    super.key,
    required this.transactions,
    this.amountResolver,
    this.currencyCode,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;

    final spendTransactions = transactions
        .where((tx) => tx.entry.effectiveSpendingMultiplier != 0)
        .toList(growable: false);
    final expenses =
        spendTransactions.map((tx) => tx.entry).toList(growable: false);
    final spendingEffectsById = {
      for (final tx in spendTransactions)
        tx.entry.id: amountResolver?.call(tx) ?? tx.entry.spendingEffect,
    };

    if (expenses.isEmpty && !isLoading) {
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
      spendingEffectResolver: (expense) =>
          spendingEffectsById[expense.id] ?? expense.spendingEffect,
      isLoading: isLoading,
    );
  }
}
