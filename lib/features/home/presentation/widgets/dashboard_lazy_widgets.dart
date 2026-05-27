import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
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
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
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

Widget _buildDashboardSwitcher(Widget child) {
  return AnimatedSize(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: _buildDashboardSwitcherTransition,
      child: child,
    ),
  );
}

Widget _buildDashboardSwitcherTransition(
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}

void _homeSpendTrace(String message) {
  assert(() {
    debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

double _traceExpenseTotal(Iterable<ExpenseEntry> entries) {
  return entries.fold<double>(0, (sum, entry) {
    final type = (entry.type ?? 'expense').toLowerCase();
    if (type == 'income') return sum;
    return sum + entry.amount.abs();
  });
}

String _traceAmount(num value) => value.toStringAsFixed(2);

String _traceDate(DateTime? value) {
  if (value == null) return '<none>';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

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
    final selectedCurrency = _selectedCurrency(ref);
    final selectedCurrencies = _selectedCurrencies(ref);
    final currency = _displayCurrency(selectedCurrency, contact);
    final rateTable = (selectedCurrencies?.length ?? 0) > 1
        ? ref.watch(currencyRateTableProvider).valueOrNull ??
            const CurrencyRateTable(
              baseCurrency: 'USD',
              rates: CurrencyRates.rates,
              isStale: true,
            )
        : null;
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: selectedCurrency,
      startDate: range['from'],
      endDate: range['to'],
    );
    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final baseTransactions =
        transactionsAsync.valueOrNull ?? const <ExpenseEntry>[];
    final overlayTransactions =
        ref.watch(dashboardLocalOverlayTransactionsProvider(query));
    final transactions = mergeDashboardTransactionsWithLocalOverlay(
      base: baseTransactions,
      localOverlay: overlayTransactions,
      query: query,
    );
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    _ensureRecurringTransactionsLoaded(ref, scope, recurringState);

    _homeSpendTrace(
      'spending-build phase=precheck scope=${scope.activeAccountType.name} '
      'household=${scope.activeAccountHouseholdId ?? '<personal>'} '
      'currency=${selectedCurrency ?? '<none>'} '
      'range=${_traceDate(range['from'])}..${_traceDate(range['to'])} '
      'txLoading=${transactionsAsync.isLoading} txHasValue=${transactionsAsync.hasValue} '
      'baseCount=${baseTransactions.length} baseTotal=${_traceAmount(_traceExpenseTotal(baseTransactions))} '
      'overlayCount=${overlayTransactions.length} overlayTotal=${_traceAmount(_traceExpenseTotal(overlayTransactions))} '
      'mergedActualCount=${transactions.length} mergedActualTotal=${_traceAmount(_traceExpenseTotal(transactions))} '
      'recLoading=${recurringState.data.isLoading} recHasValue=${recurringState.data.hasValue} '
      'recLoaded=${recurringState.hasLoadedOnce} recCount=${recurringState.data.valueOrNull?.length ?? 0} '
      'recReady=${_isRecurringTransactionsReady(recurringState)} recError=${_hasRecurringTransactionsError(recurringState)}',
    );

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      _homeSpendTrace('spending-render source=tx-skeleton');
      return _buildDashboardSwitcher(
        _buildSpendingSkeleton(
          context,
          colorScheme,
          config.dateRange,
          currency,
          userNow,
          key: const ValueKey('spending_skeleton'),
        ),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      _homeSpendTrace('spending-render source=tx-error error=${transactionsAsync.error}');
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () =>
              ref.invalidate(dashboardCalendarTransactionsProvider(query)),
          key: const ValueKey('spending_error'),
        ),
      );
    }
    if (_hasRecurringTransactionsError(recurringState)) {
      _homeSpendTrace('spending-render source=recurring-error error=${recurringState.data.error}');
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
                  .notifier)
              .refresh(ref.read(authProvider).uid),
          key: const ValueKey('spending_recurring_error'),
        ),
      );
    }
    if (!_isRecurringTransactionsReady(recurringState)) {
      _homeSpendTrace('spending-render source=recurring-skeleton actualTotal=${_traceAmount(_traceExpenseTotal(transactions))}');
      return _buildDashboardSwitcher(
        _buildSpendingSkeleton(
          context,
          colorScheme,
          config.dateRange,
          currency,
          userNow,
          key: const ValueKey('spending_recurring_skeleton'),
        ),
      );
    }

    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final mergedTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: false,
    );
    _homeSpendTrace(
      'spending-render source=data actualTotal=${_traceAmount(_traceExpenseTotal(transactions))} '
      'recCount=${recurringTransactions.length} finalCount=${mergedTransactions.length} '
      'finalTotal=${_traceAmount(_traceExpenseTotal(mergedTransactions))}',
    );

    return _buildDashboardSwitcher(
      buildSpendingCard(
        context,
        colorScheme,
        mergedTransactions,
        contact,
        config.dateRange,
        key: ValueKey('spending_data_${config.id}_$selectedCurrency'),
        referenceNow: userNow,
        selectedCurrency: selectedCurrency,
        selectedCurrencies: selectedCurrencies,
        currencyRates: rateTable,
        customStartDate: config.customStartDate,
        customEndDate: config.customEndDate,
      ),
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
    final selectedCurrency = _selectedCurrency(ref);
    final selectedCurrencies = _selectedCurrencies(ref);
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
      selectedCurrency: selectedCurrency,
      startDate: currentRange.$1,
      endDate: currentRange.$2,
    );
    final previousQuery = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: selectedCurrency,
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
    _ensureRecurringTransactionsLoaded(ref, scope, recurringState);

    if ((currentTransactionsAsync.isLoading &&
            !currentTransactionsAsync.hasValue &&
            currentBaseTransactions.isEmpty) ||
        (previousTransactionsAsync.isLoading &&
            !previousTransactionsAsync.hasValue &&
            previousBaseTransactions.isEmpty)) {
      return _buildDashboardSwitcher(
        _buildNetCashflowSkeleton(
          context,
          colorScheme,
          budgets,
          contact,
          config,
          selectedCurrency,
          key: const ValueKey('net_cashflow_skeleton'),
        ),
      );
    }
    if ((currentTransactionsAsync.hasError &&
            !currentTransactionsAsync.hasValue) ||
        (previousTransactionsAsync.hasError &&
            !previousTransactionsAsync.hasValue)) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () {
            ref.invalidate(dashboardCalendarTransactionsProvider(currentQuery));
            ref.invalidate(
                dashboardCalendarTransactionsProvider(previousQuery));
          },
          key: const ValueKey('net_cashflow_error'),
        ),
      );
    }
    if (_hasRecurringTransactionsError(recurringState)) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
                  .notifier)
              .refresh(ref.read(authProvider).uid),
          key: const ValueKey('net_cashflow_recurring_error'),
        ),
      );
    }
    if (!_isRecurringTransactionsReady(recurringState)) {
      return _buildDashboardSwitcher(
        _buildNetCashflowSkeleton(
          context,
          colorScheme,
          budgets,
          contact,
          config,
          selectedCurrency,
          key: const ValueKey('net_cashflow_recurring_skeleton'),
        ),
      );
    }

    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final currentTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: currentBaseTransactions,
      recurringTransactions: recurringTransactions,
      rangeStart: currentRange.$1,
      rangeEnd: currentRange.$2,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: false,
    );
    final previousTransactions = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: previousBaseTransactions,
      recurringTransactions: recurringTransactions,
      rangeStart: previousRange.$1,
      rangeEnd: previousRange.$2,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: false,
    );
    final shouldConvertCurrencies = (selectedCurrencies?.length ?? 0) > 1;
    final rates = shouldConvertCurrencies
        ? ref.watch(currencyRateTableProvider).valueOrNull ??
            const CurrencyRateTable(
              baseCurrency: 'USD',
              rates: CurrencyRates.rates,
              isStale: true,
            )
        : null;
    final displayCurrentTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            currentTransactions,
            targetCurrency: selectedCurrency ?? 'USD',
            rates: rates!,
          )
        : currentTransactions;
    final displayPreviousTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            previousTransactions,
            targetCurrency: selectedCurrency ?? 'USD',
            rates: rates!,
          )
        : previousTransactions;

    return _buildDashboardSwitcher(
      buildNetCashflowCard(
        context,
        colorScheme,
        budgets.cast(),
        displayCurrentTransactions,
        displayPreviousTransactions,
        contact,
        config.dateRange,
        key: ValueKey('net_cashflow_data_${config.id}_$selectedCurrency'),
        selectedCurrency: selectedCurrency,
        customStartDate: config.customStartDate,
        customEndDate: config.customEndDate,
      ),
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
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final selectedCurrency = _selectedCurrency(ref);
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    _ensureRecurringTransactionsLoaded(ref, scope, recurringState);

    if (_hasRecurringTransactionsError(recurringState)) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
                  .notifier)
              .refresh(ref.read(authProvider).uid),
          key: const ValueKey('financial_calendar_recurring_error'),
        ),
      );
    }
    if (!_isRecurringTransactionsReady(recurringState)) {
      return _buildDashboardSwitcher(
        Skeletonizer(
          key: const ValueKey('financial_calendar_recurring_skeleton'),
          effect: ShimmerEffect(
            baseColor: colorScheme.skeletonBase,
            highlightColor: colorScheme.skeletonHighlight,
          ),
          child: FinancialCalendarWidget(
            userId: userId,
            householdId: scope.activeAccountHouseholdId,
            recurringTransactions: const [],
            currency: selectedCurrency ?? fallbackCurrency,
            isExpanded: config.viewMode == DashboardWidgetViewMode.full,
          ),
        ),
      );
    }

    return _buildDashboardSwitcher(
      FinancialCalendarWidget(
        key: ValueKey(
            'fin_cal_${config.id}_${selectedCurrency ?? fallbackCurrency}'),
        userId: userId,
        householdId: scope.activeAccountHouseholdId,
        recurringTransactions: recurringState.data.valueOrNull ?? const [],
        currency: selectedCurrency ?? fallbackCurrency,
        isExpanded: config.viewMode == DashboardWidgetViewMode.full,
      ),
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
    final selectedCurrency = _selectedCurrency(ref);
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
      selectedCurrency: selectedCurrency,
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
      return _buildDashboardSwitcher(
        _buildRecentTransactionsSkeleton(
          context,
          colorScheme,
          selectedCurrency,
          key: const ValueKey('recent_skeleton'),
        ),
      );
    }
    if (recentAsync.hasError && !recentAsync.hasValue) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref.invalidate(
            dashboardRecentTransactionsProvider(
              DashboardRecentTransactionsRequest(query: query, limit: 5),
            ),
          ),
          key: const ValueKey('recent_error'),
        ),
      );
    }

    return _buildDashboardSwitcher(
      buildRecentTransactionsCard(
        context,
        colorScheme,
        recentTransactions,
        contact,
        selectedCurrency: selectedCurrency,
        selectedCurrencies: query.normalizedCurrencies,
        householdId: query.householdId,
        onViewAll: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TransactionsPage(),
            ),
          );
        },
      ),
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
    final selectedCurrency = _selectedCurrency(ref);
    final selectedCurrencies = _selectedCurrencies(ref);
    final analyticsContact = ref.watch(
      dashboardUserContactProvider.select((state) => state.valueOrNull),
    );
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
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
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    _ensureRecurringTransactionsLoaded(ref, scope, recurringState);

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      return _buildDashboardSwitcher(
        _buildBreakdownSkeleton(
          colorScheme,
          key: const ValueKey('breakdown_skeleton'),
        ),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () =>
              ref.invalidate(dashboardCalendarTransactionsProvider(query)),
          key: const ValueKey('breakdown_error'),
        ),
      );
    }
    if (_hasRecurringTransactionsError(recurringState)) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
                  .notifier)
              .refresh(ref.read(authProvider).uid),
          key: const ValueKey('breakdown_recurring_error'),
        ),
      );
    }
    if (!_isRecurringTransactionsReady(recurringState)) {
      return _buildDashboardSwitcher(
        _buildBreakdownSkeleton(
          colorScheme,
          key: const ValueKey('breakdown_recurring_skeleton'),
        ),
      );
    }

    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: false,
    );
    final displayExpenses = (selectedCurrencies?.length ?? 0) > 1
        ? convertTransactionsToCurrency(
            expenses,
            targetCurrency: selectedCurrency ?? 'USD',
            rates: ref.watch(currencyRateTableProvider).valueOrNull ??
                const CurrencyRateTable(
                  baseCurrency: 'USD',
                  rates: CurrencyRates.rates,
                  isStale: true,
                ),
          )
        : expenses;

    return _buildDashboardSwitcher(
      buildSpendingBreakdownChart(
        context,
        colorScheme,
        displayExpenses,
        const [],
        analyticsContact,
        config.dateRange,
        key: ValueKey('breakdown_data_${config.id}_$selectedCurrency'),
        referenceNow: userNow,
        selectedCurrency: selectedCurrency,
        customStartDate: config.customStartDate,
        customEndDate: config.customEndDate,
      ),
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
    final selectedCurrency = _selectedCurrency(ref);
    final selectedCurrencies = _selectedCurrencies(ref);
    final range = getDateRangeFromFilter(
      config.dateRange,
      config.customStartDate,
      config.customEndDate,
      now: userNow,
    );
    final query = _buildScopedQuery(
      ref: ref,
      scope: scope,
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
    final recurringState = ref.watch(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    _ensureRecurringTransactionsLoaded(ref, scope, recurringState);

    if (transactionsAsync.isLoading &&
        !transactionsAsync.hasValue &&
        transactions.isEmpty) {
      return _buildDashboardSwitcher(
        _buildWhereMoneyWentSkeleton(
          colorScheme,
          key: const ValueKey('where_money_went_skeleton'),
        ),
      );
    }
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () =>
              ref.invalidate(dashboardCalendarTransactionsProvider(query)),
          key: const ValueKey('where_money_went_error'),
        ),
      );
    }
    if (_hasRecurringTransactionsError(recurringState)) {
      return _buildDashboardSwitcher(
        _buildDashboardErrorCard(
          context,
          colorScheme,
          context.l10n.errorLoadingDashboard,
          onRetry: () => ref
              .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
                  .notifier)
              .refresh(ref.read(authProvider).uid),
          key: const ValueKey('where_money_went_recurring_error'),
        ),
      );
    }
    if (!_isRecurringTransactionsReady(recurringState)) {
      return _buildDashboardSwitcher(
        _buildWhereMoneyWentSkeleton(
          colorScheme,
          key: const ValueKey('where_money_went_recurring_skeleton'),
        ),
      );
    }

    final recurringTransactions = recurringState.data.valueOrNull ?? const [];
    final expenses = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: transactions,
      recurringTransactions: recurringTransactions,
      rangeStart: range['from']!,
      rangeEnd: range['to']!,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: false,
    );
    final displayExpenses = (selectedCurrencies?.length ?? 0) > 1
        ? convertTransactionsToCurrency(
            expenses,
            targetCurrency: selectedCurrency ?? 'USD',
            rates: ref.watch(currencyRateTableProvider).valueOrNull ??
                const CurrencyRateTable(
                  baseCurrency: 'USD',
                  rates: CurrencyRates.rates,
                  isStale: true,
                ),
          )
        : expenses;

    return _buildDashboardSwitcher(
      WhereTheMoneyWentWidget(
        key: ValueKey('where_money_went_data_${config.id}_$selectedCurrency'),
        expenses: displayExpenses,
        currency: selectedCurrency,
        onHelpTap: () => showCategoryGuide(context, colorScheme),
        dateRange: config.dateRange,
      ),
    );
  }
}

