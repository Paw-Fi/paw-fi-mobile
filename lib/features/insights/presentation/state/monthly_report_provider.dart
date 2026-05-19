import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
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

enum MonthlyReportRange {
  week('week'),
  month('month'),
  sixMonths('6m'),
  year('year');

  const MonthlyReportRange(this.key);

  final String key;

  static MonthlyReportRange fromKey(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'week':
        return MonthlyReportRange.week;
      case '6m':
      case 'six_months':
      case 'sixmonths':
        return MonthlyReportRange.sixMonths;
      case 'year':
        return MonthlyReportRange.year;
      case 'month':
      default:
        return MonthlyReportRange.month;
    }
  }
}

class MonthlyReportQuery {
  const MonthlyReportQuery({
    required this.monthStart,
    this.range = MonthlyReportRange.month,
  });

  final DateTime monthStart;
  final MonthlyReportRange range;

  MonthlyReportQuery normalized() => MonthlyReportQuery(
        monthStart: DateTime(monthStart.year, monthStart.month),
        range: range,
      );

  String get monthKey =>
      '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MonthlyReportQuery &&
            other.range == range &&
            other.monthStart.year == monthStart.year &&
            other.monthStart.month == monthStart.month;
  }

  @override
  int get hashCode => Object.hash(monthStart.year, monthStart.month, range);
}

class MonthlyReportPeriod {
  const MonthlyReportPeriod({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
    required this.historicalStart,
    required this.compareMonthToDate,
  });

  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;
  final DateTime historicalStart;
  final bool compareMonthToDate;
}

class MonthlyFinancialReportSnapshot {
  const MonthlyFinancialReportSnapshot({
    required this.report,
    required this.lastSyncedAt,
    this.sourceTransactions = const <ExpenseEntry>[],
    this.isRefreshing = false,
  });

  final MonthlyFinancialReport report;
  final DateTime? lastSyncedAt;
  final List<ExpenseEntry> sourceTransactions;
  final bool isRefreshing;

