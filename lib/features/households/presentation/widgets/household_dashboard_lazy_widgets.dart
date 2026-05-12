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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (!recurringState.hasLoadedOnce && !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    Widget child;

    if ((transactionsAsync.isLoading &&
            !transactionsAsync.hasValue &&
            transactions.isEmpty) ||
        (splitsAsync.isLoading && !splitsAsync.hasValue)) {
      child = _buildSpentByYouSkeleton(
        context,
        selectedCurrency,
        config.dateRange,
        referenceNow,
        key: const ValueKey('spent_by_you_skeleton'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('spent_by_you_error_1'),
      );
    } else if (splitsAsync.hasError && !splitsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
        key: const ValueKey('spent_by_you_error_2'),
      );
    } else {
      final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
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

      child = GestureDetector(
        key: ValueKey('spent_by_you_data_${syntheticExpense.id}_$spentByUser'),
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: FinancialCalendarWidget(
        key: ValueKey('household_fin_cal_${recurringAsync.data.valueOrNull?.length}_$selectedCurrency'),
        userId: userId,
        householdId: household.id,
        recurringTransactions: recurringAsync.data.valueOrNull ?? const [],
        currency: selectedCurrency,
        isExpanded: config.viewMode == DashboardWidgetViewMode.full,
      ),
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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId != null &&
        userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
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

    Widget child;

    if (summary == null && summaryAsync.hasError) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
        key: const ValueKey('member_spending_error_1'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('member_spending_error_2'),
      );
    } else if (splitsAsync.hasError && !splitsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
        key: const ValueKey('member_spending_error_3'),
      );
    } else if (summary == null) {
      child = summaryAsync.isLoading
          ? Skeletonizer(
              key: const ValueKey('member_spending_skeleton'),
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
          : const SizedBox.shrink(key: ValueKey('member_spending_empty'));
    } else {
      final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
        recurringTransactions: recurringState.data.valueOrNull ?? const [],
        rangeStart: range['from']!,
        rangeEnd: range['to']!,
        selectedCurrency: selectedCurrency,
        includeFutureOccurrences: false,
      );

      child = buildHouseholdMemberSpendingCard(
        key: ValueKey(
            'member_spending_data_${summary.totals.totalExpensesCents}_${membersAsync.valueOrNull?.length}'),
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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
    final recentTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: recentAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
      limit: 5,
    );

    Widget child;

    if (recentAsync.isLoading &&
        !recentAsync.hasValue &&
        recentTransactions.isEmpty) {
      child = _buildRecentTransactionsSkeleton(
        context,
        selectedCurrency,
        household.id,
        userId,
        key: const ValueKey('household_recent_skeleton'),
      );
    } else if (recentAsync.hasError && !recentAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(
          dashboardRecentTransactionsProvider(
            DashboardRecentTransactionsRequest(query: query, limit: 5),
          ),
        ),
        key: const ValueKey('household_recent_error'),
      );
    } else {
      child = buildRecentTransactionsCard(
        context,
        Theme.of(context).colorScheme,
        recentTransactions,
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    Widget child;

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      child = _buildBreakdownSkeleton(
        context,
        key: const ValueKey('household_breakdown_skeleton'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('household_breakdown_error'),
      );
    } else {
      final expenses = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
        recurringTransactions: recurringState.data.valueOrNull ?? const [],
        rangeStart: range['from']!,
        rangeEnd: range['to']!,
        selectedCurrency: selectedCurrency,
        includeFutureOccurrences: false,
      );

      child = buildSpendingBreakdownChart(
        key: ValueKey(
            'household_breakdown_data_${expenses.length}_$selectedCurrency'),
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    Widget child;

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      child = _buildWhereMoneyWentSkeleton(
        context,
        key: const ValueKey('household_where_money_went_skeleton'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('household_where_money_went_error'),
      );
    } else {
      final expenses = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
        recurringTransactions: recurringState.data.valueOrNull ?? const [],
        rangeStart: range['from']!,
        rangeEnd: range['to']!,
        selectedCurrency: selectedCurrency,
        includeFutureOccurrences: false,
      );

      child = WhereTheMoneyWentWidget(
        key: ValueKey(
            'household_where_money_went_data_${expenses.length}_$selectedCurrency'),
        expenses: expenses,
        currency: selectedCurrency,
        onHelpTap: () =>
            showCategoryGuide(context, Theme.of(context).colorScheme),
        dateRange: config.dateRange,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }
}

Widget _buildSpentByYouSkeleton(
  BuildContext context,
  String currency,
  dateFilter,
  DateTime referenceNow, {
  Key? key,
}) {
  return Skeletonizer(
    key: key,
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
  String userId, {
  Key? key,
}) {
  return Skeletonizer(
    key: key,
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

Widget _buildBreakdownSkeleton(BuildContext context, {Key? key}) {
  return Skeletonizer(
    key: key,
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

Widget _buildWhereMoneyWentSkeleton(BuildContext context, {Key? key}) {
  return Skeletonizer(
    key: key,
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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    Widget child;

    if (summary == null && summaryAsync.hasError) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
        key: const ValueKey('household_budget_error_1'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('household_budget_error_2'),
      );
    } else if (summary == null) {
      child = summaryAsync.isLoading
          ? _buildBreakdownSkeleton(
              context,
              key: const ValueKey('household_budget_skeleton'),
            )
          : const SizedBox.shrink(key: ValueKey('household_budget_empty'));
    } else {
      final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
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

      child = buildHouseholdBudgetOverviewCard(
        key: ValueKey(
            'household_budget_data_${spendOnly.length}_$totalSpentByHouseholdCents'),
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    Widget child;

    if (summary == null && summaryAsync.hasError) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdDerivedSummaryProvider(params)),
        key: const ValueKey('fairness_error_1'),
      );
    } else if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
        key: const ValueKey('fairness_error_2'),
      );
    } else if (splitsAsync.hasError && !splitsAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(householdSplitsProvider(splitsParams)),
        key: const ValueKey('fairness_error_3'),
      );
    } else if (summary == null) {
      child = const SizedBox.shrink(key: ValueKey('fairness_empty'));
    } else {
      final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
        actualExpenses: transactions,
        recurringTransactions: recurringState.data.valueOrNull ?? const [],
        rangeStart: range['from']!,
        rangeEnd: range['to']!,
        selectedCurrency: selectedCurrency,
        includeFutureOccurrences: false,
      );

      child = GroupFairnessMeter(
        key: ValueKey(
            'fairness_data_${mergedTransactions.length}_$selectedCurrency'),
        summary: summary,
        transactions: mergedTransactions,
        splits: splitsAsync.valueOrNull,
        from: range['from'],
        to: range['to'],
        currency: selectedCurrency,
        dateRange: config.dateRange,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
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

    Widget child;

    if (summary == null || userId == null) {
      child = summaryAsync.isLoading
          ? _buildBreakdownSkeleton(
              context,
              key: const ValueKey('settlement_skeleton'),
            )
          : const SizedBox.shrink(key: ValueKey('settlement_empty'));
    } else {
      child = SettlementSuggestionsCard(
        key: ValueKey(
            'settlement_data_${summary.householdId}_${membersAsync.valueOrNull?.length}'),
        summary: summary,
        currency: selectedCurrency,
        members: membersAsync.valueOrNull,
        currentUserId: userId,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }
}

Widget _buildDashboardErrorCard(
  BuildContext context,
  ColorScheme colorScheme,
  String message, {
  required VoidCallback onRetry,
  Key? key,
}) {
  return Card(
    key: key,
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
