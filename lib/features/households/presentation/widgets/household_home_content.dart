import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/household_onboarding_page.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/widgets/date_range_filter_modal.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'household_budget_overview_card.dart';
import 'household_member_spending_card.dart';
import '../pages/create_budget_page.dart';
import '../pages/budget_detail_page.dart';
import '../pages/household_expenses_page.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/households/presentation/widgets/group_fairness_meter.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';

/// Household home content that handles loading, empty, and data states
/// Returns Sliver widgets for use in CustomScrollView
class HouseholdHomeContent extends ConsumerStatefulWidget {
  const HouseholdHomeContent({super.key});

  @override
  ConsumerState<HouseholdHomeContent> createState() =>
      _HouseholdHomeContentState();
}

class _HouseholdHomeContentState extends ConsumerState<HouseholdHomeContent> {
  /// Calculate user's personal share of household expenses
  ///
  /// This method is ONLY used for the "Spent by You" card to show what the current user
  /// personally owes/spent in the household, including split portions from other members.
  ///
  /// ⚠️ IMPORTANT: This is NOT used for category breakdown or pie charts.
  /// Those should show ALL household expenses, not just personal share.
  ///
  /// Calculation logic:
  /// 1. If expense has NO split group (splitGroupId == null):
  ///    - Include full amount if current user created it
  ///    - Example: User logs $10 with no split → User's share = $10
  ///
  /// 2. If expense HAS split group (splitGroupId != null):
  ///    - Look up the split group to find user's allocated share
  ///    - Use the amountCents from the user's split line
  ///    - Example: Other logs $100, splits $50 to user → User's share = $50
  ///
  /// Example calculation:
  /// - User logs $10 expense, splits $0 to others → Returns $10
  /// - Other logs $100 expense, splits $50 to user → Returns $50
  /// - Total "Spent by You" = $60
  /// - Total household = $110 (calculated separately)
  // ignore: unused_element
  List<ExpenseEntry> _personalShareExpenses(
    List<ExpenseEntry> expenses,
    List<ExpenseSplitGroup> splits,
    String currentUserId,
  ) {
    if (expenses.isEmpty) return const <ExpenseEntry>[];

    // If no splits data, return all expenses created by current user with full amounts
    // This handles the case where split data hasn't loaded yet
    if (splits.isEmpty) {
      return expenses.where((e) => e.userId == currentUserId).toList();
    }

    // Create lookup map for quick access to split groups by ID
    final byGroupId = {for (final g in splits) g.id: g};
    final result = <ExpenseEntry>[];

    for (final e in expenses) {
      final gid = e.splitGroupId;

      // CASE 1: Expense has NO split group (not shared)
      // Include full amount if current user created it
      if (gid == null) {
        if (e.userId == currentUserId) {
          result.add(e);
        }
        continue;
      }

      // CASE 2: Expense HAS split group (shared expense)
      // Find the split group and extract user's allocated share
      final group = byGroupId[gid];
      if (group == null) {
        // Split group not found in data, fallback to including full amount if user created it
        if (e.userId == currentUserId) {
          result.add(e);
        }
        continue;
      }

      // Find current user's split line within the group
      final line = (group.splitLines ?? const <ExpenseSplitLine>[])
          .firstWhere((l) => l.userId == currentUserId,
              orElse: () => ExpenseSplitLine(
                    id: '',
                    splitGroupId: '',
                    userId: '',
                    isSettled: false,
                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ));

      // User not part of this split, skip this expense
      if (line.userId != currentUserId) continue;

      // Extract user's share amount from split line (in cents)
      final int share = (line.amountCents ?? 0);
      final int shareClamped = share < 0 ? 0 : share; // Clamp negatives to zero

      // Create new expense entry with user's share amount
      result.add(e.copyWith(amountCents: shareClamped));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final colorScheme = Theme.of(context).colorScheme;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.userNotLoggedIn,
          context.l10n.pleaseSignInToAccessHouseholdFeatures,
        ),
      );
    }

    final householdsAsync = ref.watch(userHouseholdsProvider(userId));

    return householdsAsync.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildLoadingState(colorScheme),
      ),
      error: (error, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.errorLoadingHouseholds,
          error.toString(),
        ),
      ),
      data: (households) {
        if (households.isEmpty) {
          // Show onboarding when user has no households
          // Use SliverToBoxAdapter with LayoutBuilder to provide proper sizing
          return SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height -
                      200, // Account for app bar
                  child: const HouseholdOnboardingPage(),
                );
              },
            ),
          );
        } else {
          // Initialize selected household if not set
          final selectedState = ref.watch(selectedHouseholdProvider);

          if (selectedState.householdId == null && !selectedState.isLoading) {
            // Auto-initialize on first load
            Future.microtask(() {
              ref.read(selectedHouseholdProvider.notifier).initialize(userId);
            });
          }

          // Determine which household to show
          final household = selectedState.household ?? households.first;

          // Load income summary for household
          Future.microtask(() {
            ref.read(incomeSummaryProvider.notifier).loadSummary(
                  userId,
                  householdId: household.id,
                );
          });

          // Filters
          final filterState = ref.watch(homeFilterProvider);
          final dateRange = getDateRangeFromFilter(
            filterState.dateRangeFilter,
            filterState.customStartDate,
            filterState.customEndDate,
          );
          final from = dateRange['from']!;
          final to = dateRange['to']!;
          final selectedCurrency =
              (filterState.selectedCurrency ?? household.currency)
                  .toUpperCase();

          // Data providers with date filtering
          final expensesAsync = ref.watch(
            householdExpensesProvider(
              HouseholdExpensesParams(
                householdId: household.id,
                limit: 10000, // Safety limit (10K max)
                startDate: from,
                endDate: to,
              ),
            ),
          );
          // Load splits data (needed for split-aware calculations)
          final splitsAsync = ref.watch(
            householdSplitsProvider(
              HouseholdSplitsParams(householdId: household.id),
            ),
          );
          final budgetsAsync =
              ref.watch(householdBudgetsProvider(household.id));
          final summaryAsync = ref.watch(
            householdSummaryProvider(
              HouseholdSummaryParams(
                householdId: household.id,
                currency: selectedCurrency,
                startDate: from.toIso8601String(),
                endDate: to.toIso8601String(),
              ),
            ),
          );
          final membersAsync =
              ref.watch(householdMembersProvider(household.id));
          final recurringAsync =
              ref.watch(recurringTransactionsProvider(household.id));

          // Per-card date filters for household cards
          final householdCategoryFilterState = ref.watch(
            cardDateFilterProvider(HomeCardFilterId.householdCategoryBreakdown),
          );
          final householdSpendingBreakdownFilterState = ref.watch(
            cardDateFilterProvider(HomeCardFilterId.householdSpendingBreakdown),
          );

          // UI
          return SliverList(
            delegate: SliverChildListDelegate([
              // ═══════════════════════════════════════════════════════════════
              // "SPENT BY YOU" CARD
              // ═══════════════════════════════════════════════════════════════
              // Shows the current user's personal spending in the household.
              // This includes:
              //   1. Full amount of expenses created by user
              //   2. Split portions allocated to user from other members' expenses
              //
              // Data source: Real-time calculation from transactions + splits
              // Same as member spending card to ensure consistency
              //
              // Example:
              //   - User logs $10 expense, splits $0 to others
              //   - Other logs $100 expense, splits $50 to user
              //   - Result: "Spent by You" = $60 (user's $10 + split $50)
              // ═══════════════════════════════════════════════════════════════
              Builder(
                builder: (context) {
                  final transactions = expensesAsync.asData?.value;
                  final splits = splitsAsync.asData?.value;

                  if (transactions == null || splits == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Calculate user's personal share from transactions + splits (real-time)
                  // This ensures immediate updates when expenses are added/edited/deleted
                  int myTotalCents = 0;

                  // Create lookup map for split groups
                  final byGroupId = {for (final g in splits) g.id: g};

                  for (final t in transactions) {
                    final tdate =
                        DateTime(t.date.year, t.date.month, t.date.day);
                    final code = (t.currency ?? '').trim().toUpperCase();
                    final currencyOk = code.isEmpty || code == selectedCurrency;
                    final isSpend =
                        (t.type ?? 'expense').toLowerCase() != 'income';

                    if (!isSpend) continue;
                    if (!currencyOk) continue;
                    if (tdate.isBefore(from) || tdate.isAfter(to)) continue;

                    final splitGroupId = t.splitGroupId;

                    // CASE 1: No split - attribute full amount if user created it
                    if (splitGroupId == null) {
                      if (t.userId == userId) {
                        myTotalCents += t.amountCents.abs();
                      }
                      continue;
                    }

                    // CASE 2: Has split - add user's allocated portion
                    final group = byGroupId[splitGroupId];
                    if (group == null || group.splitLines == null) {
                      // Split group not found, fallback to full amount if user created it
                      if (t.userId == userId) {
                        myTotalCents += t.amountCents.abs();
                      }
                      continue;
                    }

                    // Find user's split line and add their share
                    final userLine = group.splitLines!.firstWhere(
                      (line) => line.userId == userId,
                      orElse: () => ExpenseSplitLine(
                        id: '',
                        splitGroupId: '',
                        userId: '',
                        isSettled: false,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );

                    if (userLine.userId == userId) {
                      final shareAmount = (userLine.amountCents ?? 0).abs();
                      myTotalCents += shareAmount;
                    }
                  }

                  // Create a synthetic expense entry for display purposes
                  final syntheticExpense = ExpenseEntry(
                    id: 'user-summary-total',
                    date: DateTime.now(),
                    amountCents: myTotalCents,
                    createdAt: DateTime.now(),
                    userId: userId,
                    currency: selectedCurrency,
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HouseholdExpensesPage(household: household),
                          ),
                        );
                      },
                      child: buildSpendingCard(
                        context,
                        colorScheme,
                        [
                          syntheticExpense
                        ], // Single entry with real-time calculated total
                        null,
                        filterState.dateRangeFilter,
                        selectedCurrency: selectedCurrency,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════════════════
              // FINANCIAL CALENDAR WIDGET
              // ═══════════════════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: FinancialCalendarWidget(
                  transactions: expensesAsync.asData?.value ?? [],
                  recurringTransactions:
                      recurringAsync.data.asData?.value ?? [],
                  currency: selectedCurrency,
                ),
              ),

              const SizedBox(height: 16),

              // Income Card (development in progress)
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
              //   child: IncomeCard(householdId: household.id),
              // ),

              // const SizedBox(height: 16),

              // Budget Overview Card: Total Spent + Budget Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: summaryAsync.when(
                  loading: () => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Error loading summary',
                        style: TextStyle(color: colorScheme.destructive),
                      ),
                    ),
                  ),
                  data: (summary) {
                    // hasBudget in summary is currency-filtered; but for navigation
                    // we should consider any existing budget regardless of filter.
                    final allBudgets = budgetsAsync.asData?.value ?? const [];
                    final hasAnyBudget = allBudgets.isNotEmpty;

                    // Ensure "Spent by household" excludes income and respects date/currency
                    final allExpenses =
                        expensesAsync.asData?.value ?? const <ExpenseEntry>[];
                    int spentCents = 0;
                    int incomeCents = 0;
                    int txCount = 0;
                    for (final e in allExpenses) {
                      final d = DateTime(e.date.year, e.date.month, e.date.day);
                      final inRange = !d.isBefore(from) && !d.isAfter(to);
                      final code = (e.currency ?? '').trim().toUpperCase();
                      final currencyOk =
                          code.isEmpty || code == selectedCurrency;
                      if (!inRange || !currencyOk) continue;
                      final t = (e.type ?? 'expense').toLowerCase();
                      if (t == 'income') {
                        incomeCents += e.amountCents.abs();
                      } else {
                        spentCents += e.amountCents.abs();
                        txCount += 1;
                      }
                    }

                    final fixedSummary = summary == null
                        ? null
                        : HouseholdSummary(
                            householdId: summary.householdId,
                            currency: summary.currency,
                            period: summary.period,
                            totals: Totals(
                              totalExpensesCents: spentCents,
                              totalIncomeCents: incomeCents,
                              netCents: incomeCents - spentCents,
                              transactionCount: txCount,
                              splitCount: summary.totals.splitCount,
                            ),
                            memberContributions: summary.memberContributions,
                            categoryBreakdown: summary.categoryBreakdown,
                            budgets: summary.budgets,
                            balances: summary.balances,
                          );

                    return buildHouseholdBudgetOverviewCard(
                      context,
                      colorScheme,
                      fixedSummary,
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Group fairness & settlement suggestions
              if (summaryAsync.asData?.value != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GroupFairnessMeter(
                    summary: summaryAsync.asData!.value!,
                    transactions: expensesAsync.asData?.value,
                    from: from,
                    to: to,
                    currency: selectedCurrency,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SettlementSuggestionsCard(
                    summary: summaryAsync.asData!.value!,
                    transactions: expensesAsync.asData?.value,
                    splits: splitsAsync.asData?.value,
                    from: from,
                    to: to,
                    currency: selectedCurrency,
                    members: membersAsync.asData?.value,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Member Spending Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: summaryAsync.when(
                  loading: () => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        context.l10n.errorLoadingMembers,
                        style: TextStyle(color: colorScheme.destructive),
                      ),
                    ),
                  ),
                  data: (summary) => buildHouseholdMemberSpendingCard(
                    context,
                    colorScheme,
                    summary,
                    members: membersAsync.asData?.value,
                    householdId: household.id,
                    transactions: expensesAsync.asData?.value,
                    splits: splitsAsync.asData?.value,
                    from: from,
                    to: to,
                    selectedCurrency: selectedCurrency,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HouseholdExpensesPage(household: household),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // TEMP REMOVE:Net Position Card (horizontal scrollable card - keep for additional info)
              // SizedBox(
              //   height: 180,
              //   child: ListView(
              //     scrollDirection: Axis.horizontal,
              //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
              //     children: [
              //       SizedBox(
              //         width: 240,
              //         child: summaryAsync.when(
              //           loading: () => Container(
              //             decoration: BoxDecoration(
              //               color: colorScheme.card,
              //               borderRadius: BorderRadius.circular(20),
              //               border: Border.all(
              //                 color: colorScheme.border.withValues(alpha: 0.5),
              //                 width: 1,
              //               ),
              //             ),
              //             padding: const EdgeInsets.all(20),
              //             child: const Center(child: CircularProgressIndicator()),
              //           ),
              //           error: (e, st) {
              //             final zeroSummary = HouseholdSummary(
              //               householdId: household.id,
              //               currency: selectedCurrency,
              //               period: DatePeriod(
              //                 startDate: from.toIso8601String(),
              //                 endDate: to.toIso8601String(),
              //               ),
              //               totals: Totals(
              //                 totalExpensesCents: 0,
              //                 totalIncomeCents: 0,
              //                 netCents: 0,
              //                 transactionCount: 0,
              //                 splitCount: 0,
              //               ),
              //               memberContributions: const [],
              //               categoryBreakdown: const [],
              //               budgets: const [],
              //               balances: const {},
              //             );
              //             return buildHouseholdNetPositionCard(
              //               context,
              //               colorScheme,
              //               zeroSummary,
              //               onTap: () {
              //                 Navigator.of(context).push(
              //                   MaterialPageRoute(
              //                     builder: (_) => HouseholdExpensesPage(household: household),
              //                   ),
              //                 );
              //               },
              //             );
              //           },
              //           data: (summary) => buildHouseholdNetPositionCard(
              //             context,
              //             colorScheme,
              //             summary,
              //             onTap: () {
              //               Navigator.of(context).push(
              //                 MaterialPageRoute(
              //                   builder: (_) => HouseholdExpensesPage(household: household),
              //                 ),
              //               );
              //             },
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════════════════
              // CATEGORY BREAKDOWN CARD
              // ═══════════════════════════════════════════════════════════════
              // Shows spending breakdown by category for ALL household expenses.
              //
              // ⚠️ CRITICAL: Uses filteredExpenses (ALL household expenses),
              // NOT personal share. This shows where the household money went,
              // regardless of who paid or how it was split.
              //
              // Example:
              //   - User logs $10 for "Food"
              //   - Other logs $100 for "Transport"
              //   - Category breakdown shows:
              //     • Food: $10
              //     • Transport: $100
              //   - Total displayed: $110 (entire household spending)
              // ═══════════════════════════════════════════════════════════════
              expensesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (allExpenses) {
                  // Pass ALL household expenses; widget applies its own
                  // per-card date and currency filtering, scoped to this
                  // household.
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onLongPress: () => showCardDateRangeFilter(
                        context,
                        colorScheme,
                        HomeCardFilterId.householdCategoryBreakdown,
                      ),
                      child: buildCategoryBreakdownCard(
                        context,
                        colorScheme,
                        allExpenses,
                        null,
                        selectedCurrency: selectedCurrency,
                        householdId: household.id,
                        onViewAll: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  HouseholdExpensesPage(household: household),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════════════════
              // PIE CHART CARD (Spending Breakdown)
              // ═══════════════════════════════════════════════════════════════
              // Shows visual distribution of ALL household expenses by category.
              //
              // ⚠️ CRITICAL: Uses filteredExpenses (ALL household expenses),
              // NOT personal share. This provides a complete picture of household
              // spending patterns across all categories.
              //
              // Example:
              //   - User logs $10 for "Food" (9% of total)
              //   - Other logs $100 for "Transport" (91% of total)
              //   - Pie chart shows both slices representing full household
              // ═══════════════════════════════════════════════════════════════
              expensesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (allExpenses) {
                  // Pass ALL household expenses; chart applies its own
                  // per-card date and currency filtering, scoped to this
                  // household.
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HouseholdExpensesPage(household: household),
                          ),
                        );
                      },
                      onLongPress: () => showCardDateRangeFilter(
                        context,
                        colorScheme,
                        HomeCardFilterId.householdSpendingBreakdown,
                      ),
                      child: buildSpendingBreakdownChart(
                        context,
                        colorScheme,
                        allExpenses,
                        const <DailyBudgetEntry>[],
                        null,
                        householdSpendingBreakdownFilterState.dateRangeFilter,
                        selectedCurrency: selectedCurrency,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ]),
          );
        }
      },
    );
  }

  /// Full-page loading state with skeleton
  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.appBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.loadingHousehold,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state with retry option
  Widget _buildErrorState(
    ColorScheme colorScheme,
    String title,
    String message,
  ) {
    return Container(
      color: colorScheme.appBackground,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: colorScheme.destructive,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
