import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/goals/domain/models/goal.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart'
    as goals;
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _monthlyReportCacheNamespace = 'monthly_report';

class MonthlyFinancialReportSnapshot {
  const MonthlyFinancialReportSnapshot({
    required this.report,
    required this.lastSyncedAt,
    this.isRefreshing = false,
  });

  final MonthlyFinancialReport report;
  final DateTime? lastSyncedAt;
  final bool isRefreshing;

  MonthlyFinancialReportSnapshot copyWith({
    MonthlyFinancialReport? report,
    DateTime? lastSyncedAt,
    bool? isRefreshing,
  }) {
    return MonthlyFinancialReportSnapshot(
      report: report ?? this.report,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class MonthlyReportNotifier
    extends AsyncNotifier<MonthlyFinancialReportSnapshot> {
  @override
  Future<MonthlyFinancialReportSnapshot> build() async {
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final userId = user.uid;
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final appLocale = resolveSupportedAppLocale(ref.watch(localeProvider));
    final l10n = lookupAppLocalizations(appLocale);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final historicalStart = DateTime(now.year, now.month - 6);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);
    final cacheKey = _monthlyReportCacheKey(
      userId: userId,
      scope: householdScope.activeAccountType.name,
      householdId: householdId,
      monthStart: monthStart,
      currencyCode: currencyCode,
      localeTag: appLocale.toLanguageTag(),
    );

    if (preview.isActive) {
      throw UnsupportedError(
        'Monthly financial health uses real account data and is unavailable in preview mode.',
      );
    }

    if (userId.isEmpty) {
      return MonthlyFinancialReportSnapshot(
        lastSyncedAt: null,
        report: buildMonthlyFinancialReport(
          MonthlyReportInput(
            monthStart: monthStart,
            now: now,
            currencyCode: currencyCode,
            currentBalance: 0,
            currentMonthTransactions: const [],
            previousMonthTransactions: const [],
            historicalTransactions: const [],
            budgetItems: const [],
            futureTransactions: const [],
            recurringItems: const [],
            goals: const [],
          ),
          l10n: l10n,
        ),
      );
    }

    final cachedSnapshot = await _readCachedSnapshot(cacheKey);
    if (cachedSnapshot != null) {
      Future<void>.microtask(() => _refreshFromSources(
            userId: userId,
            householdId: householdId,
            currencyCode: currencyCode,
            now: now,
            monthStart: monthStart,
            monthEnd: monthEnd,
            previousMonthStart: previousMonthStart,
            previousMonthEnd: previousMonthEnd,
            historicalStart: historicalStart,
            pocketsScope: pocketsScope,
            cacheKey: cacheKey,
            l10n: l10n,
            publish: true,
            watchDependencies: false,
          ));
      return cachedSnapshot.copyWith(isRefreshing: true);
    }

    return _refreshFromSources(
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      now: now,
      monthStart: monthStart,
      monthEnd: monthEnd,
      previousMonthStart: previousMonthStart,
      previousMonthEnd: previousMonthEnd,
      historicalStart: historicalStart,
      pocketsScope: pocketsScope,
      cacheKey: cacheKey,
      l10n: l10n,
      publish: false,
      watchDependencies: true,
    );
  }

  Future<void> refreshReport() async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }

    try {
      final context = _currentReportContext();
      final refreshed = await _refreshFromSources(
        userId: context.userId,
        householdId: context.householdId,
        currencyCode: context.currencyCode,
        now: context.now,
        monthStart: context.monthStart,
        monthEnd: context.monthEnd,
        previousMonthStart: context.previousMonthStart,
        previousMonthEnd: context.previousMonthEnd,
        historicalStart: context.historicalStart,
        pocketsScope: context.pocketsScope,
        cacheKey: context.cacheKey,
        l10n: context.l10n,
        publish: false,
        watchDependencies: false,
      );
      state = AsyncData(refreshed);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous.copyWith(isRefreshing: false));
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  _MonthlyReportContext _currentReportContext() {
    final user = ref.read(authProvider);
    final userId = user.uid;
    final currencyCode = ref.read(selectedHomeCurrencyCodeProvider);
    final appLocale = resolveSupportedAppLocale(ref.read(localeProvider));
    final l10n = lookupAppLocalizations(appLocale);
    final preferredTimezone = ref.read(appPreferredTimezoneProvider);
    final householdScope = ref.read(householdScopeProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final historicalStart = DateTime(now.year, now.month - 6);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);
    return _MonthlyReportContext(
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      now: now,
      monthStart: monthStart,
      monthEnd: monthEnd,
      previousMonthStart: previousMonthStart,
      previousMonthEnd: previousMonthEnd,
      historicalStart: historicalStart,
      pocketsScope: pocketsScope,
      cacheKey: _monthlyReportCacheKey(
        userId: userId,
        scope: householdScope.activeAccountType.name,
        householdId: householdId,
        monthStart: monthStart,
        currencyCode: currencyCode,
        localeTag: appLocale.toLanguageTag(),
      ),
      l10n: l10n,
    );
  }

  Future<MonthlyFinancialReportSnapshot> _refreshFromSources({
    required String userId,
    required String? householdId,
    required String currencyCode,
    required DateTime now,
    required DateTime monthStart,
    required DateTime monthEnd,
    required DateTime previousMonthStart,
    required DateTime previousMonthEnd,
    required DateTime historicalStart,
    required PocketsScopeType pocketsScope,
    required String cacheKey,
    required AppLocalizations l10n,
    required bool publish,
    required bool watchDependencies,
  }) async {
    final currentQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: monthStart,
      endDate: monthEnd,
    );
    final previousQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: previousMonthStart,
      endDate: previousMonthEnd,
    );
    final historicalQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: historicalStart,
      endDate: previousMonthEnd,
    );

    final currentProvider = dashboardCalendarTransactionsProvider(currentQuery);
    final previousProvider =
        dashboardCalendarTransactionsProvider(previousQuery);
    final historicalProvider =
        dashboardCalendarTransactionsProvider(historicalQuery);
    final currentBase = await (watchDependencies
        ? ref.watch(currentProvider.future)
        : ref.read(currentProvider.future));
    final previousBase = await (watchDependencies
        ? ref.watch(previousProvider.future)
        : ref.read(previousProvider.future));
    final historicalBase = await (watchDependencies
        ? ref.watch(historicalProvider.future)
        : ref.read(historicalProvider.future));
    final currentTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: currentBase,
      localOverlay: watchDependencies
          ? ref.watch(dashboardLocalOverlayTransactionsProvider(currentQuery))
          : ref.read(dashboardLocalOverlayTransactionsProvider(currentQuery)),
      query: currentQuery,
    );
    final previousTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: previousBase,
      localOverlay: watchDependencies
          ? ref.watch(dashboardLocalOverlayTransactionsProvider(previousQuery))
          : ref.read(dashboardLocalOverlayTransactionsProvider(previousQuery)),
      query: previousQuery,
    );
    final historicalTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: historicalBase,
      localOverlay: watchDependencies
          ? ref.watch(dashboardLocalOverlayTransactionsProvider(historicalQuery))
          : ref.read(dashboardLocalOverlayTransactionsProvider(historicalQuery)),
      query: historicalQuery,
    );

    final recurringTransactions = await _loadRecurringTransactions(
      ref,
      userId: userId,
      householdId: householdId,
      watchDependencies: watchDependencies,
    );
    final futureTransactions = _futureTransactionsForReport(
      actualTransactions: currentTransactions,
      recurringTransactions: recurringTransactions,
      now: now,
      monthEnd: monthEnd,
      currencyCode: currencyCode,
    );
    final recurringItems = _recurringItemsForReport(
      recurringTransactions,
      previousTransactions: previousTransactions,
      now: now,
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencyCode: currencyCode,
    );

    final pocketsParams = PocketsScopeParams(
      scope: pocketsScope,
      householdId: householdId,
      periodMonth: monthStart,
      currency: currencyCode,
      includeUpcomingRecurring: true,
    );
    final pocketsState = watchDependencies
        ? ref.watch(pocketsProvider(pocketsParams))
        : ref.read(pocketsProvider(pocketsParams));
    if (pocketsState.isLoading && !pocketsState.hasDisplayData) {
      await ref.read(pocketsProvider(pocketsParams).notifier).load();
    }
    final loadedPocketsState = ref.read(pocketsProvider(pocketsParams));
    if (loadedPocketsState.error != null &&
        loadedPocketsState.error!.trim().isNotEmpty) {
      throw StateError('Budget data unavailable: ${loadedPocketsState.error}');
    }

    final walletSnapshot = await _readWalletSnapshot(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      monthStart: monthStart,
      watchDependencies: watchDependencies,
    );
    final previousNetWorth = await _readPreviousNetWorth(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      monthStart: monthStart,
      watchDependencies: watchDependencies,
    );
    final goalInputsResult = await _loadGoalInputsForReport(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
    );
    final report = buildMonthlyFinancialReport(
      MonthlyReportInput(
        monthStart: monthStart,
        now: now,
        currencyCode: currencyCode,
        currentBalance: walletSnapshot.netWorthCents / 100.0,
        currentMonthTransactions:
            currentTransactions.map(_transactionInput).toList(growable: false),
        previousMonthTransactions:
            previousTransactions.map(_transactionInput).toList(growable: false),
        historicalTransactions:
            historicalTransactions.map(_transactionInput).toList(growable: false),
        budgetItems: _budgetInputs(loadedPocketsState.editing),
        futureTransactions:
            futureTransactions.map(_transactionInput).toList(growable: false),
        recurringItems: recurringItems,
        goals: goalInputsResult.items,
        previousNetWorth: previousNetWorth,
        goalsDataAvailable: goalInputsResult.dataAvailable,
      ),
      l10n: l10n,
    );
    final completedAt = DateTime.now().toUtc();
    final snapshot = MonthlyFinancialReportSnapshot(
      report: report,
      lastSyncedAt: completedAt,
    );
    await _writeCachedSnapshot(cacheKey, snapshot);
    if (publish && state.valueOrNull != null) {
      state = AsyncData(snapshot);
    }
    return snapshot;
  }

  Future<MonthlyFinancialReportSnapshot?> _readCachedSnapshot(
    String cacheKey,
  ) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      final entry = await database.getJsonCache(
        namespace: _monthlyReportCacheNamespace,
        cacheKey: cacheKey,
      );
      if (entry == null) return null;
      return MonthlyFinancialReportSnapshot(
        report: _monthlyReportFromJson(entry.payload),
        lastSyncedAt: entry.cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedSnapshot(
    String cacheKey,
    MonthlyFinancialReportSnapshot snapshot,
  ) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.upsertJsonCache(
        namespace: _monthlyReportCacheNamespace,
        cacheKey: cacheKey,
        payload: _monthlyReportToJson(snapshot.report),
        cachedAt: snapshot.lastSyncedAt,
      );
    } catch (_) {}
  }
}

