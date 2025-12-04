import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/household_onboarding_page.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';

import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'household_budget_overview_card.dart';
import 'household_member_spending_card.dart';

import '../pages/household_expenses_page.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/widgets/group_fairness_meter.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';

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
          // NOTE: Selected household is initialized by app_initialization_provider
          // Just watch the state here - no need to re-initialize
          final selectedState = ref.watch(selectedHouseholdProvider);

          // Determine which household to show
          final household = selectedState.household ?? households.first;

          // Filters
          final filterState = ref.watch(homeFilterProvider);
          final selectedCurrency =
              (filterState.selectedCurrency ?? household.currency)
                  .toUpperCase();

          // Data providers with date filtering
          // Note: Individual widgets inside DraggableDashboardList will fetch their own data
          // based on their specific date range configuration.

          final repoAsync = ref.watch(dashboardRepositoryFutureProvider);

          return repoAsync.when(
            loading: () =>
                SliverToBoxAdapter(child: _buildLoadingState(colorScheme)),
            error: (e, st) => SliverToBoxAdapter(
              child: _buildErrorState(
                colorScheme,
                context.l10n.errorLoadingHouseholds,
                'Repository Error: $e',
              ),
            ),
            data: (_) {
              final dashboardAsync =
                  ref.watch(householdDashboardProvider(household.id));

              return dashboardAsync.when(
                loading: () =>
                    SliverToBoxAdapter(child: _buildLoadingState(colorScheme)),
                error: (e, st) => SliverToBoxAdapter(
                  child: _buildErrorState(
                    colorScheme,
                    context.l10n.errorLoadingHouseholds,
                    e.toString(),
                  ),
                ),
                data: (configs) {
                  return DraggableDashboardList(
                    configs: configs,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .reorder(oldIndex, newIndex);
                    },
                    onToggleVisibility: (id) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .toggleVisibility(id);
                    },
                    onUpdateConfig: (id, {dateRange, viewMode, start, end}) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .updateConfig(id,
                              dateRange: dateRange,
                              viewMode: viewMode,
                              start: start,
                              end: end);
                    },
                    widgetBuilders: {
                      DashboardWidgetType.householdSpentByYou:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));
                          final splitsAsync = ref.watch(householdSplitsProvider(
                            HouseholdSplitsParams(householdId: household.id),
                          ));

                          final transactions = expensesAsync.asData?.value;
                          final splits = splitsAsync.asData?.value;

                          if (transactions == null || splits == null) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          // Logic copied from original _personalShareExpenses / inline logic
                          int myTotalCents = 0;
                          final byGroupId = {for (final g in splits) g.id: g};

                          for (final t in transactions) {
                            final tdate =
                                DateTime(t.date.year, t.date.month, t.date.day);
                            final code =
                                (t.currency ?? '').trim().toUpperCase();
                            final currencyOk =
                                code.isEmpty || code == selectedCurrency;
                            final isSpend =
                                (t.type ?? 'expense').toLowerCase() != 'income';

                            if (!isSpend) continue;
                            if (!currencyOk) continue;
                            // Date filtering is already done by provider, but double check doesn't hurt
                            if (tdate.isBefore(from) || tdate.isAfter(to)) {
                              continue;
                            }

                            final splitGroupId = t.splitGroupId;

                            if (splitGroupId == null) {
                              if (t.userId == userId) {
                                myTotalCents += t.amountCents.abs();
                              }
                              continue;
                            }

                            final group = byGroupId[splitGroupId];
                            if (group == null || group.splitLines == null) {
                              if (t.userId == userId) {
                                myTotalCents += t.amountCents.abs();
                              }
                              continue;
                            }

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
                              final shareAmount =
                                  (userLine.amountCents ?? 0).abs();
                              myTotalCents += shareAmount;
                            }
                          }

                          final syntheticExpense = ExpenseEntry(
                            id: 'user-summary-total',
                            date: DateTime.now(),
                            amountCents: myTotalCents,
                            createdAt: DateTime.now(),
                            userId: userId,
                            currency: selectedCurrency,
                          );

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HouseholdExpensesPage(
                                        household: household),
                                  ),
                                );
                              },
                              child: buildSpendingCard(
                                context,
                                colorScheme,
                                [syntheticExpense],
                                null,
                                config.dateRange,
                                selectedCurrency: selectedCurrency,
                              ),
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdFinancialCalendar:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          // Calendar typically shows a month.
                          // We can use config.dateRange to filter transactions passed to it,
                          // but the widget itself might handle month navigation.
                          // For now, let's pass the transactions for the selected range.

                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));
                          final recurringAsync = ref.watch(
                              recurringTransactionsProvider(household.id));

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: FinancialCalendarWidget(
                              transactions: expensesAsync.asData?.value ?? [],
                              recurringTransactions:
                                  recurringAsync.data.asData?.value ?? [],
                              currency: selectedCurrency,
                              isExpanded: config.viewMode ==
                                  DashboardWidgetViewMode.full,
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdBudgetOverview:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final summaryAsync =
                              ref.watch(householdSummaryProvider(
                            HouseholdSummaryParams(
                              householdId: household.id,
                              currency: selectedCurrency,
                              startDate: from.toIso8601String(),
                              endDate: to.toIso8601String(),
                            ),
                          ));

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: summaryAsync.when(
                              loading: () => const SizedBox(
                                  height: 200,
                                  child: Center(
                                      child: CircularProgressIndicator())),
                              error: (e, st) => SizedBox(
                                  height: 200,
                                  child: Center(
                                      child: Text('Error',
                                          style: TextStyle(
                                              color:
                                                  colorScheme.destructive)))),
                              data: (summary) {
                                // We need to reconstruct summary if we want to filter expenses manually?
                                // But summary is already fetched with date range!
                                // However, the original code did manual filtering on `expensesAsync` too.
                                // Let's trust `householdSummaryProvider` returns correct data for the range.
                                return buildHouseholdBudgetOverviewCard(
                                  context,
                                  colorScheme,
                                  summary,
                                );
                              },
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdFairness: (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final summaryAsync =
                              ref.watch(householdSummaryProvider(
                            HouseholdSummaryParams(
                              householdId: household.id,
                              currency: selectedCurrency,
                              startDate: from.toIso8601String(),
                              endDate: to.toIso8601String(),
                            ),
                          ));
                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));

                          if (summaryAsync.value == null) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GroupFairnessMeter(
                              summary: summaryAsync.value!,
                              transactions: expensesAsync.value,
                              from: from,
                              to: to,
                              currency: selectedCurrency,
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdSettlement:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final summaryAsync =
                              ref.watch(householdSummaryProvider(
                            HouseholdSummaryParams(
                              householdId: household.id,
                              currency: selectedCurrency,
                              startDate: from.toIso8601String(),
                              endDate: to.toIso8601String(),
                            ),
                          ));
                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));
                          final splitsAsync = ref.watch(householdSplitsProvider(
                            HouseholdSplitsParams(householdId: household.id),
                          ));
                          final membersAsync =
                              ref.watch(householdMembersProvider(household.id));

                          if (summaryAsync.value == null) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SettlementSuggestionsCard(
                              summary: summaryAsync.value!,
                              transactions: expensesAsync.value,
                              splits: splitsAsync.value,
                              currency: selectedCurrency,
                              members: membersAsync.value,
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdMemberSpending:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final summaryAsync =
                              ref.watch(householdSummaryProvider(
                            HouseholdSummaryParams(
                              householdId: household.id,
                              currency: selectedCurrency,
                              startDate: from.toIso8601String(),
                              endDate: to.toIso8601String(),
                            ),
                          ));
                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));
                          final splitsAsync = ref.watch(householdSplitsProvider(
                            HouseholdSplitsParams(householdId: household.id),
                          ));
                          final membersAsync =
                              ref.watch(householdMembersProvider(household.id));

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: summaryAsync.when(
                              loading: () => const SizedBox(
                                  height: 200,
                                  child: Center(
                                      child: CircularProgressIndicator())),
                              error: (e, st) => const SizedBox.shrink(),
                              data: (summary) =>
                                  buildHouseholdMemberSpendingCard(
                                context,
                                colorScheme,
                                summary,
                                members: membersAsync.value,
                                householdId: household.id,
                                transactions: expensesAsync.value,
                                splits: splitsAsync.value,
                                from: from,
                                to: to,
                                selectedCurrency: selectedCurrency,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => HouseholdExpensesPage(
                                          household: household),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdRecentTransactions:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));

                          final allExpenses = expensesAsync.value ?? [];
                          // Filter by date AND currency
                          final filteredExpenses = allExpenses.where((e) {
                            final d =
                                DateTime(e.date.year, e.date.month, e.date.day);
                            final dateOk = !d.isBefore(from) && !d.isAfter(to);
                            final code = (e.currency ?? '').trim().toUpperCase();
                            final currencyOk = code.isEmpty || code == selectedCurrency;
                            return dateOk && currencyOk;
                          }).toList();

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GestureDetector(
                              // Removed onLongPress as date range is now handled by wrapper
                              child: buildRecentTransactionsCard(
                                context,
                                colorScheme,
                                filteredExpenses,
                                null,
                                selectedCurrency: selectedCurrency,
                                householdId: household.id,
                                onViewAll: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => HouseholdExpensesPage(
                                          household: household),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdSpendingBreakdownChart:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));

                          final allExpenses = expensesAsync.value ?? [];
                          // Filter by date AND currency
                          final filteredExpenses = allExpenses.where((e) {
                            final d =
                                DateTime(e.date.year, e.date.month, e.date.day);
                            final dateOk = !d.isBefore(from) && !d.isAfter(to);
                            final code = (e.currency ?? '').trim().toUpperCase();
                            final currencyOk = code.isEmpty || code == selectedCurrency;
                            return dateOk && currencyOk;
                          }).toList();

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HouseholdExpensesPage(
                                        household: household),
                                  ),
                                );
                              },
                              // Removed onLongPress
                              child: buildSpendingBreakdownChart(
                                context,
                                colorScheme,
                                filteredExpenses,
                                const <DailyBudgetEntry>[],
                                null,
                                config.dateRange,
                                selectedCurrency: selectedCurrency,
                              ),
                            ),
                          );
                        });
                      },
                      DashboardWidgetType.householdWhereTheMoneyWent:
                          (context, config) {
                        return Consumer(builder: (context, ref, _) {
                          final range = getDateRangeFromFilter(config.dateRange,
                              config.customStartDate, config.customEndDate);
                          final from = range['from']!;
                          final to = range['to']!;

                          final expensesAsync =
                              ref.watch(householdExpensesProvider(
                            HouseholdExpensesParams(
                              householdId: household.id,
                            ),
                          ));

                          final allExpenses = expensesAsync.value ?? [];
                          // Filter by date AND currency
                          final filteredExpenses = allExpenses.where((e) {
                            final d =
                                DateTime(e.date.year, e.date.month, e.date.day);
                            final dateOk = !d.isBefore(from) && !d.isAfter(to);
                            final code = (e.currency ?? '').trim().toUpperCase();
                            final currencyOk = code.isEmpty || code == selectedCurrency;
                            return dateOk && currencyOk;
                          }).toList();

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: WhereTheMoneyWentWidget(
                              expenses: filteredExpenses,
                              currency: selectedCurrency,
                              onHelpTap: () =>
                                  showCategoryGuide(context, colorScheme),
                            ),
                          );
                        });
                      },
                    },
                  );
                },
              );
            },
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
