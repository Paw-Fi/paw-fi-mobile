import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/utils/dashboard_synthetic_entries.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';
import 'package:moneko/features/home/presentation/widgets/spending_breakdown_chart.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/group_fairness_meter.dart';
import 'package:moneko/features/households/presentation/widgets/household_budget_overview_card.dart';
import 'package:moneko/features/households/presentation/widgets/household_member_spending_card.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/features/households/presentation/utils/member_spending_attribution.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:skeletonizer/skeletonizer.dart';

HouseholdSummaryParams buildHouseholdSummaryParams({
  required Household household,
  required String selectedCurrency,
  required DashboardWidgetConfig config,
  DateTime? referenceNow,
  int financialMonthStartDay = 1,
  HomePeriodDateRange? selectedPeriod,
}) {
  final range = selectedPeriod == null
      ? getDateRangeFromFilter(
          config.dateRange,
          config.customStartDate,
          config.customEndDate,
          now: referenceNow,
          financialMonthStartDay: financialMonthStartDay,
        )
      : {'from': selectedPeriod.start, 'to': selectedPeriod.end};
  return HouseholdSummaryParams(
    householdId: household.id,
    currency: selectedCurrency,
    startDate: range['from']!.toIso8601String(),
    endDate: range['to']!.toIso8601String(),
  );
}

HomePeriodDateRange _selectedHomePeriodRange(WidgetRef ref, String userId) {
  return ref.watch(homePeriodDateRangeProvider(userId));
}

Widget _buildDashboardSwitcher(Widget child) {
  return child;
}

List<String>? _selectedCurrencies(WidgetRef ref) {
  return ref.watch(
    homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
  );
}