class _MonthlyReportContext {
  const _MonthlyReportContext({
    required this.userId,
    required this.householdId,
    required this.currencyCode,
    required this.now,
    required this.monthStart,
    required this.monthEnd,
    required this.previousMonthStart,
    required this.previousMonthEnd,
    required this.historicalStart,
    required this.pocketsScope,
    required this.cacheKey,
    required this.l10n,
  });

  final String userId;
  final String? householdId;
  final String currencyCode;
  final DateTime now;
  final DateTime monthStart;
  final DateTime monthEnd;
  final DateTime previousMonthStart;
  final DateTime previousMonthEnd;
  final DateTime historicalStart;
  final PocketsScopeType pocketsScope;
  final String cacheKey;
  final AppLocalizations l10n;
}

final monthlyFinancialReportProvider = AsyncNotifierProvider<
    MonthlyReportNotifier, MonthlyFinancialReportSnapshot>(
  MonthlyReportNotifier.new,
);

String _monthlyReportCacheKey({
  required String userId,
  required String scope,
  required String? householdId,
  required DateTime monthStart,
  required String currencyCode,
  required String localeTag,
}) {
  final month =
      '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';
  return 'monthly-report:v1:$userId:$scope:${householdId ?? 'personal'}:$month:${currencyCode.toUpperCase()}:$localeTag';
}

