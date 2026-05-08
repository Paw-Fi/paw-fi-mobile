import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/widgets/where_the_money_went_widget.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/home/presentation/widgets/net_cashflow_card.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/home/presentation/widgets/spending_breakdown_chart.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:skeletonizer/skeletonizer.dart';

class LazyDashboardSpendingSummaryCard extends ConsumerWidget {
  const LazyDashboardSpendingSummaryCard({
    super.key,
    required this.config,
    required this.colorScheme,
    required this.contact,
    required this.userNow,
  });

  final DashboardWidgetConfig config;
  final ColorScheme colorScheme;
  final UserContact? contact;
  final DateTime userNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final currency = _displayCurrency(filterState.selectedCurrency, contact);
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
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
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: filterState.selectedCurrency,
      includeFutureOccurrences: false,
    );

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      return _buildSpendingSkeleton(
        context,
        colorScheme,
        config.dateRange,
        currency,
        userNow,
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }

    return buildSpendingCard(
      context,
      colorScheme,
      mergedTransactions,
      contact,
      config.dateRange,
      referenceNow: userNow,
      selectedCurrency: filterState.selectedCurrency,
      customStartDate: config.customStartDate,
      customEndDate: config.customEndDate,
    );
  }
}

class LazyDashboardNetCashflowCard extends ConsumerWidget {
  const LazyDashboardNetCashflowCard({
    super.key,
    required this.config,
    required this.colorScheme,
    required this.contact,
    required this.userNow,
    required this.budgets,
  });

  final DashboardWidgetConfig config;
  final ColorScheme colorScheme;
  final UserContact? contact;
  final DateTime userNow;
  final List budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final currentRange = _getDateRangeForFilter(
      config.dateRange,
      userNow,
      config.customStartDate,
      config.customEndDate,
    );
    final previousRange = _getPreviousDateRangeForFilter(
      config.dateRange,
      userNow,
      config.customStartDate,
      config.customEndDate,
    );

    final currentQuery = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
      startDate: currentRange.$1,
      endDate: currentRange.$2,
    );
    final previousQuery = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
      startDate: previousRange.$1,
      endDate: previousRange.$2,
    );

    final previousTransactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(previousQuery));
    final currentTransactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(currentQuery));
    final previousBaseTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: previousTransactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay:
          ref.watch(dashboardLocalOverlayTransactionsProvider(previousQuery)),
      query: previousQuery,
    );
    final currentBaseTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: currentTransactionsAsync.valueOrNull ?? const <ExpenseEntry>[],
      localOverlay:
          ref.watch(dashboardLocalOverlayTransactionsProvider(currentQuery)),
      query: currentQuery,
    );
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    final recurringTransactions = recurringState.data.valueOrNull ?? const [];

    if ((currentTransactionsAsync.isLoading &&
            !currentTransactionsAsync.hasValue &&
            currentBaseTransactions.isEmpty) ||
        (previousTransactionsAsync.isLoading &&
            !previousTransactionsAsync.hasValue &&
            previousBaseTransactions.isEmpty)) {
      return _buildNetCashflowSkeleton(context, colorScheme, budgets, contact,
          config, filterState.selectedCurrency);
    }
    if ((currentTransactionsAsync.hasError &&
            !currentTransactionsAsync.hasValue) ||
        (previousTransactionsAsync.hasError &&
            !previousTransactionsAsync.hasValue)) {
      return _buildDashboardErrorCard(
        context,
        colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () {
          ref.invalidate(dashboardCalendarTransactionsProvider(currentQuery));
          ref.invalidate(dashboardCalendarTransactionsProvider(previousQuery));
        },
      );
    }

    final currentTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: currentBaseTransactions,
      recurringTransactions: recurringTransactions,
      rangeStart: currentRange.$1,
      rangeEnd: currentRange.$2,
      selectedCurrency: filterState.selectedCurrency,
      includeFutureOccurrences: false,
    );
    final previousTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: previousBaseTransactions,
      recurringTransactions: recurringTransactions,
      rangeStart: previousRange.$1,
      rangeEnd: previousRange.$2,
      selectedCurrency: filterState.selectedCurrency,
      includeFutureOccurrences: false,
    );

    return buildNetCashflowCard(
      context,
      colorScheme,
      budgets.cast(),
      currentTransactions,
      previousTransactions,
      contact,
      config.dateRange,
      selectedCurrency: filterState.selectedCurrency,
      customStartDate: config.customStartDate,
      customEndDate: config.customEndDate,
    );
  }
}

