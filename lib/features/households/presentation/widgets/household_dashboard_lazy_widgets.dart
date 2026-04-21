import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/utils/dashboard_synthetic_entries.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';
import 'package:moneko/features/home/presentation/widgets/spending_breakdown_chart.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/group_fairness_meter.dart';
import 'package:moneko/features/households/presentation/widgets/household_budget_overview_card.dart';
import 'package:moneko/features/households/presentation/widgets/household_member_spending_card.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/features/households/presentation/utils/member_spending_attribution.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:skeletonizer/skeletonizer.dart';

HouseholdSummaryParams buildHouseholdSummaryParams({
  required Household household,
  required String selectedCurrency,
  required DashboardWidgetConfig config,
  DateTime? referenceNow,
}) {
  final range = getDateRangeFromFilter(
    config.dateRange,
    config.customStartDate,
    config.customEndDate,
    now: referenceNow,
  );
  return HouseholdSummaryParams(
    householdId: household.id,
    currency: selectedCurrency,
    startDate: range['from']!.toIso8601String(),
    endDate: range['to']!.toIso8601String(),
  );
}

class LazyHouseholdSpentByYouCard extends ConsumerWidget {
  const LazyHouseholdSpentByYouCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (!recurringState.hasLoadedOnce && !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }

    if ((transactionsAsync.isLoading && !transactionsAsync.hasValue) ||
        (splitsAsync.isLoading && !splitsAsync.hasValue)) {
      return _buildSpentByYouSkeleton(
        context,
        selectedCurrency,
        config.dateRange,
        referenceNow,
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }
    if (splitsAsync.hasError && !splitsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
      );
    }

    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );
    final totals = computeSplitAwareMemberSpendingTotals(
      transactions: mergedTransactions,
      from: range['from']!,
      to: range['to']!,
      splits: splitsAsync.valueOrNull ?? const [],
      selectedCurrency: selectedCurrency,
    );
    final spentByUser = totals.totalForUser(userId);

    final syntheticExpense = buildSyntheticSpentByUserExpense(
      userId: userId,
      totalSpentCents: spentByUser,
      anchorDate: range['to']!,
      currency: selectedCurrency,
      householdId: household.id,
    );

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionsPage(
              householdId: household.id,
              enableDateFilter: true,
              initialStartDate: range['from'],
              initialEndDate: range['to'],
            ),
          ),
        );
      },
      child: buildSpendingCard(
        context,
        Theme.of(context).colorScheme,
        [syntheticExpense],
        null,
        config.dateRange,
        referenceNow: referenceNow,
        selectedCurrency: selectedCurrency,
      ),
    );
  }
}

class LazyHouseholdFinancialCalendarCard extends ConsumerWidget {
  const LazyHouseholdFinancialCalendarCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final recurringAsync =
        ref.watch(recurringTransactionsProvider(household.id));

    return FinancialCalendarWidget(
      userId: userId,
      householdId: household.id,
      recurringTransactions: recurringAsync.data.valueOrNull ?? const [],
      currency: selectedCurrency,
      isExpanded: config.viewMode == DashboardWidgetViewMode.full,
    );
  }
}

class LazyHouseholdMemberSpendingCard extends ConsumerWidget {
  const LazyHouseholdMemberSpendingCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(householdMembersProvider(household.id));
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final query = DashboardScopeQuery(
      userId: userId ?? '',
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId != null &&
        userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
    );
    final summaryAsync = ref.watch(householdDerivedSummaryProvider(params));
    final summary = summaryAsync.valueOrNull;