Map<String, dynamic> _monthlyReportToJson(MonthlyFinancialReport report) {
  return {
    'month_start': report.monthStart.toIso8601String(),
    'currency_code': report.currencyCode,
    'overview': {
      'income': report.overview.income,
      'spending': report.overview.spending,
      'savings': report.overview.savings,
      'current_balance': report.overview.currentBalance,
      'forecasted_balance': report.overview.forecastedBalance,
      'status': report.overview.status.name,
    },
    'safe_to_spend': {
      'daily_amount': report.safeToSpend.dailyAmount,
      'days_remaining': report.safeToSpend.daysRemaining,
      'budget_remaining': report.safeToSpend.budgetRemaining,
      'future_income': report.safeToSpend.futureIncome,
      'future_obligations': report.safeToSpend.futureObligations,
    },
    'spending_pace': report.spendingPace
        .map((item) => {
              'label': item.label,
              'spent_progress': item.spentProgress,
              'time_progress': item.timeProgress,
              'status': item.status.name,
              'insight': item.insight,
            })
        .toList(growable: false),
    'budget_health': report.budgetHealth
        .map((item) => {
              'name': item.name,
              'status': item.status.name,
              'budget_amount': item.budgetAmount,
              'spent': item.spent,
              'remaining': item.remaining,
            })
        .toList(growable: false),
    'anomalies': report.anomalies.map(_insightToJson).toList(growable: false),
    'subscriptions': {
      'total_monthly_amount': report.subscriptions.totalMonthlyAmount,
      'items': report.subscriptions.items
          .map((item) => {
                'name': item.name,
                'amount': item.amount,
                'next_date': item.nextDate.toIso8601String(),
                'status': item.status.name,
                'note': item.note,
              })
          .toList(growable: false),
    },
    'upcoming_obligations': report.upcomingObligations
        .map((item) => {
              'date': item.date.toIso8601String(),
              'name': item.name,
              'amount': item.amount,
              'type': item.type,
            })
        .toList(growable: false),
    'cash_flow_forecast': report.cashFlowForecast
        .map((item) => {
              'label': item.label,
              'balance': item.balance,
            })
        .toList(growable: false),
    'goals': report.goals
        .map((item) => {
              'title': item.title,
              'target_amount': item.targetAmount,
              'current_amount': item.currentAmount,
              'progress': item.progress,
              'monthly_needed': item.monthlyNeeded,
              'status': item.status.name,
            })
        .toList(growable: false),
    'trend_summary': {
      'current_income': report.trendSummary.currentIncome,
      'previous_income': report.trendSummary.previousIncome,
      'income_change': report.trendSummary.incomeChange,
      'income_change_percent': report.trendSummary.incomeChangePercent,
      'current_spending': report.trendSummary.currentSpending,
      'previous_spending': report.trendSummary.previousSpending,
      'spending_change': report.trendSummary.spendingChange,
      'spending_change_percent': report.trendSummary.spendingChangePercent,
      'current_savings': report.trendSummary.currentSavings,
      'previous_savings': report.trendSummary.previousSavings,
      'savings_rate': report.trendSummary.savingsRate,
      'previous_savings_rate': report.trendSummary.previousSavingsRate,
      'net_cash_flow': report.trendSummary.netCashFlow,
    },
    'budget_plan': {
      'total_budgeted': report.budgetPlan.totalBudgeted,
      'total_spent': report.budgetPlan.totalSpent,
      'total_remaining': report.budgetPlan.totalRemaining,
      'over_budget_count': report.budgetPlan.overBudgetCount,
      'at_risk_count': report.budgetPlan.atRiskCount,
      'unbudgeted_spent': report.budgetPlan.unbudgetedSpent,
      'budget_to_income_ratio': report.budgetPlan.budgetToIncomeRatio,
    },
    'category_trends': report.categoryTrends
        .map((item) => {
              'name': item.name,
              'current_spent': item.currentSpent,
              'previous_spent': item.previousSpent,
              'baseline_average_spent': item.baselineAverageSpent,
              'previous_change': item.previousChange,
              'previous_change_percent': item.previousChangePercent,
              'baseline_change': item.baselineChange,
              'baseline_change_percent': item.baselineChangePercent,
              'status': item.status.name,
              'insight': item.insight,
            })
        .toList(growable: false),
    'merchant_concentration': report.merchantConcentration
        .map((item) => {
              'name': item.name,
              'amount': item.amount,
              'transaction_count': item.transactionCount,
              'spending_share': item.spendingShare,
            })
        .toList(growable: false),
    'recurring_commitment': {
      'monthly_amount': report.recurringCommitment.monthlyAmount,
      'income_share': report.recurringCommitment.incomeShare,
      'due_soon_amount': report.recurringCommitment.dueSoonAmount,
      'due_soon_count': report.recurringCommitment.dueSoonCount,
      'status': report.recurringCommitment.status.name,
    },
    'cash_flow_health': {
      'low_water_balance': report.cashFlowHealth.lowWaterBalance,
      'low_water_date': report.cashFlowHealth.lowWaterDate?.toIso8601String(),
      'first_negative_date':
          report.cashFlowHealth.firstNegativeDate?.toIso8601String(),
      'status': report.cashFlowHealth.status.name,
    },
    'net_worth_trend': report.netWorthTrend == null
        ? null
        : {
            'current_net_worth': report.netWorthTrend!.currentNetWorth,
            'previous_net_worth': report.netWorthTrend!.previousNetWorth,
            'change': report.netWorthTrend!.change,
            'change_percent': report.netWorthTrend!.changePercent,
          },
    'goals_data_available': report.goalsDataAvailable,
    'summary': report.summary,
  };
}