void _ensureRecurringTransactionsLoaded(
  WidgetRef ref,
  HouseholdScope scope,
  RecurringTransactionsState recurringState,
) {
  if (recurringState.hasLoadedOnce) return;

  final userId = ref.read(authProvider).uid;
  if (userId.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final current = ref.read(
      recurringTransactionsProvider(scope.activeAccountHouseholdId),
    );
    if (current.hasLoadedOnce) return;
    ref
        .read(recurringTransactionsProvider(scope.activeAccountHouseholdId)
            .notifier)
        .loadRecurringTransactions(userId);
  });
}

bool _isRecurringTransactionsReady(RecurringTransactionsState recurringState) {
  if (recurringState.data.hasError && !recurringState.data.hasValue) {
    return false;
  }
  final cachedRows = recurringState.data.valueOrNull;
  if (cachedRows != null && cachedRows.isNotEmpty) return true;
  return recurringState.hasLoadedOnce && recurringState.data.hasValue;
}

bool _hasRecurringTransactionsError(RecurringTransactionsState recurringState) {
  return recurringState.data.hasError && !recurringState.data.hasValue;
}

DashboardScopeQuery _buildScopedQuery({
  required WidgetRef ref,
  required HouseholdScope scope,
  required String? selectedCurrency,
  DateTime? startDate,
  DateTime? endDate,
  String? intervalGranularity,
}) {
  final userId = ref.watch(authProvider.select((user) => user.uid));
  final selectedCurrencies = _selectedCurrencies(ref);
  return DashboardScopeQuery(
    userId: userId,
    householdId: scope.activeAccountType == ActiveWalletType.personal
        ? null
        : scope.activeAccountHouseholdId,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
    startDate: startDate,
    endDate: endDate,
    intervalGranularity: intervalGranularity,
  );
}

