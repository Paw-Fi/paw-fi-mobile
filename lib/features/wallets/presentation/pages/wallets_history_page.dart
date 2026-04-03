import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class WalletsHistoryPage extends HookConsumerWidget {
  const WalletsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Providers
    final accounts = ref.watch(effectiveScopeWalletsProvider);
    final analytics = ref.watch(analyticsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final householdScope = ref.watch(householdScopeProvider);

    final symbol = resolveCurrencySymbol(selectedCurrencyCode);

    // Helpers
    bool isInActiveScope(ExpenseEntry expense) {
      final householdId = expense.householdId;
      switch (householdScope.activeAccountType) {
        case ActiveWalletType.personal:
          return householdId == null || householdId.isEmpty;
        case ActiveWalletType.portfolio:
          final selected = householdScope.activeAccountHouseholdId;
          return selected != null && selected.isNotEmpty && householdId == selected;
        case ActiveWalletType.household:
          final selected = householdScope.selectedHouseholdId;
          return selected != null && selected.isNotEmpty && householdId == selected;
      }
    }

    String? resolveDefaultAccountId() {
      for (final account in accounts) {
        if (account.isDefault && !account.isArchived) return account.id;
      }
      return accounts.isNotEmpty ? accounts.first.id : null;
    }

    String? resolveTxAccountId(ExpenseEntry tx, String? defaultId) {
      final raw = tx.walletId?.trim();
      return (raw != null && raw.isNotEmpty) ? raw : defaultId;
    }

    // Prepare data
    final allTxs = analytics.allExpenses.where((e) {
      return isInActiveScope(e) && (e.currency?.trim().toUpperCase() == selectedCurrencyCode);
    }).toList();

    final standardTxs = allTxs.where((e) => !e.isRecurring).toList();

    // Sorting standard to have latest first
    standardTxs.sort((a, b) => b.date.compareTo(a.date));

    // Stats
    final now = DateTime.now();
    double thisMonthIncome = 0;
    double thisMonthExpense = 0;
    
    final accountBalances = <String, int>{
      for (final a in accounts) a.id: a.openingBalanceCents,
    };
    final defaultId = resolveDefaultAccountId();

    // Categories
    final categoryTotals = <String, double>{};

    for (final tx in standardTxs) {
      final isIncome = (tx.type ?? 'expense').toLowerCase() == 'income';
      final amt = tx.amount.abs();
      final amtCents = tx.amountCents.abs();

      // Current month isolated stats
      if (tx.date.year == now.year && tx.date.month == now.month) {
        if (isIncome) {
          thisMonthIncome += amt;
        } else {
          thisMonthExpense += amt;
          final catName = tx.category ?? 'Uncategorized';
          categoryTotals[catName] = (categoryTotals[catName] ?? 0) + amt;
        }
      }

      // Net Worth Calculation
      final accId = resolveTxAccountId(tx, defaultId);
      if (accId != null && accountBalances.containsKey(accId)) {
        final cur = accountBalances[accId] ?? 0;
        accountBalances[accId] = isIncome ? cur + amtCents : cur - amtCents;
      }
    }

    final netWorth = accountBalances.values.fold<int>(0, (s, v) => s + v) / 100.0;
    final netCashFlow = thisMonthIncome - thisMonthExpense;

    // Ordered categories
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // UI Block Components
    Widget buildKPIWidget(String title, double amount, {bool isPositiveGood = true, bool forceColor = false}) {
      final isPositive = amount >= 0;
      final color = forceColor 
          ? (isPositive == isPositiveGood ? colorScheme.primary : colorScheme.destructive)
          : colorScheme.foreground;
          
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildCardHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          title,
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(
        title: 'Historical Data',
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // KPI GRID
          Row(
            children: [
              buildKPIWidget('Total Net Worth', netWorth),
              const SizedBox(width: 12),
              buildKPIWidget('Net Cash Flow', netCashFlow, forceColor: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              buildKPIWidget('Monthly Income', thisMonthIncome),
              const SizedBox(width: 12),
              buildKPIWidget('Monthly Expenses', thisMonthExpense),
            ],
          ),
          const SizedBox(height: 24),

          // TOP SPENDING BY CATEGORIES (Current Month)
          if (sortedCategories.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildCardHeader('Top Categories (This Month)'),
                  ...sortedCategories.take(5).mapIndexed((index, entry) {
                    final fraction = entry.value / (sortedCategories.first.value == 0 ? 1 : sortedCategories.first.value);
                    final colorColors = [
                      Colors.blue,
                      Colors.purple,
                      Colors.orange,
                      Colors.pink,
                      Colors.teal,
                    ];
                    final barColor = colorColors[index % colorColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: TextStyle(color: colorScheme.foreground, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('$symbol${formatAmount(entry.value)}', style: TextStyle(color: colorScheme.mutedForeground, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              color: barColor,
                              minHeight: 6,
                            ),
                          )
                        ],
                      ),
                    );
                  })
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ACCOUNT BALANCES
          if (accounts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildCardHeader('Account Balances'),
                  ...accounts.map((acc) {
                    final currCents = accountBalances[acc.id] ?? acc.openingBalanceCents;
                    final currBal = currCents / 100.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(resolveWalletIcon(acc.icon), size: 16, color: colorScheme.foreground),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(acc.name, style: TextStyle(color: colorScheme.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '${currBal < 0 ? '-' : ''}$symbol${formatAmount(currBal.abs())}',
                            style: TextStyle(
                              color: currBal < 0 ? colorScheme.destructive : colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // RECENT TRANSACTIONS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCardHeader('Recent Transactions'),
                if (standardTxs.isEmpty)
                  Text('No recent transactions', style: TextStyle(color: colorScheme.mutedForeground))
                else
                  ...standardTxs.take(15).map((tx) {
                    final isInc = (tx.type ?? 'expense').toLowerCase() == 'income';
                    final dateStr = DateFormat('MMM d, yyyy').format(tx.date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx.category ?? 'Uncategorized', style: TextStyle(color: colorScheme.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(dateStr, style: TextStyle(color: colorScheme.mutedForeground, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            '${isInc ? '+' : '-'}$symbol${formatAmount(tx.amount.abs())}',
                            style: TextStyle(
                              color: isInc ? colorScheme.primary : colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
              ],
            ),
          ),
        ],
      ),
    );
  }
}