Map<String, dynamic> _insightToJson(MonthlyInsightItem item) {
  return {
    'title': item.title,
    'description': item.description,
    'status': item.status.name,
    'category_name': item.categoryName,
    'increase_percent': item.increasePercent,
  };
}

MonthlyFinancialReport _monthlyReportFromJson(Map<String, dynamic> json) {
  final overview = Map<String, dynamic>.from(json['overview'] as Map);
  final safeToSpend = Map<String, dynamic>.from(json['safe_to_spend'] as Map);
  final subscriptions = Map<String, dynamic>.from(json['subscriptions'] as Map);
  final trendSummary = Map<String, dynamic>.from(json['trend_summary'] as Map);
  final budgetPlan = Map<String, dynamic>.from(json['budget_plan'] as Map);
  final recurringCommitment =
      Map<String, dynamic>.from(json['recurring_commitment'] as Map);
  final cashFlowHealth =
      Map<String, dynamic>.from(json['cash_flow_health'] as Map);
  final netWorthTrend = json['net_worth_trend'] as Map?;

  return MonthlyFinancialReport(
    monthStart: DateTime.parse(json['month_start'] as String),
    currencyCode: json['currency_code'] as String? ?? 'USD',
    overview: MonthlyOverview(
      income: _num(json: overview, key: 'income'),
      spending: _num(json: overview, key: 'spending'),
      savings: _num(json: overview, key: 'savings'),
      currentBalance: _num(json: overview, key: 'current_balance'),
      forecastedBalance: _num(json: overview, key: 'forecasted_balance'),
      status: _monthlyReportStatus(overview['status']),
    ),
    safeToSpend: MonthlySafeToSpend(
      dailyAmount: _num(json: safeToSpend, key: 'daily_amount'),
      daysRemaining: _int(json: safeToSpend, key: 'days_remaining'),
      budgetRemaining: _num(json: safeToSpend, key: 'budget_remaining'),
      futureIncome: _num(json: safeToSpend, key: 'future_income'),
      futureObligations: _num(json: safeToSpend, key: 'future_obligations'),
    ),
    spendingPace: _list(json['spending_pace'])
        .map((item) => MonthlySpendingPaceItem(
              label: item['label'] as String? ?? '',
              spentProgress: _num(json: item, key: 'spent_progress'),
              timeProgress: _num(json: item, key: 'time_progress'),
              status: _monthlyReportStatus(item['status']),
              insight: item['insight'] as String? ?? '',
            ))
        .toList(growable: false),
    budgetHealth: _list(json['budget_health'])
        .map((item) => MonthlyBudgetHealthItem(
              name: item['name'] as String? ?? '',
              status: _monthlyReportStatus(item['status']),
              budgetAmount: _num(json: item, key: 'budget_amount'),
              spent: _num(json: item, key: 'spent'),
              remaining: _num(json: item, key: 'remaining'),
            ))
        .toList(growable: false),
    anomalies:
        _list(json['anomalies']).map(_insightFromJson).toList(growable: false),
    subscriptions: MonthlySubscriptionReport(
      totalMonthlyAmount:
          _num(json: subscriptions, key: 'total_monthly_amount'),
      items: _list(subscriptions['items'])
          .map((item) => MonthlySubscriptionItem(
                name: item['name'] as String? ?? '',
                amount: _num(json: item, key: 'amount'),
                nextDate: DateTime.parse(item['next_date'] as String),
                status: _monthlySubscriptionStatus(item['status']),
                note: item['note'] as String? ?? '',
              ))
          .toList(growable: false),
    ),
    upcomingObligations: _list(json['upcoming_obligations'])
        .map((item) => MonthlyCashFlowItem(
              date: DateTime.parse(item['date'] as String),
              name: item['name'] as String? ?? '',
              amount: _num(json: item, key: 'amount'),
              type: item['type'] as String? ?? 'expense',
            ))
        .toList(growable: false),
    cashFlowForecast: _list(json['cash_flow_forecast'])
        .map((item) => MonthlyCashFlowPoint(
              label: item['label'] as String? ?? '',
              balance: _num(json: item, key: 'balance'),
            ))
        .toList(growable: false),
    goals: _list(json['goals'])
        .map((item) => MonthlyGoalReportItem(
              title: item['title'] as String? ?? '',
              targetAmount: _num(json: item, key: 'target_amount'),
              currentAmount: _num(json: item, key: 'current_amount'),
              progress: _num(json: item, key: 'progress'),
              monthlyNeeded: _num(json: item, key: 'monthly_needed'),
              status: _monthlyReportStatus(item['status']),
            ))
        .toList(growable: false),
    trendSummary: MonthlyTrendSummary(
      currentIncome: _num(json: trendSummary, key: 'current_income'),
      previousIncome: _num(json: trendSummary, key: 'previous_income'),
      incomeChange: _num(json: trendSummary, key: 'income_change'),
      incomeChangePercent:
          _nullableNum(json: trendSummary, key: 'income_change_percent'),
      currentSpending: _num(json: trendSummary, key: 'current_spending'),
      previousSpending: _num(json: trendSummary, key: 'previous_spending'),
      spendingChange: _num(json: trendSummary, key: 'spending_change'),
      spendingChangePercent:
          _nullableNum(json: trendSummary, key: 'spending_change_percent'),
      currentSavings: _num(json: trendSummary, key: 'current_savings'),
      previousSavings: _num(json: trendSummary, key: 'previous_savings'),
      savingsRate: _num(json: trendSummary, key: 'savings_rate'),
      previousSavingsRate:
          _num(json: trendSummary, key: 'previous_savings_rate'),
      netCashFlow: _num(json: trendSummary, key: 'net_cash_flow'),
    ),
    budgetPlan: MonthlyBudgetPlanSummary(
      totalBudgeted: _num(json: budgetPlan, key: 'total_budgeted'),
      totalSpent: _num(json: budgetPlan, key: 'total_spent'),
      totalRemaining: _num(json: budgetPlan, key: 'total_remaining'),
      overBudgetCount: _int(json: budgetPlan, key: 'over_budget_count'),
      atRiskCount: _int(json: budgetPlan, key: 'at_risk_count'),
      unbudgetedSpent: _num(json: budgetPlan, key: 'unbudgeted_spent'),
      budgetToIncomeRatio:
          _nullableNum(json: budgetPlan, key: 'budget_to_income_ratio'),
    ),
    categoryTrends: _list(json['category_trends'])
        .map((item) => MonthlyCategoryTrendItem(
              name: item['name'] as String? ?? '',
              currentSpent: _num(json: item, key: 'current_spent'),
              previousSpent: _num(json: item, key: 'previous_spent'),
              baselineAverageSpent:
                  _num(json: item, key: 'baseline_average_spent'),
              previousChange: _num(json: item, key: 'previous_change'),
              previousChangePercent:
                  _nullableNum(json: item, key: 'previous_change_percent'),
              baselineChange: _num(json: item, key: 'baseline_change'),
              baselineChangePercent:
                  _nullableNum(json: item, key: 'baseline_change_percent'),
              status: _monthlyReportStatus(item['status']),
              insight: item['insight'] as String? ?? '',
            ))
        .toList(growable: false),
    merchantConcentration: _list(json['merchant_concentration'])
        .map((item) => MonthlyMerchantSpendItem(
              name: item['name'] as String? ?? '',
              amount: _num(json: item, key: 'amount'),
              transactionCount: _int(json: item, key: 'transaction_count'),
              spendingShare: _num(json: item, key: 'spending_share'),
            ))
        .toList(growable: false),
    recurringCommitment: MonthlyRecurringCommitmentSummary(
      monthlyAmount: _num(json: recurringCommitment, key: 'monthly_amount'),
      incomeShare: _nullableNum(json: recurringCommitment, key: 'income_share'),
      dueSoonAmount: _num(json: recurringCommitment, key: 'due_soon_amount'),
      dueSoonCount: _int(json: recurringCommitment, key: 'due_soon_count'),
      status: _monthlyReportStatus(recurringCommitment['status']),
    ),
    cashFlowHealth: MonthlyCashFlowHealth(
      lowWaterBalance: _num(json: cashFlowHealth, key: 'low_water_balance'),
      lowWaterDate: _nullableDate(cashFlowHealth['low_water_date']),
      firstNegativeDate: _nullableDate(cashFlowHealth['first_negative_date']),
      status: _monthlyReportStatus(cashFlowHealth['status']),
    ),
    netWorthTrend: netWorthTrend == null
        ? null
        : MonthlyNetWorthTrend(
            currentNetWorth: _num(
              json: Map<String, dynamic>.from(netWorthTrend),
              key: 'current_net_worth',
            ),
            previousNetWorth: _num(
              json: Map<String, dynamic>.from(netWorthTrend),
              key: 'previous_net_worth',
            ),
            change: _num(
              json: Map<String, dynamic>.from(netWorthTrend),
              key: 'change',
            ),
            changePercent: _nullableNum(
              json: Map<String, dynamic>.from(netWorthTrend),
              key: 'change_percent',
            ),
          ),
    goalsDataAvailable: json['goals_data_available'] != false,
    summary: json['summary'] as String? ?? '',
  );
}