CurrencyRateTable _currencyRates(WidgetRef ref) {
  return ref.watch(currencyRateTableProvider).valueOrNull ??
      const CurrencyRateTable(
        baseCurrency: 'USD',
        rates: CurrencyRates.rates,
        isStale: true,
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
    if (!isBackendHouseholdId(household.id)) {
      return const SizedBox.shrink();
    }
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final range = _selectedHomePeriodRange(ref, userId);
    final selectedCurrencyFilters = _selectedCurrencies(ref);
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencyFilters,
      startDate: range.start,
      endDate: range.end,
    );
    final projectionAsync = ref.watch(
      householdDashboardProjectionProvider(query),
    );
    Widget child;

    if (!projectionAsync.hasValue && !projectionAsync.hasError) {
      child = _buildSpentByYouSkeleton(
        context,
        selectedCurrency,
        config.dateRange,
        referenceNow,
        key: const ValueKey('spent_by_you_skeleton'),
      );
    } else if (projectionAsync.hasError && !projectionAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () {
          ref.invalidate(householdDashboardProjectionProvider(query));
        },
        key: const ValueKey('spent_by_you_error_1'),
      );
    } else {
      final projection = projectionAsync.valueOrNull!;
      final totals = computeSplitAwareMemberSpendingTotals(
        transactions: projection.expensesWithRecurring,
        from: range['from']!,
        to: range['to']!,
        splits: projection.splits,
        selectedCurrency: selectedCurrency,
        currencyRates: (selectedCurrencyFilters?.length ?? 0) > 1
            ? _currencyRates(ref)
            : null,
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
        key: ValueKey(
            'spent_by_you_data_${household.id}_${config.id}_$selectedCurrency'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionsPage(
                householdId: household.id,
                enableDateFilter: true,
                initialDateFilter: DateRangeFilter.custom,
                initialStartDate: range.start,
                initialEndDate: range.end,
              ),
            ),
          );
        },
        child: buildSpendingCard(
          context,
          Theme.of(context).colorScheme,
          [syntheticExpense],
          null,
          // The dashboard period picker owns the query range. Passing the
          // widget's saved display setting here would filter the already
          // scoped synthetic entry a second time (and could turn it into $0
          // after a restart).
          DateRangeFilter.custom,
          referenceNow: referenceNow,
          selectedCurrency: selectedCurrency,
          customStartDate: range.start,
          customEndDate: range.end,
          headerLabel: context.l10n.spendByYou,
          animationStorageKey:
              'household_spent_by_you:${household.id}:${config.id}:$selectedCurrency:${config.dateRange.name}:${config.viewMode.name}:${config.customStartDate?.microsecondsSinceEpoch ?? ''}:${config.customEndDate?.microsecondsSinceEpoch ?? ''}',
        ),
      );
    }

    return _buildDashboardSwitcher(child);
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
    final recurringState =
        ref.watch(recurringTransactionsProvider(household.id));
    if (userId.isNotEmpty && !recurringState.hasLoadedOnce) {
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(household.id).notifier);
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(userId);
      });
    }

    if (recurringState.data.hasError && !recurringState.data.hasValue) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          Theme.of(context).colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(household.id).notifier)
              .refresh(userId),
          key: const ValueKey('household_calendar_recurring_error'),
        ),
      );
    }

    if (!recurringState.hasLoadedOnce || !recurringState.data.hasValue) {
      final colorScheme = Theme.of(context).colorScheme;
      return _buildDashboardSwitcher(
        Skeletonizer(
          key: const ValueKey('household_calendar_recurring_skeleton'),
          effect: ShimmerEffect(
            baseColor: colorScheme.skeletonBase,
            highlightColor: colorScheme.skeletonHighlight,
          ),
          child: FinancialCalendarWidget(
            userId: userId,
            householdId: household.id,
            recurringTransactions: const [],
            currency: selectedCurrency,
            isExpanded: config.viewMode == DashboardWidgetViewMode.full,
          ),
        ),
      );
    }

    return _buildDashboardSwitcher(
      FinancialCalendarWidget(
        key: ValueKey(
            'household_fin_cal_${household.id}_${config.id}_$selectedCurrency'),
        userId: userId,
        householdId: household.id,
        recurringTransactions: recurringState.data.valueOrNull!,
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
    required this.includeBudgetsInSummary,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;
  final bool includeBudgetsInSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
    final range = _selectedHomePeriodRange(ref, userId ?? '');
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
      financialMonthStartDay: financialMonthStartDay,
      selectedPeriod: range,
    );
    final summaryProvider = includeBudgetsInSummary
        ? householdDerivedSummaryProvider(params)
        : householdDerivedSummaryWithoutBudgetsProvider(params);
    final summaryAsync = ref.watch(summaryProvider);
    final summary = summaryAsync.valueOrNull;
    final projection = ref
        .watch(
          householdDashboardProjectionProvider(
            DashboardScopeQuery(
              userId: userId ?? '',
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              selectedCurrencies: _selectedCurrencies(ref),
              startDate: range.start,
              endDate: range.end,
            ),
          ),
        )
        .valueOrNull;

    Widget child;

    if (summary == null && summaryAsync.hasError) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(summaryProvider),
        key: const ValueKey('member_spending_error_1'),
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
                dateRangeFilter: DateRangeFilter.custom,
                currentUserId: userId,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('member_spending_empty'));
    } else {
      child = buildHouseholdMemberSpendingCard(
        key: ValueKey(
            'member_spending_data_${household.id}_${config.id}_$selectedCurrency'),
        context,
        Theme.of(context).colorScheme,
        summary,
        householdId: household.id,
        selectedCurrency: selectedCurrency,
        dateRangeFilter: DateRangeFilter.custom,
        currentUserId: userId,
        transactions: projection?.expensesWithRecurring,
        splits: projection?.splits,
        from: range.start,
        to: range.end,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionsPage(
                householdId: household.id,
                enableDateFilter: true,
                initialDateFilter: DateRangeFilter.custom,
                initialStartDate: range['from'],
                initialEndDate: range['to'],
              ),
            ),
          );
        },
      );
    }

    return _buildDashboardSwitcher(child);
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
    final selectedPeriod = _selectedHomePeriodRange(ref, userId);
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: _selectedCurrencies(ref),
      startDate: selectedPeriod.start,
      endDate: selectedPeriod.end,
    );
    final recurringTransactions = ref
            .watch(recurringTransactionsProvider(household.id))
            .data
            .valueOrNull ??
        const <RecurringTransaction>[];
    final occurrenceResolution = ref.watch(
      recurringOccurrenceProjectionResolutionProvider(
        RecurringOccurrenceProjectionResolutionQuery(
          userId: userId,
          householdId: household.id,
          startDate: selectedPeriod.start,
          endDate: selectedPeriod.end,
        ),
      ),
    );
    final recentAsync = ref.watch(
      dashboardRecentTransactionsProvider(
        DashboardRecentTransactionsRequest(query: query, limit: 5),
      ),
    );
    final rawRecentTransactions = mergeHouseholdDashboardExpenses(
      base: recentAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
      optimisticExpenses: ref.watch(
        householdOptimisticExpensesProvider.select(
          (state) => state[household.id] ?? const <ExpenseEntry>[],
        ),
      ),
      deletedIds: ref.watch(
        householdOptimisticDeletedExpenseIdsProvider.select(
          (state) => state[household.id] ?? const <String>{},
        ),
      ),
      limit: 5,
    );
    final recentTransactions = <ExpenseEntry>[
      ...rawRecentTransactions.where(
        (entry) =>
            extractRecurringTransactionIdFromProjectedExpenseId(entry.id) ==
            null,
      ),
      ...dedupeProjectedRecurringExpenseEntries(
        projectedExpenses: rawRecentTransactions
            .where(
              (entry) =>
                  extractRecurringTransactionIdFromProjectedExpenseId(
                      entry.id) !=
                  null,
            )
            .toList(growable: false),
        actualExpenses: <ExpenseEntry>[
          ...rawRecentTransactions.where(
            (entry) =>
                extractRecurringTransactionIdFromProjectedExpenseId(entry.id) ==
                null,
          ),
          ...occurrenceResolution.suppressionEntries,
        ],
      ),
    ];

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
        selectedCurrencies: query.normalizedCurrencies,
        householdId: household.id,
        recurringTransactionsById: {
          for (final transaction in recurringTransactions)
            transaction.id: transaction,
        },
        recurringOccurrencesByActualTransactionId:
            occurrenceResolution.occurrencesByActualTransactionId,
        recurringIdsByActualTransactionId:
            occurrenceResolution.recurringIdsByActualTransactionId,
        onViewAll: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionsPage(
                householdId: household.id,
                enableDateFilter: true,
                initialDateFilter: DateRangeFilter.custom,
                initialStartDate: selectedPeriod.start,
                initialEndDate: selectedPeriod.end,
              ),
            ),
          );
        },
      );
    }

    return _buildDashboardSwitcher(child);
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
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final range = _selectedHomePeriodRange(ref, userId);
    final selectedCurrencyFilters = _selectedCurrencies(ref);
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencyFilters,
      startDate: range.start,
      endDate: range.end,
    );
    final projectionAsync = ref.watch(
      householdDashboardProjectionProvider(query),
    );
    Widget child;

    if (!projectionAsync.hasValue && !projectionAsync.hasError) {
      child = _buildBreakdownSkeleton(
        context,
        key: const ValueKey('household_breakdown_skeleton'),
      );
    } else if (projectionAsync.hasError && !projectionAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () {
          ref.invalidate(householdDashboardProjectionProvider(query));
        },
        key: const ValueKey('household_breakdown_error'),
      );
    } else {
      final expenses = projectionAsync.valueOrNull!.expensesWithRecurring;
      final displayExpenses = (selectedCurrencyFilters?.length ?? 0) > 1
          ? convertTransactionsToCurrency(
              expenses,
              targetCurrency: selectedCurrency,
              rates: _currencyRates(ref),
            )
          : expenses;

      child = buildSpendingBreakdownChart(
        key: ValueKey(
            'household_breakdown_data_${household.id}_${config.id}_$selectedCurrency'),
        context,
        Theme.of(context).colorScheme,
        displayExpenses,
        const [],
        null,
        DateRangeFilter.custom,
        referenceNow: referenceNow,
        selectedCurrency: selectedCurrency,
        customStartDate: range.start,
        customEndDate: range.end,
      );
    }

    return _buildDashboardSwitcher(child);
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
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final range = _selectedHomePeriodRange(ref, userId);
    final selectedCurrencyFilters = _selectedCurrencies(ref);
    final query = DashboardScopeQuery(
      userId: userId,
      householdId: household.id,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencyFilters,
      startDate: range.start,
      endDate: range.end,
    );
    final projectionAsync = ref.watch(
      householdDashboardProjectionProvider(query),
    );
    Widget child;

    if (!projectionAsync.hasValue && !projectionAsync.hasError) {
      child = _buildWhereMoneyWentSkeleton(
        context,
        key: const ValueKey('household_where_money_went_skeleton'),
      );
    } else if (projectionAsync.hasError && !projectionAsync.hasValue) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () {
          ref.invalidate(householdDashboardProjectionProvider(query));
        },
        key: const ValueKey('household_where_money_went_error'),
      );
    } else {
      final expenses = projectionAsync.valueOrNull!.expensesWithRecurring;
      final displayExpenses = (selectedCurrencyFilters?.length ?? 0) > 1
          ? convertTransactionsToCurrency(
              expenses,
              targetCurrency: selectedCurrency,
              rates: _currencyRates(ref),
            )
          : expenses;

      child = WhereTheMoneyWentWidget(
        key: ValueKey(
            'household_where_money_went_data_${household.id}_${config.id}_$selectedCurrency'),
        expenses: displayExpenses,
        currency: selectedCurrency,
        onHelpTap: () =>
            showCategoryGuide(context, Theme.of(context).colorScheme),
        dateRange: DateRangeFilter.custom,
      );
    }

    return _buildDashboardSwitcher(child);
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
      headerLabel: context.l10n.spendByYou,
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
  final now = DateTime.now();
  return Skeletonizer(
    key: key,
    effect: ShimmerEffect(
      baseColor: Theme.of(context).colorScheme.skeletonBase,
      highlightColor: Theme.of(context).colorScheme.skeletonHighlight,
    ),
    child: buildRecentTransactionsCard(
      context,
      Theme.of(context).colorScheme,
      List.generate(
        5,
        (index) => ExpenseEntry(
          id: 'household-recent-skeleton-$index',
          date: now.subtract(Duration(minutes: index)),
          amountCents: 0,
          createdAt: now.subtract(Duration(minutes: index)),
          userId: userId,
          currency: selectedCurrency,
        ),
      ),
      null,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: <String>[selectedCurrency],
      householdId: householdId,
      onViewAll: () {},
    ),
  );
}