  MonthlyFinancialReportSnapshot copyWith({
    MonthlyFinancialReport? report,
    DateTime? lastSyncedAt,
    List<ExpenseEntry>? sourceTransactions,
    bool? isRefreshing,
  }) {
    return MonthlyFinancialReportSnapshot(
      report: report ?? this.report,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      sourceTransactions: sourceTransactions ?? this.sourceTransactions,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class MonthlyReportNotifier extends FamilyAsyncNotifier<
    MonthlyFinancialReportSnapshot, MonthlyReportQuery> {
  late MonthlyReportQuery _query;

  @override
  Future<MonthlyFinancialReportSnapshot> build(MonthlyReportQuery arg) async {
    _query = arg.normalized();
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final userId = user.uid;
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final appLocale = resolveSupportedAppLocale(ref.watch(localeProvider));
    final l10n = lookupAppLocalizations(appLocale);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = _query.monthStart;
    final period = _monthlyReportPeriod(_query, now: now);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);
    final cacheKey = _monthlyReportCacheKey(
      userId: userId,
      scope: householdScope.activeAccountType.name,
      householdId: householdId,
      monthStart: monthStart,
      range: _query.range,
      periodStart: period.start,
      periodEnd: period.end,
      currencyCode: currencyCode,
      localeTag: appLocale.toLanguageTag(),
    );

    if (preview.isActive) {
      return _buildPreviewSnapshot(
        query: _query,
        period: period,
        now: now,
        currencyCode: currencyCode,
        l10n: l10n,
        householdScope: householdScope,
      );
    }

    if (userId.isEmpty) {
      return MonthlyFinancialReportSnapshot(
        lastSyncedAt: null,
        report: buildMonthlyFinancialReport(
          MonthlyReportInput(
            monthStart: monthStart,
            periodStart: period.start,
            periodEnd: period.end,
            compareMonthToDate: period.compareMonthToDate,
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
            period: period,
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
      period: period,
      pocketsScope: pocketsScope,
      cacheKey: cacheKey,
      l10n: l10n,
      publish: false,
      watchDependencies: true,
    );
  }

  Future<void> refreshReport() async {
    if (ref.read(previewModeProvider).isActive) {
      final context = _currentReportContext();
      final snapshot = _buildPreviewSnapshot(
        query: _query,
        period: context.period,
        now: context.now,
        currencyCode: context.currencyCode,
        l10n: context.l10n,
        householdScope: ref.read(householdScopeProvider),
      );
      state = AsyncData(snapshot);
      return;
    }
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
        period: context.period,
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
    final monthStart = _query.monthStart;
    final period = _monthlyReportPeriod(_query, now: now);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);
    return _MonthlyReportContext(
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      now: now,
      monthStart: monthStart,
      period: period,
      pocketsScope: pocketsScope,
      cacheKey: _monthlyReportCacheKey(
        userId: userId,
        scope: householdScope.activeAccountType.name,
        householdId: householdId,
        monthStart: monthStart,
        range: _query.range,
        periodStart: period.start,
        periodEnd: period.end,
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
    required MonthlyReportPeriod period,
    required PocketsScopeType pocketsScope,
    required String cacheKey,
    required AppLocalizations l10n,
    required bool publish,
    required bool watchDependencies,
  }) async {
    final selectedCurrencies = watchDependencies
        ? ref.watch(
            homeFilterProvider
                .select((state) => state.normalizedSelectedCurrencies),
          )
        : ref.read(homeFilterProvider).normalizedSelectedCurrencies;
    final currentQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      startDate: period.start,
      endDate: period.end,
    );
    final previousQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      startDate: period.previousStart,
      endDate: period.previousEnd,
    );
    final historicalQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      startDate: period.historicalStart,
      endDate: period.previousEnd,
    );

    final currentProvider = dashboardCalendarTransactionsProvider(currentQuery);
    final previousProvider =
        dashboardCalendarTransactionsProvider(previousQuery);
    final historicalProvider =
        dashboardCalendarTransactionsProvider(historicalQuery);
    final currentBase = await ref.read(currentProvider.future);
    final previousBase = await ref.read(previousProvider.future);
    final historicalBase = await ref.read(historicalProvider.future);
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
          ? ref
              .watch(dashboardLocalOverlayTransactionsProvider(historicalQuery))
          : ref
              .read(dashboardLocalOverlayTransactionsProvider(historicalQuery)),
      query: historicalQuery,
    );
    final shouldConvertCurrencies = (selectedCurrencies?.length ?? 0) > 1;
    final rateTable = watchDependencies
        ? ref.watch(currencyRateTableProvider).valueOrNull
        : ref.read(currencyRateTableProvider).valueOrNull;
    final rates = rateTable ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final reportCurrentTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            currentTransactions,
            targetCurrency: currencyCode,
            rates: rates,
          )
        : currentTransactions;
    final reportPreviousTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            previousTransactions,
            targetCurrency: currencyCode,
            rates: rates,
          )
        : previousTransactions;
    final reportHistoricalTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            historicalTransactions,
            targetCurrency: currencyCode,
            rates: rates,
          )
        : historicalTransactions;

    final recurringTransactions = await _loadRecurringTransactions(
      ref,
      userId: userId,
      householdId: householdId,
      watchDependencies: watchDependencies,
    );
    final futureTransactions = _futureTransactionsForReport(
      actualTransactions: reportCurrentTransactions,
      recurringTransactions: recurringTransactions,
      now: now,
      monthEnd: period.end,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      rates: rates,
    );
    final recurringItems = _recurringItemsForReport(
      recurringTransactions,
      previousTransactions: reportPreviousTransactions,
      now: now,
      monthStart: monthStart,
      monthEnd: period.end,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      rates: rates,
    );

    final pocketsParams = PocketsScopeParams(
      scope: pocketsScope,
      householdId: householdId,
      periodMonth: monthStart,
      currency: currencyCode,
      selectedCurrencies: selectedCurrencies,
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
        periodStart: period.start,
        periodEnd: period.end,
        compareMonthToDate: period.compareMonthToDate,
        now: now,
        currencyCode: currencyCode,
        currentBalance: walletSnapshot.netWorthCents / 100.0,
        currentMonthTransactions: reportCurrentTransactions
            .map(_transactionInput)
            .toList(growable: false),
        previousMonthTransactions: reportPreviousTransactions
            .map(_transactionInput)
            .toList(growable: false),
        historicalTransactions: reportHistoricalTransactions
            .map(_transactionInput)
            .toList(growable: false),
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
      sourceTransactions: _dedupeSourceTransactions([
        ...currentTransactions,
        ...previousTransactions,
        ...historicalTransactions,
        ...futureTransactions,
      ]),
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
        sourceTransactions: _list(entry.payload['source_transactions'])
            .map(ExpenseEntry.fromJson)
            .toList(growable: false),
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
        payload: {
          ..._monthlyReportToJson(snapshot.report),
          'source_transactions': snapshot.sourceTransactions
              .map((item) => item.toJson())
              .toList(growable: false),
        },
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
    required this.period,
    required this.pocketsScope,
    required this.cacheKey,
    required this.l10n,
  });

  final String userId;
  final String? householdId;
  final String currencyCode;
  final DateTime now;
  final DateTime monthStart;
  final MonthlyReportPeriod period;
  final PocketsScopeType pocketsScope;
  final String cacheKey;
  final AppLocalizations l10n;
}