MonthlyInsightItem _insightFromJson(Map<String, dynamic> json) {
  return MonthlyInsightItem(
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    status: _monthlyReportStatus(json['status']),
    categoryName: json['category_name'] as String?,
    increasePercent: (json['increase_percent'] as num?)?.toInt(),
  );
}

List<Map<String, dynamic>> _list(Object? value) {
  return ((value as List?) ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double _num({
  required Map<String, dynamic> json,
  required String key,
}) {
  return (json[key] as num?)?.toDouble() ?? 0;
}

double? _nullableNum({
  required Map<String, dynamic> json,
  required String key,
}) {
  return (json[key] as num?)?.toDouble();
}

int _int({
  required Map<String, dynamic> json,
  required String key,
}) {
  return (json[key] as num?)?.toInt() ?? 0;
}

DateTime? _nullableDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

MonthlyReportStatus _monthlyReportStatus(Object? value) {
  final name = value?.toString();
  return MonthlyReportStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => MonthlyReportStatus.needsAttention,
  );
}

MonthlySubscriptionStatus _monthlySubscriptionStatus(Object? value) {
  final name = value?.toString();
  return MonthlySubscriptionStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => MonthlySubscriptionStatus.active,
  );
}

String? _reportHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      return scope.activeAccountHouseholdId;
    case ActiveWalletType.household:
      return scope.selectedHouseholdId ?? scope.activeAccountHouseholdId;
  }
}