class LazyDashboardFinancialCalendarCard extends ConsumerWidget {
  const LazyDashboardFinancialCalendarCard({
    super.key,
    required this.config,
    required this.colorScheme,
    required this.fallbackCurrency,
  });

  final DashboardWidgetConfig config;
  final ColorScheme colorScheme;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final auth = ref.watch(authProvider);
    final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;
    final recurringAsync = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );

    return FinancialCalendarWidget(
      userId: auth.uid,
      householdId: scope.activeAccountHouseholdId,
      recurringTransactions: recurringAsync.data.valueOrNull ?? const [],
      currency: selectedCurrency ?? fallbackCurrency,
      isExpanded: config.viewMode == DashboardWidgetViewMode.full,
    );
  }
}

class LazyDashboardRecentTransactionsCard extends ConsumerWidget {
  const LazyDashboardRecentTransactionsCard({
    super.key,
    required this.colorScheme,
    required this.contact,
  });

  final ColorScheme colorScheme;
  final UserContact? contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
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

    if (recentAsync.isLoading &&
        !recentAsync.hasValue &&
        recentTransactions.isEmpty) {
      return _buildRecentTransactionsSkeleton(
        context,
        colorScheme,
        filterState.selectedCurrency,
      );
    }
    if (recentAsync.hasError && !recentAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        colorScheme,
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
      colorScheme,
      recentTransactions,
      contact,
      selectedCurrency: filterState.selectedCurrency,
      onViewAll: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TransactionsPage(),
          ),
        );
      },
    );
  }
}

class LazyDashboardSpendingBreakdownCard extends ConsumerWidget {
  const LazyDashboardSpendingBreakdownCard({
    super.key,
    required this.config,
    required this.colorScheme,
    required this.userNow,
  });

  final DashboardWidgetConfig config;
  final ColorScheme colorScheme;
  final DateTime userNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final analyticsContact =
        ref.watch(dashboardUserContactProvider).valueOrNull;
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
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
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: filterState.selectedCurrency,
      includeFutureOccurrences: false,
    );

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      return _buildBreakdownSkeleton(colorScheme);
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }

    return buildSpendingBreakdownChart(
      context,
      colorScheme,
      expenses,
      const [],
      analyticsContact,
      config.dateRange,
      referenceNow: userNow,
      selectedCurrency: filterState.selectedCurrency,
      customStartDate: config.customStartDate,
      customEndDate: config.customEndDate,
    );
  }
}

class LazyDashboardWhereTheMoneyWentCard extends ConsumerWidget {
  const LazyDashboardWhereTheMoneyWentCard({
    super.key,
    required this.config,
    required this.colorScheme,
    required this.userNow,
  });

  final DashboardWidgetConfig config;
  final ColorScheme colorScheme;
  final DateTime userNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: filterState.selectedCurrency,
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
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: filterState.selectedCurrency,
      includeFutureOccurrences: false,
    );

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      return _buildWhereMoneyWentSkeleton(colorScheme);
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardErrorCard(
        context,
        colorScheme,
        context.l10n.errorLoadingDashboard,
        onRetry: () =>
            ref.invalidate(dashboardCalendarTransactionsProvider(query)),
      );
    }

    return WhereTheMoneyWentWidget(
      expenses: expenses,
      currency: filterState.selectedCurrency,
      onHelpTap: () => showCategoryGuide(context, colorScheme),
      dateRange: config.dateRange,
    );
  }
}