final monthlyFinancialReportProvider = AsyncNotifierProvider.family<
    MonthlyReportNotifier, MonthlyFinancialReportSnapshot, MonthlyReportQuery>(
  MonthlyReportNotifier.new,
);

String _monthlyReportCacheKey({
  required String userId,
  required String scope,
  required String? householdId,
  required DateTime monthStart,
  required MonthlyReportRange range,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String currencyCode,
  required String localeTag,
}) {
  final month =
      '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';
  final start =
      '${periodStart.year.toString().padLeft(4, '0')}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}';
  final end =
      '${periodEnd.year.toString().padLeft(4, '0')}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}';
  return 'monthly-report:v2:$userId:$scope:${householdId ?? 'personal'}:$month:${range.key}:$start:$end:${currencyCode.toUpperCase()}:$localeTag';
}

MonthlyReportPeriod _monthlyReportPeriod(
  MonthlyReportQuery query, {
  required DateTime now,
}) {
  final monthStart = DateTime(query.monthStart.year, query.monthStart.month);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
  final today = DateTime(now.year, now.month, now.day);

  switch (query.range) {
    case MonthlyReportRange.week:
      final effectiveDay = today.isBefore(monthStart) || today.isAfter(monthEnd)
          ? monthStart
          : today;
      final rawStart =
          effectiveDay.subtract(Duration(days: effectiveDay.weekday - 1));
      final start = rawStart.isBefore(monthStart) ? monthStart : rawStart;
      final rawEnd = start.add(const Duration(days: 6));
      final end = rawEnd.isAfter(monthEnd) ? monthEnd : rawEnd;
      final previousStart = start.subtract(const Duration(days: 7));
      final previousEnd = end.subtract(const Duration(days: 7));
      return MonthlyReportPeriod(
        start: start,
        end: end,
        previousStart: previousStart,
        previousEnd: previousEnd,
        historicalStart: DateTime(start.year, start.month - 6, start.day),
        compareMonthToDate: false,
      );
    case MonthlyReportRange.month:
      return MonthlyReportPeriod(
        start: monthStart,
        end: monthEnd,
        previousStart: DateTime(monthStart.year, monthStart.month - 1),
        previousEnd: DateTime(monthStart.year, monthStart.month, 0),
        historicalStart: DateTime(monthStart.year, monthStart.month - 6),
        compareMonthToDate: true,
      );
    case MonthlyReportRange.sixMonths:
      final start = DateTime(monthStart.year, monthStart.month - 5);
      final previousStart = DateTime(start.year, start.month - 6);
      final previousEnd = start.subtract(const Duration(days: 1));
      return MonthlyReportPeriod(
        start: start,
        end: monthEnd,
        previousStart: previousStart,
        previousEnd: previousEnd,
        historicalStart: DateTime(start.year, start.month - 6),
        compareMonthToDate: false,
      );
    case MonthlyReportRange.year:
      final start = DateTime(monthStart.year, monthStart.month - 11);
      final previousStart = DateTime(start.year, start.month - 12);
      final previousEnd = start.subtract(const Duration(days: 1));
      return MonthlyReportPeriod(
        start: start,
        end: monthEnd,
        previousStart: previousStart,
        previousEnd: previousEnd,
        historicalStart: DateTime(start.year, start.month - 12),
        compareMonthToDate: false,
      );
  }
}