PocketsScopeType _pocketsScopeType(ActiveWalletType type) {
  switch (type) {
    case ActiveWalletType.personal:
      return PocketsScopeType.personal;
    case ActiveWalletType.portfolio:
      return PocketsScopeType.portfolio;
    case ActiveWalletType.household:
      return PocketsScopeType.household;
  }
}

Future<List<RecurringTransaction>> _loadRecurringTransactions(
  Ref ref, {
  required String userId,
  required String? householdId,
  required bool watchDependencies,
}) async {
  final provider = recurringTransactionsProvider(householdId);
  final state = watchDependencies ? ref.watch(provider) : ref.read(provider);
  if (!state.hasLoadedOnce && !state.data.isLoading) {
    await ref
        .read(provider.notifier)
        .loadRecurringTransactions(userId);
  }
  return ref.read(provider).data.valueOrNull ??
      state.data.valueOrNull ??
      const <RecurringTransaction>[];
}

Future<WalletsMonthSnapshot> _readWalletSnapshot(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
  required DateTime monthStart,
  required bool watchDependencies,
}) async {
  final provider = walletsMonthSnapshotProvider(
    WalletsMonthQuery(
      scope: WalletsScopeQuery(
        userId: userId,
        householdId: householdId,
        selectedCurrency: currencyCode,
        currentMonthStart: monthStart,
      ),
      monthStart: monthStart,
    ),
  );
  return watchDependencies ? ref.watch(provider.future) : ref.read(provider.future);
}