DashboardScopeQuery _buildScopedQuery({
  required WidgetRef ref,
  required HouseholdScope scope,
  required String? selectedCurrency,
  DateTime? startDate,
  DateTime? endDate,
  String? intervalGranularity,
}) {
  final userId = ref.watch(authProvider).uid;
  return DashboardScopeQuery(
    userId: userId,
    householdId: scope.activeAccountType == ActiveWalletType.personal
        ? null
        : scope.activeAccountHouseholdId,
    selectedCurrency: selectedCurrency,
    startDate: startDate,
    endDate: endDate,
    intervalGranularity: intervalGranularity,
  );
}

String _displayCurrency(String? selectedCurrency, UserContact? contact) {
  final currency = selectedCurrency?.trim().toUpperCase();
  if (currency != null && currency.isNotEmpty) {
    return currency;
  }
  final preferred = contact?.preferredCurrency?.trim().toUpperCase();
  if (preferred != null && preferred.isNotEmpty) {
    return preferred;
  }
  return 'USD';
}

Widget _buildSpendingSkeleton(
  BuildContext context,
  ColorScheme colorScheme,
  DateRangeFilter dateFilter,
  String currency,
  DateTime referenceNow,
) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: buildSpendingCard(
      context,
      colorScheme,
      [
        ExpenseEntry(
          id: 'skeleton-spending',
          date: DateTime.now(),
          amountCents: 0,
          createdAt: DateTime.now(),
          currency: currency,
          type: 'expense',
        ),
      ],
      null,
      dateFilter,
      referenceNow: referenceNow,
      selectedCurrency: currency,
    ),
  );
}

Widget _buildNetCashflowSkeleton(
  BuildContext context,
  ColorScheme colorScheme,
  List budgets,
  UserContact? contact,
  DashboardWidgetConfig config,
  String? selectedCurrency,
) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: buildNetCashflowCard(
      context,
      colorScheme,
      budgets.cast(),
      const <ExpenseEntry>[],
      const <ExpenseEntry>[],
      contact,
      config.dateRange,
      selectedCurrency: selectedCurrency,
      customStartDate: config.customStartDate,
      customEndDate: config.customEndDate,
    ),
  );
}

Widget _buildRecentTransactionsSkeleton(
  BuildContext context,
  ColorScheme colorScheme,
  String? selectedCurrency,
) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: buildRecentTransactionsCard(
      context,
      colorScheme,
      [
        ExpenseEntry(
          id: 'recent-skeleton-1',
          date: DateTime.now(),
          amountCents: 0,
          createdAt: DateTime.now(),
          currency: selectedCurrency ?? 'USD',
        ),
        ExpenseEntry(
          id: 'recent-skeleton-2',
          date: DateTime.now(),
          amountCents: 0,
          createdAt: DateTime.now(),
          currency: selectedCurrency ?? 'USD',
        ),
      ],
      null,
      selectedCurrency: selectedCurrency,
      onViewAll: () {},
    ),
  );
}

Widget _buildBreakdownSkeleton(ColorScheme colorScheme) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: Card(
      color: colorScheme.cardSurface,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending breakdown'),
            SizedBox(height: 8),
            Text('Chart placeholder'),
          ],
        ),
      ),
    ),
  );
}

Widget _buildWhereMoneyWentSkeleton(ColorScheme colorScheme) {
  return Skeletonizer(
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: Card(
      color: colorScheme.cardSurface,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where the money went'),
            SizedBox(height: 8),
            Text('Row placeholder'),
          ],
        ),
      ),
    ),
  );
}