MonthlyFinancialReportSnapshot _buildPreviewSnapshot({
  required MonthlyReportQuery query,
  required MonthlyReportPeriod period,
  required DateTime now,
  required String currencyCode,
  required AppLocalizations l10n,
  required HouseholdScope householdScope,
}) {
  final baseEntries = _previewBaseExpenses(
    householdScope: householdScope,
    currencyCode: currencyCode,
  );
  final previewEntries = _expandPreviewExpenses(
    baseEntries: baseEntries,
    monthStart: query.monthStart,
  );
  final currentTransactions =
      _filterEntriesInRange(previewEntries, period.start, period.end);
  final previousTransactions = _filterEntriesInRange(
    previewEntries,
    period.previousStart,
    period.previousEnd,
  );
  final historicalTransactions = _filterEntriesInRange(
    previewEntries,
    period.historicalStart,
    period.previousEnd,
  );
  final budgetInputs = _previewBudgetInputs(householdScope, currencyCode);
  final recurringTransactions = _previewRecurringTransactions(
    householdScope: householdScope,
    currencyCode: currencyCode,
  );
  const previewRates = CurrencyRateTable(
    baseCurrency: 'USD',
    rates: CurrencyRates.rates,
    isStale: true,
  );
  final futureTransactions = _futureTransactionsForReport(
    actualTransactions: currentTransactions,
    recurringTransactions: recurringTransactions,
    now: now,
    monthEnd: period.end,
    currencyCode: currencyCode,
    rates: previewRates,
  );
  final recurringItems = _recurringItemsForReport(
    recurringTransactions,
    previousTransactions: previousTransactions,
    now: now,
    monthStart: query.monthStart,
    monthEnd: period.end,
    currencyCode: currencyCode,
    rates: previewRates,
  );
  final currentBalance = _previewCurrentBalance(householdScope: householdScope);
  final previousNetWorth = _previewPreviousNetWorth(
    currentBalance: currentBalance,
    currentTransactions: currentTransactions,
  );
  final report = buildMonthlyFinancialReport(
    MonthlyReportInput(
      monthStart: query.monthStart,
      periodStart: period.start,
      periodEnd: period.end,
      compareMonthToDate: period.compareMonthToDate,
      now: now,
      currencyCode: currencyCode,
      currentBalance: currentBalance,
      currentMonthTransactions:
          currentTransactions.map(_transactionInput).toList(growable: false),
      previousMonthTransactions:
          previousTransactions.map(_transactionInput).toList(growable: false),
      historicalTransactions:
          historicalTransactions.map(_transactionInput).toList(growable: false),
      budgetItems: budgetInputs,
      futureTransactions:
          futureTransactions.map(_transactionInput).toList(growable: false),
      recurringItems: recurringItems,
      goals: _previewGoalInputs(currencyCode, now),
      previousNetWorth: previousNetWorth,
      goalsDataAvailable: true,
    ),
    l10n: l10n,
  );
  final sourceTransactions = _dedupeSourceTransactions([
    ...currentTransactions,
    ...previousTransactions,
    ...historicalTransactions,
    ...futureTransactions,
  ]);
  return MonthlyFinancialReportSnapshot(
    report: report,
    lastSyncedAt: now.subtract(const Duration(minutes: 6)),
    sourceTransactions: sourceTransactions,
    isRefreshing: false,
  );
}