String? _selectedCurrency(WidgetRef ref) {
  return ref.watch(
    homeFilterProvider.select((state) => state.selectedCurrency),
  );
}

List<String>? _selectedCurrencies(WidgetRef ref) {
  return ref.watch(
    homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
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
  DateTime referenceNow, {
  Key? key,
}) {
  return Skeletonizer(
    key: key,
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
  String? selectedCurrency, {
  Key? key,
}) {
  return Skeletonizer(
    key: key,
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
  String? selectedCurrency, {
  Key? key,
}) {
  final now = DateTime.now();
  return Skeletonizer(
    key: key,
    effect: ShimmerEffect(
      baseColor: colorScheme.skeletonBase,
      highlightColor: colorScheme.skeletonHighlight,
    ),
    child: buildRecentTransactionsCard(
      context,
      colorScheme,
      List.generate(
        5,
        (index) => ExpenseEntry(
          id: 'recent-skeleton-$index',
          date: now.subtract(Duration(minutes: index)),
          amountCents: 0,
          createdAt: now.subtract(Duration(minutes: index)),
          currency: selectedCurrency ?? 'USD',
        ),
      ),
      null,
      selectedCurrency: selectedCurrency,
      selectedCurrencies:
          selectedCurrency == null ? null : <String>[selectedCurrency],
      onViewAll: () {},
    ),
  );
}

Widget _buildBreakdownSkeleton(ColorScheme colorScheme, {Key? key}) {
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
              SizedBox(height: 8),
              Text('Current period'),
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

Widget _buildWhereMoneyWentSkeleton(ColorScheme colorScheme, {Key? key}) {
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
              SizedBox(height: 8),
              Text('Current period'),
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