    if (summary == null && summaryAsync.hasError) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }
    if (splitsAsync.hasError && !splitsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
      );
    }
    if (summary == null) {
      return summaryAsync.isLoading
          ? Skeletonizer(
              effect: ShimmerEffect(
                baseColor: Theme.of(context).colorScheme.skeletonBase,
                highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
              ),
              child: buildHouseholdMemberSpendingCard(
                context,
                Theme.of(context).colorScheme,
                null,
                members: const [],
                householdId: household.id,
                selectedCurrency: selectedCurrency,
                dateRangeFilter: config.dateRange,
                currentUserId: userId,
              ),
            )
          : const SizedBox.shrink();
    }

    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );

    return buildHouseholdMemberSpendingCard(
      context,
      Theme.of(context).colorScheme,
      summary,
      members: membersAsync.valueOrNull,
      householdId: household.id,
      transactions: mergedTransactions,
      splits: splitsAsync.valueOrNull,
      from: range['from'],
      to: range['to'],
      selectedCurrency: selectedCurrency,
      dateRangeFilter: config.dateRange,
      currentUserId: userId,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionsPage(
              householdId: household.id,
              enableDateFilter: true,
              initialStartDate: range['from'],
              initialEndDate: range['to'],
            ),
          ),
        );
      },
    );
  }
}

class LazyHouseholdRecentTransactionsCard extends ConsumerWidget {
  const LazyHouseholdRecentTransactionsCard({
    super.key,
    required this.household,
    required this.selectedCurrency,
  });

  final Household household;
  final String selectedCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: null,
      endDate: null,
    );
    final recentAsync = ref.watch(
      dashboardRecentTransactionsProvider(
        DashboardRecentTransactionsRequest(query: query, limit: 5),
      ),
    );

    if (recentAsync.isLoading && !recentAsync.hasValue) {
      return _buildRecentTransactionsSkeleton(
          context, selectedCurrency, household.id, userId);
    }
    if (recentAsync.hasError && !recentAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(
          dashboardRecentTransactionsProvider(
            DashboardRecentTransactionsRequest(query: query, limit: 5),
          ),
        ),
      );
    }

    return buildRecentTransactionsCard(
      context,
      Theme.of(context).colorScheme,
      recentAsync.valueOrNull ?? const <ExpenseEntry>[],
      null,
      selectedCurrency: selectedCurrency,
      householdId: household.id,
      onViewAll: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionsPage(
              householdId: household.id,
            ),
          ),
        );
      },
    );
  }
}

class LazyHouseholdSpendingBreakdownChartCard extends ConsumerWidget {
  const LazyHouseholdSpendingBreakdownChartCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }

    if (transactionsAsync.isLoading && !transactionsAsync.hasValue) {
      return _buildBreakdownSkeleton(context);
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }

    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );

    return buildSpendingBreakdownChart(
      context,
      Theme.of(context).colorScheme,
      expenses,
      const [],
      null,
      config.dateRange,
      referenceNow: referenceNow,
      selectedCurrency: selectedCurrency,
      customStartDate: config.customStartDate,
      customEndDate: config.customEndDate,
    );
  }
}

class LazyHouseholdWhereTheMoneyWentCard extends ConsumerWidget {
  const LazyHouseholdWhereTheMoneyWentCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }

    if (transactionsAsync.isLoading && !transactionsAsync.hasValue) {
      return _buildWhereMoneyWentSkeleton(context);
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }

    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );

    return WhereTheMoneyWentWidget(
      expenses: expenses,
      currency: selectedCurrency,
      onHelpTap: () =>
          showCategoryGuide(context, Theme.of(context).colorScheme),
      dateRange: config.dateRange,
    );
  }
}

Widget _buildSpentByYouSkeleton(
  BuildContext context,
  String currency,
  dateFilter,
  DateTime referenceNow,
) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: Theme.of(context).colorScheme.skeletonBase,
      highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
    ),
    child: buildSpendingCard(
      context,
      Theme.of(context).colorScheme,
      [
        ExpenseEntry(
          id: 'spent-skeleton',
          date: DateTime.now(),
          amountCents: 0,
          createdAt: DateTime.now(),
          userId: 'skeleton',
          currency: currency,
        ),
      ],
      null,
      dateFilter,
      referenceNow: referenceNow,
      selectedCurrency: currency,
    ),
  );
}

Widget _buildRecentTransactionsSkeleton(
  BuildContext context,
  String selectedCurrency,
  String householdId,
  String userId,
) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: Theme.of(context).colorScheme.skeletonBase,
      highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
    ),
    child: buildRecentTransactionsCard(
      context,
      Theme.of(context).colorScheme,
      [
        ExpenseEntry(
          id: 'skeleton-1',
          date: DateTime.now(),
          amountCents: 0,
          createdAt: DateTime.now(),
          userId: userId,
          currency: selectedCurrency,
        ),
      ],
      null,
      selectedCurrency: selectedCurrency,
      householdId: householdId,
      onViewAll: () {},
    ),
  );
}