List<ExpenseEntry> _previewBaseExpenses({
  required HouseholdScope householdScope,
  required String currencyCode,
}) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  List<ExpenseEntry> scoped = PreviewMockData.expenses.where((entry) {
    final matchesCurrency = normalizedCurrency.isEmpty ||
        (entry.currency ?? '').trim().toUpperCase() == normalizedCurrency;
    if (!matchesCurrency) return false;
    return _matchesPreviewScope(entry, householdScope);
  }).toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  scoped = PreviewMockData.expenses
      .where((entry) => _matchesPreviewScope(entry, householdScope))
      .toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  scoped = PreviewMockData.expenses.where((entry) {
    if (normalizedCurrency.isEmpty) return true;
    return (entry.currency ?? '').trim().toUpperCase() == normalizedCurrency;
  }).toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  return PreviewMockData.expenses
      .map((entry) => entry.copyWith())
      .toList(growable: false);
}

List<ExpenseEntry> _expandPreviewExpenses({
  required List<ExpenseEntry> baseEntries,
  required DateTime monthStart,
}) {
  final normalizedMonth = DateTime(monthStart.year, monthStart.month, 1);
  const maxMonthOffsets = 11;
  final expanded = <ExpenseEntry>[];

  for (var offset = 0; offset <= maxMonthOffsets; offset++) {
    final targetMonth =
        DateTime(normalizedMonth.year, normalizedMonth.month - offset, 1);
    final tag =
        '${targetMonth.year}${targetMonth.month.toString().padLeft(2, '0')}';
    expanded.addAll(
      baseEntries.map((entry) {
        final adjustedDate =
            _previewDateForMonth(entry.date, targetMonth, offset);
        final scaledAmount = _scalePreviewAmount(entry.amountCents, offset);
        return entry.copyWith(
          id: 'preview-$tag-${entry.id}',
          date: adjustedDate,
          createdAt: adjustedDate.subtract(const Duration(hours: 2)),
          updatedAt: null,
          amountCents: scaledAmount,
        );
      }),
    );
  }

  return expanded;
}

DateTime _previewDateForMonth(
  DateTime source,
  DateTime monthStart,
  int offset,
) {
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  final shift = offset * 3;
  var day = ((source.day + shift) % daysInMonth);
  if (day <= 0) {
    day += daysInMonth;
  }
  return DateTime(
    monthStart.year,
    monthStart.month,
    day,
    source.hour,
    source.minute,
    source.second,
  );
}

int _scalePreviewAmount(int amountCents, int offset) {
  final scale = 1 - (offset * 0.05);
  final scaled = (amountCents * scale).round();
  return scaled <= 0 ? 1 : scaled;
}

List<RecurringTransaction> _previewRecurringTransactions({
  required HouseholdScope householdScope,
  required String currencyCode,
}) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  List<RecurringTransaction> scoped =
      PreviewMockData.recurringTransactions.where((transaction) {
    final matchesCurrency = normalizedCurrency.isEmpty ||
        transaction.currency.trim().toUpperCase() == normalizedCurrency;
    if (!matchesCurrency) return false;
    return _matchesRecurringScope(transaction, householdScope);
  }).toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  scoped = PreviewMockData.recurringTransactions
      .where(
          (transaction) => _matchesRecurringScope(transaction, householdScope))
      .toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  scoped = PreviewMockData.recurringTransactions.where((transaction) {
    if (normalizedCurrency.isEmpty) return true;
    return transaction.currency.trim().toUpperCase() == normalizedCurrency;
  }).toList(growable: false);
  if (scoped.isNotEmpty) {
    return scoped;
  }
  return PreviewMockData.recurringTransactions
      .map(_copyPreviewRecurring)
      .toList(growable: false);
}

bool _matchesRecurringScope(
  RecurringTransaction transaction,
  HouseholdScope scope,
) {
  final transactionHouseholdId = transaction.householdId?.trim();
  final targetHouseholdId = _reportHouseholdId(scope);
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return transactionHouseholdId == null || transactionHouseholdId.isEmpty;
    case ActiveWalletType.portfolio:
    case ActiveWalletType.household:
      if (targetHouseholdId == null || targetHouseholdId.isEmpty) {
        return transactionHouseholdId == null || transactionHouseholdId.isEmpty;
      }
      return transactionHouseholdId == targetHouseholdId;
  }
}