(DateTime, DateTime) _getDateRangeForFilter(
  DateRangeFilter filter,
  DateTime now,
  DateTime? customStart,
  DateTime? customEnd,
) {
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final todayStart = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DateRangeFilter.today:
      return (todayStart, todayEnd);
    case DateRangeFilter.yesterday:
      final yStart = todayStart.subtract(const Duration(days: 1));
      final yEnd = todayEnd.subtract(const Duration(days: 1));
      return (yStart, yEnd);
    case DateRangeFilter.thisWeek:
      final weekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      return (weekStart, todayEnd);
    case DateRangeFilter.lastWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      final lastWeekEnd = thisWeekStart.subtract(const Duration(seconds: 1));
      return (lastWeekStart, lastWeekEnd);
    case DateRangeFilter.last7Days:
      final start = todayStart.subtract(const Duration(days: 6));
      return (start, todayEnd);
    case DateRangeFilter.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      return (start, todayEnd);
    case DateRangeFilter.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end =
          DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
      return (start, end);
    case DateRangeFilter.last3Months:
      final start = DateTime(now.year, now.month - 2, 1);
      return (start, todayEnd);
    case DateRangeFilter.last30Days:
      final start = todayStart.subtract(const Duration(days: 29));
      return (start, todayEnd);
    case DateRangeFilter.thisYear:
      final start = DateTime(now.year, 1, 1);
      return (start, todayEnd);
    case DateRangeFilter.allTime:
      final start = DateTime.fromMillisecondsSinceEpoch(0);
      return (start, todayEnd);
    case DateRangeFilter.custom:
      if (customStart != null && customEnd != null) {
        final start =
            DateTime(customStart.year, customStart.month, customStart.day);
        final end = DateTime(
            customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
        return (start, end);
      }
      final start = todayStart.subtract(const Duration(days: 29));
      return (start, todayEnd);
  }
}

(DateTime, DateTime) _getPreviousDateRangeForFilter(
  DateRangeFilter filter,
  DateTime now,
  DateTime? customStart,
  DateTime? customEnd,
) {
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final todayStart = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DateRangeFilter.today:
      final yStart = todayStart.subtract(const Duration(days: 1));
      final yEnd = todayEnd.subtract(const Duration(days: 1));
      return (yStart, yEnd);
    case DateRangeFilter.yesterday:
      final prevStart = todayStart.subtract(const Duration(days: 2));
      final prevEnd = todayEnd.subtract(const Duration(days: 2));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final prevStart = thisWeekStart.subtract(const Duration(days: 7));
      final prevEnd = thisWeekStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.lastWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      final prevStart = lastWeekStart.subtract(const Duration(days: 7));
      final prevEnd = lastWeekStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.last7Days:
      final currentStart = todayStart.subtract(const Duration(days: 6));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 6));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisMonth:
      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0).day;
      final dayToCompare = min(now.day, lastDayPrevMonth);
      final prevMonthEnd =
          DateTime(now.year, now.month - 1, dayToCompare, 23, 59, 59);
      return (prevMonthStart, prevMonthEnd);
    case DateRangeFilter.lastMonth:
      final currentStart = DateTime(now.year, now.month - 1, 1);
      final prevStart = DateTime(now.year, now.month - 2, 1);
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.last3Months:
      final currentStart = DateTime(now.year, now.month - 2, 1);
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = DateTime(prevEnd.year, prevEnd.month - 2, 1);
      return (prevStart, prevEnd);
    case DateRangeFilter.last30Days:
      final currentStart = todayStart.subtract(const Duration(days: 29));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisYear:
      final prevYear = now.year - 1;
      final lastDayPrevYear = DateTime(prevYear + 1, 1, 0).day;
      final dayToCompare = min(now.day, lastDayPrevYear);
      final prevEnd = DateTime(prevYear, now.month, dayToCompare, 23, 59, 59);
      final prevStart = DateTime(prevYear, 1, 1);
      return (prevStart, prevEnd);
    case DateRangeFilter.allTime:
      final currentStart = DateTime.fromMillisecondsSinceEpoch(0);
      final currentEnd = todayEnd;
      final span = currentEnd.difference(currentStart);
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(span);
      return (prevStart, prevEnd);
    case DateRangeFilter.custom:
      if (customStart != null && customEnd != null) {
        final start =
            DateTime(customStart.year, customStart.month, customStart.day);
        final end = DateTime(
            customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
        final span = end.difference(start);
        final prevEnd = start.subtract(const Duration(seconds: 1));
        final prevStart = prevEnd.subtract(span);
        return (prevStart, prevEnd);
      }
      final currentStart = todayStart.subtract(const Duration(days: 29));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      return (prevStart, prevEnd);
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
          Text(
            message,
            style: TextStyle(color: colorScheme.foreground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    ),
  );
}