Widget _buildBreakdownSkeleton(BuildContext context, {Key? key}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Skeletonizer(
    key: key,
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: SizedBox(
      height: 360,
      child: Card(
        color: colorScheme.cardSurface,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spending breakdown'),
              SizedBox(height: 32),
              Expanded(child: Center(child: Text('Chart placeholder'))),
              SizedBox(height: 24),
              Text('Legend placeholder'),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildWhereMoneyWentSkeleton(BuildContext context, {Key? key}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Skeletonizer(
    key: key,
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: SizedBox(
      height: 320,
      child: Card(
        color: colorScheme.cardSurface,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where the money went'),
              SizedBox(height: 32),
              Text('Category row placeholder'),
              SizedBox(height: 16),
              Text('Category row placeholder'),
              SizedBox(height: 16),
              Text('Category row placeholder'),
            ],
          ),
        ),
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
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final range = _selectedHomePeriodRange(ref, userId);
    final fromDate =
        DateTime(range.start.year, range.start.month, range.start.day);
    final toDate = DateTime(range.end.year, range.end.month, range.end.day);
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
      financialMonthStartDay: financialMonthStartDay,
      selectedPeriod: range,
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
        key: const ValueKey('household_budget_error_1'),
      );
    } else if (summary == null) {
      child = summaryAsync.isLoading
          ? _buildBreakdownSkeleton(
              context,
              key: const ValueKey('household_budget_skeleton'),
            )
          : const SizedBox.shrink(key: ValueKey('household_budget_empty'));
    } else {
      child = buildHouseholdBudgetOverviewCard(
        key: ValueKey(
            'household_budget_data_${household.id}_${config.id}_$selectedCurrency'),
        context,
        Theme.of(context).colorScheme,
        summary,
        DateRangeFilter.custom,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionsPage(
                householdId: household.id,
                enableDateFilter: true,
                initialDateFilter: DateRangeFilter.custom,
                initialStartDate: fromDate,
                initialEndDate: toDate,
              ),
            ),
          );
        },
      );
    }

    return _buildDashboardSwitcher(child);
  }
}