RecurringTransaction _copyPreviewRecurring(RecurringTransaction transaction) {
  return RecurringTransaction(
    id: transaction.id,
    userId: transaction.userId,
    date: transaction.date,
    category: transaction.category,
    description: transaction.description,
    source: transaction.source,
    merchant: transaction.merchant,
    amount: transaction.amount,
    currency: transaction.currency,
    ownerType: transaction.ownerType,
    privacyScope: transaction.privacyScope,
    householdId: transaction.householdId,
    payerUserId: transaction.payerUserId,
    splitGroupId: transaction.splitGroupId,
    accountId: transaction.accountId,
    recurrenceRule: transaction.recurrenceRule,
    type: transaction.type,
    attachments: transaction.attachments,
    createdAt: transaction.createdAt,
    updatedAt: transaction.updatedAt,
  );
}

List<ExpenseEntry> _filterEntriesInRange(
  List<ExpenseEntry> entries,
  DateTime start,
  DateTime end,
) {
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  return entries.where((entry) {
    final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }).toList(growable: false);
}

bool _matchesPreviewScope(ExpenseEntry entry, HouseholdScope scope) {
  final entryHouseholdId = entry.householdId?.trim();
  final targetHouseholdId = _reportHouseholdId(scope);
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return entryHouseholdId == null || entryHouseholdId.isEmpty;
    case ActiveWalletType.portfolio:
    case ActiveWalletType.household:
      if (targetHouseholdId == null || targetHouseholdId.isEmpty) {
        return entryHouseholdId == null || entryHouseholdId.isEmpty;
      }
      return entryHouseholdId == targetHouseholdId;
  }
}

List<MonthlyReportBudgetInput> _previewBudgetInputs(
  HouseholdScope scope,
  String currencyCode,
) {
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  final pockets = PreviewMockData.pockets.where((pocket) {
    if (normalizedCurrency.isEmpty) return true;
    return pocket.currency.trim().toUpperCase() == normalizedCurrency;
  }).toList(growable: false);
  Iterable<PocketEnvelope> scoped = switch (scope.activeAccountType) {
    ActiveWalletType.personal => pockets,
    ActiveWalletType.portfolio => pockets.where(
        (pocket) => pocket.householdId == _reportHouseholdId(scope),
      ),
    ActiveWalletType.household => pockets.where(
        (pocket) => pocket.householdId == _reportHouseholdId(scope),
      ),
  };
  final resolved = scoped.isEmpty ? pockets : scoped;
  return resolved
      .map(
        (pocket) => MonthlyReportBudgetInput(
          name: pocket.name,
          budgetAmount: pocket.budgetAmountCents / 100.0,
          spent: pocket.spent,
        ),
      )
      .toList(growable: false);
}

List<MonthlyReportGoalInput> _previewGoalInputs(
  String currencyCode,
  DateTime now,
) {
  final futureA = DateTime(now.year, now.month + 6, 1);
  final futureB = DateTime(now.year, now.month + 10, 1);
  final futureC = DateTime(now.year, now.month + 4, 1);
  final normalizedCurrency = currencyCode.trim().toUpperCase();
  return [
    MonthlyReportGoalInput(
      id: 'preview-goal-1',
      title: 'Emergency buffer',
      targetAmount: 6000,
      currentAmount: 2400,
      currencyCode: normalizedCurrency,
      targetDate: futureA.toIso8601String(),
      isOnTrack: true,
    ),
    MonthlyReportGoalInput(
      id: 'preview-goal-2',
      title: 'Japan trip',
      targetAmount: 3200,
      currentAmount: 1100,
      currencyCode: normalizedCurrency,
      targetDate: futureB.toIso8601String(),
      isOnTrack: false,
    ),
    MonthlyReportGoalInput(
      id: 'preview-goal-3',
      title: 'Car maintenance',
      targetAmount: 1200,
      currentAmount: 650,
      currencyCode: normalizedCurrency,
      targetDate: futureC.toIso8601String(),
      isOnTrack: true,
    ),
  ];
}

