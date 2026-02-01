import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart'; // For homeFilterProvider

class BudgetDashboardPage extends ConsumerWidget {
  const BudgetDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The provider automatically updates when dependencies change
    final state = ref.watch(budgetDashboardProvider);
    final filterState = ref.watch(homeFilterProvider);
    final currency = filterState.selectedCurrency?.toUpperCase() ?? 'USD';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Or app background
      appBar: AppBar(
        title: const Text(
          'Budget Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: state.when(
        data: (data) {
          if (data.isLoading && data.allTransactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
                  // Hero Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DashboardHero(
                      transactions: data.allTransactions,
                      personalBudgets: data.allBudgets,
                      householdBudgets: data.householdBudgets,
                      preferredCurrency: currency,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Overview Stats
                  Builder(builder: (context) {
                    double expense = 0;
                    double income = 0;
                    // Filter transactions for currency and current month (simulated context)
                    // Currently only tracking expenses in this view
                    final now = DateTime.now();
                    for (final tx in data.allTransactions) {
                      // Note: User requested total regardless of currency.
                      // if ((tx.entry.currency ?? '').toUpperCase() != currency) continue;

                      if (tx.entry.date.year != now.year ||
                          tx.entry.date.month != now.month) continue;

                      if (tx.entry.type == 'income') {
                        income += tx.entry.amount;
                      } else {
                        expense += tx.entry.amount;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DashboardMetricCard(
                                  title: 'Total Spent',
                                  value: NumberFormat.simpleCurrency(
                                          name: currency)
                                      .format(expense),
                                  icon: Icons.arrow_upward_rounded,
                                  color: Colors.redAccent,
                                  infoText: 'Includes all currencies (raw sum)',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DashboardMetricCard(
                                  title: 'Total Income',
                                  value: NumberFormat.simpleCurrency(
                                          name: currency)
                                      .format(income),
                                  icon: Icons.arrow_downward_rounded,
                                  color: Colors.greenAccent,
                                  infoText: 'Includes all currencies',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DashboardTrendChart(
                            transactions: data.allTransactions,
                            currency: currency,
                          ),
                          const SizedBox(height: 16),
                          // Space Breakdown
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Row(
                              children: [
                                // Personal Space
                                Builder(builder: (_) {
                                  double pIncome = 0;
                                  double pExpense = 0;
                                  for (final tx in data.allTransactions) {
                                    // Note: User requested total regardless of currency.
                                    // if ((tx.entry.currency ?? '').toUpperCase() != currency) continue;

                                    if (tx.entry.date.year != now.year ||
                                        tx.entry.date.month != now.month)
                                      continue;
                                    if (tx.accountId != null &&
                                        tx.accountId!.isNotEmpty) continue;

                                    if (tx.entry.type == 'income') {
                                      pIncome += tx.entry.amount;
                                    } else {
                                      pExpense += tx.entry.amount;
                                    }
                                  }
                                  return DashboardSpaceCard(
                                    spaceName: 'Personal Space',
                                    income: pIncome,
                                    expense: pExpense,
                                    currency: currency,
                                  );
                                }),

                                // Households
                                ...data.households.map((h) {
                                  double hIncome = 0;
                                  double hExpense = 0;
                                  for (final tx in data.allTransactions) {
                                    // Note: User requested total regardless of currency.
                                    // if ((tx.entry.currency ?? '').toUpperCase() != currency) continue;

                                    if (tx.entry.date.year != now.year ||
                                        tx.entry.date.month != now.month)
                                      continue;
                                    if (tx.accountId != h.id) continue;

                                    if (tx.entry.type == 'income') {
                                      hIncome += tx.entry.amount;
                                    } else {
                                      hExpense += tx.entry.amount;
                                    }
                                  }
                                  return DashboardSpaceCard(
                                    spaceName: h.name,
                                    income: hIncome,
                                    expense: hExpense,
                                    currency: currency,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Accounts Section
                  DashboardAccountsSection(
                    transactions: data.allTransactions,
                    households: data.households,
                    currency: currency,
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
                    currency: currency,
                    onViewAll: () {
                      // Navigate to full list
                    },
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  DashboardCategoryList(
                    transactions: data.allTransactions,
                    currency: currency,
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
          debugPrint('Add Expense Clicked');
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