Widget _buildBreakdownSkeleton(BuildContext context) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: Theme.of(context).colorScheme.skeletonBase,
      highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
    ),
    child: Card(
      color: Theme.of(context).colorScheme.cardSurface,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chart placeholder'),
      ),
    ),
  );
}

Widget _buildWhereMoneyWentSkeleton(BuildContext context) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: Theme.of(context).colorScheme.skeletonBase,
      highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
    ),
    child: Card(
      color: Theme.of(context).colorScheme.cardSurface,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Row placeholder'),
      ),
    ),
  );
}

class LazyHouseholdBudgetOverviewCard extends ConsumerWidget {
  const LazyHouseholdBudgetOverviewCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final fromDate =
        DateTime(range['from']!.year, range['from']!.month, range['from']!.day);
    final toDate =
        DateTime(range['to']!.year, range['to']!.month, range['to']!.day);
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
    );
    final summaryAsync = ref.watch(householdDerivedSummaryProvider(params));
    final summary = summaryAsync.valueOrNull;
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }

    if (summary == null && summaryAsync.hasError) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }
    if (summary == null) {
      return summaryAsync.isLoading
          ? _buildBreakdownSkeleton(context)
          : const SizedBox.shrink();
    }

    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );
    final spendOnly = mergedTransactions
        .where((tx) => (tx.type ?? 'expense').toLowerCase() != 'income')
        .toList(growable: false);
    final totalSpentByHouseholdCents = spendOnly.fold<int>(
      0,
      (sum, tx) => sum + tx.amountCents.abs(),
    );

    return buildHouseholdBudgetOverviewCard(
      context,
      Theme.of(context).colorScheme,
      summary,
      config.dateRange,
      totalExpensesCentsOverride: totalSpentByHouseholdCents,
      transactionCountOverride: spendOnly.length,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionsPage(
              householdId: household.id,
              enableDateFilter: true,
              initialStartDate: fromDate,
              initialEndDate: toDate,
            ),
          ),
        );
      },
    );
  }
}

class LazyHouseholdFairnessCard extends ConsumerWidget {
  const LazyHouseholdFairnessCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
    );
    final summaryAsync = ref.watch(householdDerivedSummaryProvider(params));
    final summary = summaryAsync.valueOrNull;
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: referenceNow,
    );
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(household.id).notifier)
            .loadRecurringTransactions(userId);
      });
    }
    if (summary == null && summaryAsync.hasError) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }
    if (splitsAsync.hasError && !splitsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
      );
    }
    if (summary == null) return const SizedBox.shrink();

    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      includeFutureOccurrences: false,
    );

    return GroupFairnessMeter(
      summary: summary,
      transactions: mergedTransactions,
      splits: splitsAsync.valueOrNull,
      from: range['from'],
      to: range['to'],
      currency: selectedCurrency,
      dateRange: config.dateRange,
    );
  }
}

class LazyHouseholdSettlementCard extends ConsumerWidget {
  const LazyHouseholdSettlementCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(householdMembersProvider(household.id));
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
    );
    final summaryAsync = ref.watch(householdDerivedSummaryProvider(params));
    final summary = summaryAsync.valueOrNull;
    if (summary == null || userId == null) {
      return summaryAsync.isLoading
          ? _buildBreakdownSkeleton(context)
          : const SizedBox.shrink();
    }

    return SettlementSuggestionsCard(
      summary: summary,
      currency: selectedCurrency,
      members: membersAsync.valueOrNull,
      currentUserId: userId,
    );
  }
}

Widget _buildDashboardErrorCard(
  BuildContext context,
  ColorScheme colorScheme,
  String message, {
  required VoidCallback onRetry,
}) {
  return Card(
    color: colorScheme.cardSurface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: TextStyle(color: colorScheme.foreground)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    ),
  );
}