class LazyHouseholdFairnessCard extends ConsumerWidget {
  const LazyHouseholdFairnessCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
    required this.referenceNow,
    required this.includeBudgetsInSummary,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;
  final DateTime referenceNow;
  final bool includeBudgetsInSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final range = _selectedHomePeriodRange(ref, userId);
    final params = buildHouseholdSummaryParams(
      household: household,
      selectedCurrency: selectedCurrency,
      config: config,
      referenceNow: referenceNow,
      financialMonthStartDay: financialMonthStartDay,
      selectedPeriod: range,
    );
    final summaryProvider = includeBudgetsInSummary
        ? householdDerivedSummaryProvider(params)
        : householdDerivedSummaryWithoutBudgetsProvider(params);
    final summaryAsync = ref.watch(summaryProvider);
    final summary = summaryAsync.valueOrNull;
    Widget child;

    if (summary == null && summaryAsync.hasError) {
      child = _buildDashboardErrorCard(
        context,
        Theme.of(context).colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () => ref.invalidate(summaryProvider),
        key: const ValueKey('fairness_error_1'),
      );
    } else if (summary == null) {
      child = const SizedBox.shrink(key: ValueKey('fairness_empty'));
    } else {
      child = GroupFairnessMeter(
        key: ValueKey(
            'fairness_data_${household.id}_${config.id}_$selectedCurrency'),
        summary: summary,
        dateRange: DateRangeFilter.custom,
      );
    }