double _previewCurrentBalance({required HouseholdScope householdScope}) {
  final wallets = PreviewMockData.wallets;
  final targetHouseholdId = _reportHouseholdId(householdScope);
  final scoped = switch (householdScope.activeAccountType) {
    ActiveWalletType.personal => wallets.where(
        (wallet) => wallet.householdId == null || wallet.householdId!.isEmpty,
      ),
    ActiveWalletType.portfolio => wallets.where(
        (wallet) => wallet.householdId == targetHouseholdId,
      ),
    ActiveWalletType.household => wallets.where(
        (wallet) => wallet.householdId == targetHouseholdId,
      ),
  };
  final resolved = scoped.isEmpty ? wallets : scoped;
  final totalCents = resolved.fold<int>(
    0,
    (sum, wallet) => sum + wallet.currentBalanceCents,
  );
  return totalCents == 0 ? 2850 : totalCents / 100.0;
}

double _previewPreviousNetWorth({
  required double currentBalance,
  required List<ExpenseEntry> currentTransactions,
}) {
  final income = currentTransactions
      .where((entry) => (entry.type ?? 'expense').toLowerCase() == 'income')
      .fold<double>(0, (sum, entry) => sum + entry.amount.abs());
  final spending = currentTransactions
      .where((entry) => (entry.type ?? 'expense').toLowerCase() != 'income')
      .fold<double>(0, (sum, entry) => sum + entry.amount.abs());
  final netCashFlow = income - spending;
  if (netCashFlow == 0) {
    return currentBalance - 450;
  }
  return currentBalance - netCashFlow;
}

List<ExpenseEntry> _dedupeSourceTransactions(Iterable<ExpenseEntry> entries) {
  final seen = <String>{};
  final result = <ExpenseEntry>[];
  for (final entry in entries) {
    if (entry.id.isEmpty || !seen.add(entry.id)) continue;
    result.add(entry);
  }
  return result..sort((a, b) => b.date.compareTo(a.date));
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
              'source_transaction_ids': item.sourceTransactionIds,
            })
        .toList(growable: false),
    'budget_health': report.budgetHealth
        .map((item) => {
              'name': item.name,
              'status': item.status.name,
              'budget_amount': item.budgetAmount,
              'spent': item.spent,
              'remaining': item.remaining,
              'source_transaction_ids': item.sourceTransactionIds,
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
                'recurring_id': item.recurringId,
              })
          .toList(growable: false),
    },
    'upcoming_obligations': report.upcomingObligations
        .map((item) => {
              'date': item.date.toIso8601String(),
              'name': item.name,
              'amount': item.amount,
              'type': item.type,
              'source_transaction_id': item.sourceTransactionId,
              'recurring_id': item.recurringId,
            })
        .toList(growable: false),
    'cash_flow_forecast': report.cashFlowForecast
        .map((item) => {
              'label': item.label,
              'balance': item.balance,
              'source_transaction_id': item.sourceTransactionId,
            })
        .toList(growable: false),
    'goals': report.goals
        .map((item) => {
              'id': item.id,
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
              'source_transaction_ids': item.sourceTransactionIds,
            })
        .toList(growable: false),
    'merchant_concentration': report.merchantConcentration
        .map((item) => {
              'name': item.name,
              'amount': item.amount,
              'transaction_count': item.transactionCount,
              'spending_share': item.spendingShare,
              'source_transaction_ids': item.sourceTransactionIds,
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
    'source_transaction_ids': item.sourceTransactionIds,
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
              sourceTransactionIds: _stringList(item['source_transaction_ids']),
            ))
        .toList(growable: false),
    budgetHealth: _list(json['budget_health'])
        .map((item) => MonthlyBudgetHealthItem(
              name: item['name'] as String? ?? '',
              status: _monthlyReportStatus(item['status']),
              budgetAmount: _num(json: item, key: 'budget_amount'),
              spent: _num(json: item, key: 'spent'),
              remaining: _num(json: item, key: 'remaining'),
              sourceTransactionIds: _stringList(item['source_transaction_ids']),
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
                recurringId: item['recurring_id'] as String?,
              ))
          .toList(growable: false),
    ),
    upcomingObligations: _list(json['upcoming_obligations'])
        .map((item) => MonthlyCashFlowItem(
              date: DateTime.parse(item['date'] as String),
              name: item['name'] as String? ?? '',
              amount: _num(json: item, key: 'amount'),
              type: item['type'] as String? ?? 'expense',
              sourceTransactionId: item['source_transaction_id'] as String?,
              recurringId: item['recurring_id'] as String?,
            ))
        .toList(growable: false),
    cashFlowForecast: _list(json['cash_flow_forecast'])
        .map((item) => MonthlyCashFlowPoint(
              label: item['label'] as String? ?? '',
              balance: _num(json: item, key: 'balance'),
              sourceTransactionId: item['source_transaction_id'] as String?,
            ))
        .toList(growable: false),
    goals: _list(json['goals'])
        .map((item) => MonthlyGoalReportItem(
              id: item['id'] as String? ?? '',
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
              sourceTransactionIds: _stringList(item['source_transaction_ids']),
            ))
        .toList(growable: false),
    merchantConcentration: _list(json['merchant_concentration'])
        .map((item) => MonthlyMerchantSpendItem(
              name: item['name'] as String? ?? '',
              amount: _num(json: item, key: 'amount'),
              transactionCount: _int(json: item, key: 'transaction_count'),
              spendingShare: _num(json: item, key: 'spending_share'),
              sourceTransactionIds: _stringList(item['source_transaction_ids']),
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
    sourceTransactionIds: _stringList(json['source_transaction_ids']),
  );
}