Future<double?> _readPreviousNetWorth(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
  required DateTime monthStart,
  required bool watchDependencies,
}) async {
  final provider = walletsHistoryProvider(
    WalletsScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      currentMonthStart: monthStart,
    ),
  );
  final history =
      await (watchDependencies ? ref.watch(provider.future) : ref.read(provider.future));
  final priorPoints = history.netWorthSeries
      .where((point) => point.monthStart.isBefore(monthStart))
      .toList(growable: false)
    ..sort((a, b) => b.monthStart.compareTo(a.monthStart));
  if (priorPoints.isEmpty) return null;
  return priorPoints.first.netWorthCents / 100.0;
}

Future<_GoalInputsResult> _loadGoalInputsForReport(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
}) async {
  try {
    final supabase = ref.read(goals.supabaseProvider);
    final response = await supabase.functions.invoke(
      'list-goals',
      method: HttpMethod.get,
      queryParameters: {
        'userId': userId,
        if (householdId != null) 'householdId': householdId,
        'status': 'active',
      },
    );
    if (response.status != 200 || response.data == null) {
      return const _GoalInputsResult(
        items: <MonthlyReportGoalInput>[],
        dataAvailable: false,
      );
    }
    final data = response.data as Map<String, dynamic>;
    final rows = data['goals'] as List<dynamic>? ?? const [];
    final items = rows
        .whereType<Map<String, dynamic>>()
        .map(Goal.fromJson)
        .where((goal) => goal.isActive && !goal.privacyRedacted)
        .map((goal) => _goalInput(goal, currencyCode))
        .whereType<MonthlyReportGoalInput>()
        .toList(growable: false);
    return _GoalInputsResult(items: items, dataAvailable: true);
  } catch (_) {
    return const _GoalInputsResult(
      items: <MonthlyReportGoalInput>[],
      dataAvailable: false,
    );
  }
}

class _GoalInputsResult {
  const _GoalInputsResult({
    required this.items,
    required this.dataAvailable,
  });

  final List<MonthlyReportGoalInput> items;
  final bool dataAvailable;
}