    return _buildDashboardSwitcher(child);
  }
}

class LazyHouseholdSettlementCard extends ConsumerStatefulWidget {
  const LazyHouseholdSettlementCard({
    super.key,
    required this.household,
    required this.config,
    required this.selectedCurrency,
  });

  final Household household;
  final DashboardWidgetConfig config;
  final String selectedCurrency;

  @override
  ConsumerState<LazyHouseholdSettlementCard> createState() =>
      _LazyHouseholdSettlementCardState();
}

class _LazyHouseholdSettlementCardState
    extends ConsumerState<LazyHouseholdSettlementCard> {
  @override
  Widget build(BuildContext context) {
    if (!isBackendHouseholdId(widget.household.id)) {
      return const SizedBox.shrink();
    }
    final userId = ref.watch(currentUserIdProvider);
    final membersAsync =
        ref.watch(householdMembersProvider(widget.household.id));

    Widget child;

    if (userId == null) {
      child = const SizedBox.shrink(key: ValueKey('settlement_empty'));
    } else {
      child = SettlementSuggestionsCard(
        key: ValueKey(
            'settlement_data_${widget.household.id}_${widget.config.id}_${widget.selectedCurrency}'),
        householdId: widget.household.id,
        currency: widget.selectedCurrency,
        selectedCurrencies: _selectedCurrencies(ref),
        // Member records only resolve labels. The cached split/payment
        // snapshot remains authoritative for amounts, so a member refresh
        // must not replace an already-visible settlement card with a skeleton.
        members: membersAsync.valueOrNull,
        currentUserId: userId,
      );
    }

    return _buildDashboardSwitcher(child);
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
