import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';

class BudgetDashboardPage extends ConsumerWidget {
  const BudgetDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The provider automatically updates when dependencies change
    final state = ref.watch(budgetDashboardProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        title: const Text(
          'Overview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: state.when(
        data: (data) {
          if (data.isLoading && data.allTransactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final monthTransactions = data.allTransactions.where((tx) {
            return tx.entry.date.year == now.year &&
                tx.entry.date.month == now.month;
          }).toList(growable: false);

          final totalIncomeCents = monthTransactions.fold<int>(0, (sum, tx) {
            if (tx.entry.type == 'income') {
              return sum + tx.entry.amountCents;
            }
            return sum;
          });

          final totalExpenseCents = monthTransactions.fold<int>(0, (sum, tx) {
            if (tx.entry.type != 'income') {
              return sum + tx.entry.amountCents;
            }
            return sum;
          });

          final totalIncome = totalIncomeCents / 100.0;
          final totalExpense = totalExpenseCents / 100.0;
          final netFlow = totalIncome - totalExpense;
          final avgDaily = now.day > 0 ? totalExpense / now.day : 0.0;

          final activeSpaces = <String>{};
          final activeCurrencies = <String>{};
          for (final tx in monthTransactions) {
            activeSpaces.add(tx.accountId ?? 'personal');
            final currency = tx.entry.currency;
            if (currency != null && currency.trim().isNotEmpty) {
              activeCurrencies.add(currency.toUpperCase());
            }
          }

          final amountFormatter = NumberFormat.compact();
          final countFormatter = NumberFormat.compact();

          String formatSigned(double value) {
            final formatted = amountFormatter.format(value.abs());
            return value >= 0 ? '+$formatted' : '-$formatted';
          }

          return RefreshIndicator(
            // Since it's reactive, we primarily rely on upstream providers refreshing.
            // But we can trigger a refresh on them if needed.
            // For MVP, simple scroll logic. To refresh, we'd need to invalidate sources.
            onRefresh: () async {
              // ref.refresh(analyticsProvider);
              // ref.refresh(userHouseholdsProvider);
              return Future.value();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Month at a glance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${DateFormat.MMMM().format(now)} ${now.year}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _OverviewChip(
                              label: '${activeSpaces.length} spaces',
                            ),
                            _OverviewChip(
                              label: '${activeCurrencies.length} currencies',
                            ),
                            _OverviewChip(
                              label:
                                  '${countFormatter.format(monthTransactions.length)} transactions',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DashboardMetricCard(
                            title: 'Total Spent',
                            value: amountFormatter.format(totalExpense),
                            icon: Icons.arrow_upward_rounded,
                            color: colorScheme.error,
                            subtitle: 'All currencies combined',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardMetricCard(
                            title: 'Total Income',
                            value: amountFormatter.format(totalIncome),
                            icon: Icons.arrow_downward_rounded,
                            color: colorScheme.success,
                            subtitle: 'All currencies combined',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DashboardMetricCard(
                            title: 'Net Flow',
                            value: formatSigned(netFlow),
                            icon: Icons.account_balance_wallet_rounded,
                            color: netFlow >= 0
                                ? colorScheme.success
                                : colorScheme.error,
                            subtitle: 'Income minus spending',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardMetricCard(
                            title: 'Avg Daily Spend',
                            value: amountFormatter.format(avgDaily),
                            icon: Icons.calendar_today_rounded,
                            color: colorScheme.primary,
                            subtitle: '${now.day} days tracked',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DashboardTrendChart(
                      transactions: data.allTransactions,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Accounts Section
                  DashboardAccountsSection(
                    transactions: data.allTransactions,
                    households: data.households,
                  ),
                  const SizedBox(height: 24),

                  // Smart Insight
                  SmartInsightCard(
                    onTap: () {
                      // TODO: Open insights or details
                    },
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  DashboardTransactionsList(
                    transactions: data.allTransactions,
                    onViewAll: () {
                      // Navigate to full list
                    },
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  DashboardCategoryList(
                    transactions: data.allTransactions,
                  ),

                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Provide action to add expense
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final String label;

  const _OverviewChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.homeCardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