MonthlyReportGoalInput? _goalInput(Goal goal, String currencyCode) {
  final selectedCurrency = currencyCode.toUpperCase();
  final goalCurrency = goal.currency.toUpperCase();
  final baseCurrency = goal.baseCurrency?.toUpperCase();
  final useNormalized = baseCurrency == selectedCurrency &&
      goal.normalizedTargetAmount != null &&
      goal.normalizedCurrentAmount != null;
  if (!useNormalized && goalCurrency != selectedCurrency) return null;

  return MonthlyReportGoalInput(
    title: goal.title,
    targetAmount:
        useNormalized ? goal.normalizedTargetAmount! : goal.targetAmount,
    currentAmount:
        useNormalized ? goal.normalizedCurrentAmount! : goal.currentAmount,
    currencyCode: selectedCurrency,
    targetDate: goal.targetDate,
    isOnTrack: goal.isOnTrack,
  );
}

List<ExpenseEntry> _futureTransactionsForReport({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime now,
  required DateTime monthEnd,
  required String currencyCode,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final actualFuture = actualTransactions.where((entry) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    return day.isAfter(today) && !day.isAfter(monthEnd);
  }).toList(growable: false);
  final projected = projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions,
    rangeStart: today.add(const Duration(days: 1)),
    rangeEnd: monthEnd,
    selectedCurrency: currencyCode,
  );
  final dedupedProjected = dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projected,
    actualExpenses: actualFuture,
  );

  return <ExpenseEntry>[...actualFuture, ...dedupedProjected]
    ..sort((a, b) => a.date.compareTo(b.date));
}

List<MonthlyReportRecurringInput> _recurringItemsForReport(
  List<RecurringTransaction> recurringTransactions, {
  required List<ExpenseEntry> previousTransactions,
  required DateTime now,
  required DateTime monthStart,
  required DateTime monthEnd,
  required String currencyCode,
}) {
  final nowDay = DateTime(now.year, now.month, now.day);
  return recurringTransactions.where((item) {
    return item.isActive &&
        item.currency.toUpperCase() == currencyCode.toUpperCase();
  }).map((item) {
    final nextDate = item
        .getNextOccurrence(nowDay.subtract(const Duration(microseconds: 1)));
    return MonthlyReportRecurringInput(
      id: item.id,
      name: _recurringName(item),
      amount: item.amount.abs(),
      type: item.type,
      currencyCode: item.currency.toUpperCase(),
      nextDate: nextDate,
      previousAmount: _previousAmountForRecurring(item, previousTransactions),
    );
  }).where((item) {
    final day =
        DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
    return !day.isBefore(nowDay) &&
        !day.isBefore(monthStart) &&
        !day.isAfter(monthEnd);
  }).toList(growable: false);
}

List<MonthlyReportBudgetInput> _budgetInputs(List<PocketEnvelope> pockets) {
  return pockets
      .map(
        (pocket) => MonthlyReportBudgetInput(
          name: pocket.name,
          budgetAmount: pocket.budgetAmountCents / 100.0,
          spent: pocket.spent,
        ),
      )
      .toList(growable: false);
}

MonthlyReportTransactionInput _transactionInput(ExpenseEntry entry) {
  return MonthlyReportTransactionInput(
    id: entry.id,
    date: entry.date,
    amount: entry.amount.abs(),
    type: (entry.type ?? 'expense').toLowerCase(),
    category: (entry.category?.trim().isNotEmpty == true)
        ? entry.category!.trim()
        : 'Uncategorized',
    merchant: entry.merchant?.trim().isNotEmpty == true
        ? entry.merchant!.trim()
        : entry.rawText,
    currencyCode: (entry.currency ?? '').toUpperCase(),
  );
}

String _recurringName(RecurringTransaction item) {
  final merchant = item.merchant?.trim();
  if (merchant != null && merchant.isNotEmpty) return merchant;
  final description = item.description?.trim();
  if (description != null && description.isNotEmpty) return description;
  final source = item.source?.trim();
  if (source != null && source.isNotEmpty) return source;
  return item.category;
}

double? _previousAmountForRecurring(
  RecurringTransaction item,
  List<ExpenseEntry> previousTransactions,
) {
  final recurringName = _normalizeRecurringMatch(_recurringName(item));
  final category = _normalizeRecurringMatch(item.category);
  final matches = previousTransactions.where((tx) {
    if ((tx.type ?? 'expense').toLowerCase() != item.type.toLowerCase()) {
      return false;
    }
    final merchant = _normalizeRecurringMatch(tx.merchant ?? tx.rawText ?? '');
    final txCategory = _normalizeRecurringMatch(tx.category ?? '');
    return merchant == recurringName || txCategory == category;
  }).toList(growable: false)
    ..sort((a, b) => b.date.compareTo(a.date));
  if (matches.isEmpty) return null;
  return matches.first.amount.abs();
}

String _normalizeRecurringMatch(String value) => value.trim().toLowerCase();