List<String> _stringList(Object? value) {
  return ((value as List?) ?? const [])
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
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
    await ref.read(provider.notifier).loadRecurringTransactions(userId);
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
  return watchDependencies
      ? ref.read(provider.future)
      : ref.read(provider.future);
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
  final history = await ref.read(provider.future);
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
    id: goal.id,
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
  List<String>? selectedCurrencies,
  required CurrencyRateTable rates,
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
    selectedCurrencies: selectedCurrencies,
  );
  final dedupedProjected = dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projected,
    actualExpenses: actualFuture,
  );

  final convertedProjected = (selectedCurrencies?.length ?? 0) > 1
      ? convertTransactionsToCurrency(
          dedupedProjected,
          targetCurrency: currencyCode,
          rates: rates,
        )
      : dedupedProjected;

  return <ExpenseEntry>[...actualFuture, ...convertedProjected]
    ..sort((a, b) => a.date.compareTo(b.date));
}

List<MonthlyReportRecurringInput> _recurringItemsForReport(
  List<RecurringTransaction> recurringTransactions, {
  required List<ExpenseEntry> previousTransactions,
  required DateTime now,
  required DateTime monthStart,
  required DateTime monthEnd,
  required String currencyCode,
  List<String>? selectedCurrencies,
  required CurrencyRateTable rates,
}) {
  final nowDay = DateTime(now.year, now.month, now.day);
  final selectedCurrencySet = selectedCurrencies
      ?.map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet();
  final hasMultiCurrencySelection = (selectedCurrencySet?.length ?? 0) > 1;
  return recurringTransactions.where((item) {
    if (!item.isActive) return false;
    final itemCurrency = item.currency.trim().toUpperCase();
    if (selectedCurrencySet != null && selectedCurrencySet.isNotEmpty) {
      return selectedCurrencySet.contains(itemCurrency);
    }
    return itemCurrency == currencyCode.toUpperCase();
  }).map((item) {
    final nextDate = item
        .getNextOccurrence(nowDay.subtract(const Duration(microseconds: 1)));
    final itemCurrency = item.currency.trim().toUpperCase();
    final amount = hasMultiCurrencySelection
        ? rates.convert(item.amount.abs(), itemCurrency, currencyCode)
        : item.amount.abs();
    return MonthlyReportRecurringInput(
      id: item.id,
      name: _recurringName(item),
      amount: amount,
      type: item.type,
      currencyCode: hasMultiCurrencySelection ? currencyCode : itemCurrency,
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
