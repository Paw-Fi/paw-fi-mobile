import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

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
    this.financialMonthStartDay = 1,
    this.range = MonthlyReportRange.month,
  });

  final DateTime monthStart;
  final int financialMonthStartDay;
  final MonthlyReportRange range;

  MonthlyReportQuery normalized({int? financialMonthStartDay}) {
    final startDay = normalizeFinancialMonthStartDay(
      financialMonthStartDay ?? this.financialMonthStartDay,
    );
    return MonthlyReportQuery(
      monthStart: financialCycleStartForMonth(
        monthStart,
        startDay: startDay,
      ),
      financialMonthStartDay: startDay,
      range: range,
    );
  }

  String get monthKey => formatFinancialPeriodDate(monthStart);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MonthlyReportQuery &&
            other.range == range &&
            other.monthStart == monthStart &&
            other.financialMonthStartDay == financialMonthStartDay;
  }

  @override
  int get hashCode => Object.hash(monthStart, financialMonthStartDay, range);
}

MonthlyReportQuery shiftMonthlyReportQuery(
  MonthlyReportQuery query,
  int cycleDelta,
) {
  final normalized = query.normalized();
  return MonthlyReportQuery(
    monthStart: addFinancialCycles(
      normalized.monthStart,
      cycleDelta,
      startDay: normalized.financialMonthStartDay,
    ),
    financialMonthStartDay: normalized.financialMonthStartDay,
    range: normalized.range,
  );
}

List<MonthlyReportQuery> monthlyReportArchiveQueries({
  required MonthlyReportQuery currentQuery,
  int previousPeriodCount = 12,
}) {
  final normalized = currentQuery.normalized();
  return List<MonthlyReportQuery>.generate(
    previousPeriodCount + 1,
    (index) => shiftMonthlyReportQuery(normalized, -index),
    growable: false,
  );
}

bool isMonthlyReportPeriodCompleted(
  MonthlyReportQuery query, {
  required DateTime now,
}) {
  final period = resolveMonthlyReportPeriod(query.normalized(), now: now);
  final today = DateTime(now.year, now.month, now.day);
  return today.isAfter(period.end);
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
  int _refreshGeneration = 0;

  @override
  Future<MonthlyFinancialReportSnapshot> build(MonthlyReportQuery arg) async {
    final buildGeneration = ++_refreshGeneration;
    var disposed = false;
    ref.onDispose(() => disposed = true);
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
    _query = arg.normalized(financialMonthStartDay: financialMonthStartDay);
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final userId = user.uid;
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final selectedCurrencies = ref.watch(
      homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
    );
    final rawLocale = ref.watch(localeProvider);
    final appLocale = resolveSupportedAppLocale(rawLocale);
    final l10n = lookupAppLocalizations(appLocale);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final dashboardRefreshSignal = ref.watch(dashboardRefreshSignalProvider);
    final transactionsRefreshSignal =
        ref.watch(transactionsFeedRefreshSignalProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = _query.monthStart;
    final period = resolveMonthlyReportPeriod(_query, now: now);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);
    final cacheKey = _monthlyReportCacheKey(
      userId: userId,
      scope: householdScope.activeAccountType.name,
      householdId: householdId,
      monthStart: monthStart,
      financialMonthStartDay: _query.financialMonthStartDay,
      range: _query.range,
      periodStart: period.start,
      periodEnd: period.end,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
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
            financialMonthStartDay: _query.financialMonthStartDay,
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
          ),
          l10n: l10n,
        ),
      );
    }

    final cachedSnapshot = shouldReadMonthlyReportCache(
      dashboardRefreshSignal: dashboardRefreshSignal,
      transactionsRefreshSignal: transactionsRefreshSignal,
    )
        ? await _readCachedSnapshot(cacheKey)
        : null;
    if (cachedSnapshot != null) {
      unawaited(() async {
        try {
          final refreshed = await _refreshFromSources(
            userId: userId,
            householdId: householdId,
            currencyCode: currencyCode,
            now: now,
            monthStart: monthStart,
            period: period,
            pocketsScope: pocketsScope,
            cacheKey: cacheKey,
            l10n: l10n,
            watchDependencies: false,
          );
          if (!disposed && buildGeneration == _refreshGeneration) {
            state = AsyncData(refreshed);
          }
        } catch (_) {
          if (!disposed && buildGeneration == _refreshGeneration) {
            state = AsyncData(cachedSnapshot.copyWith(isRefreshing: false));
          }
        }
      }());
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
      watchDependencies: true,
    );
  }

  Future<void> refreshReport() async {
    final refreshGeneration = ++_refreshGeneration;
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
        watchDependencies: false,
      );
      if (refreshGeneration == _refreshGeneration) {
        state = AsyncData(refreshed);
      }
    } catch (error, stackTrace) {
      if (refreshGeneration != _refreshGeneration) return;
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
    final selectedCurrencies =
        ref.read(homeFilterProvider).normalizedSelectedCurrencies;
    final appLocale = resolveSupportedAppLocale(ref.read(localeProvider));
    final l10n = lookupAppLocalizations(appLocale);
    final preferredTimezone = ref.read(appPreferredTimezoneProvider);
    final householdScope = ref.read(householdScopeProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = _query.monthStart;
    final period = resolveMonthlyReportPeriod(_query, now: now);
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
        financialMonthStartDay: _query.financialMonthStartDay,
        range: _query.range,
        periodStart: period.start,
        periodEnd: period.end,
        currencyCode: currencyCode,
        selectedCurrencies: selectedCurrencies,
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
    required bool watchDependencies,
  }) async {
    final financialMonthStartDay = _query.financialMonthStartDay;
    final selectedCurrencies = watchDependencies
        ? ref.watch(
            homeFilterProvider
                .select((state) => state.normalizedSelectedCurrencies),
          )
        : ref.read(homeFilterProvider).normalizedSelectedCurrencies;
    final transactionsQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      startDate: period.historicalStart,
      endDate: period.end,
    );
    final transactionFeed = ref.read(transactionsFeedServiceProvider);
    final transactionsFuture = transactionFeed.fetchAllPages(
      dashboardTransactionsQuery(transactionsQuery, pageSize: 500),
    );
    final localOverlay = ref.read(
      dashboardLocalOverlayTransactionsProvider(transactionsQuery),
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
    final recurringTransactionsFuture = _loadRecurringTransactions(
      ref,
      userId: userId,
      householdId: householdId,
      watchDependencies: watchDependencies,
    );
    final pocketsParams = PocketsScopeParams(
      scope: pocketsScope,
      householdId: householdId,
      periodMonth: monthStart,
      currency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      financialMonthStartDay: financialMonthStartDay,
      includeUpcomingRecurring: false,
    );
    final pocketsState = watchDependencies
        ? ref.watch(pocketsProvider(pocketsParams))
        : ref.read(pocketsProvider(pocketsParams));
    final pocketsLoadFuture =
        pocketsState.isLoading && !pocketsState.hasDisplayData
            ? ref.read(pocketsProvider(pocketsParams).notifier).load()
            : Future<void>.value();
    final walletSnapshotFuture = _readWalletSnapshot(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      monthStart: monthStart,
      financialMonthStartDay: financialMonthStartDay,
      watchDependencies: watchDependencies,
    );
    final previousNetWorthFuture = _readPreviousNetWorth(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      monthStart: monthStart,
      financialMonthStartDay: financialMonthStartDay,
      watchDependencies: watchDependencies,
    );

    final sourceResults = await Future.wait<Object?>(
      <Future<Object?>>[
        transactionsFuture,
        recurringTransactionsFuture,
        pocketsLoadFuture.then<Object?>((_) => null),
        walletSnapshotFuture,
        previousNetWorthFuture,
      ],
      eagerError: false,
    );
    final transactionBase = sourceResults[0]! as List<ExpenseEntry>;
    final recurringTransactions =
        sourceResults[1]! as List<RecurringTransaction>;
    final walletSnapshot = sourceResults[3]! as WalletsMonthSnapshot;
    final previousNetWorth = sourceResults[4] as double?;
    final allTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionBase,
      localOverlay: localOverlay,
      query: transactionsQuery,
    );
    final transactionPeriods = _partitionMonthlyReportTransactions(
      allTransactions,
      period,
    );
    final currentTransactions = transactionPeriods.current;
    final previousTransactions = transactionPeriods.previous;
    final historicalTransactions = transactionPeriods.historical;
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
    final occurrenceResolution = watchDependencies
        ? ref.watch(recurringOccurrenceProjectionResolutionProvider(
            RecurringOccurrenceProjectionResolutionQuery(
              userId: userId,
              householdId: householdId,
              startDate: now.add(const Duration(days: 1)),
              endDate: period.end,
            ),
          ))
        : ref.read(recurringOccurrenceProjectionResolutionProvider(
            RecurringOccurrenceProjectionResolutionQuery(
              userId: userId,
              householdId: householdId,
              startDate: now.add(const Duration(days: 1)),
              endDate: period.end,
            ),
          ));

    final futureTransactionSets = _futureTransactionsForReport(
      actualTransactions: currentTransactions,
      recurringTransactions: recurringTransactions,
      now: now,
      monthEnd: period.end,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      rates: rates,
      confirmedOccurrenceSuppressionEntries:
          occurrenceResolution.suppressionEntries,
    );
    final futureTransactions = futureTransactionSets.report;
    final nativeFutureTransactionsById = <String, ExpenseEntry>{
      for (final transaction in futureTransactionSets.native)
        transaction.id: transaction,
    };
    final recurringItems = _recurringItemsForReport(
      recurringTransactions,
      previousTransactions: previousTransactions,
      now: now,
      currencyCode: currencyCode,
      selectedCurrencies: selectedCurrencies,
      rates: rates,
    );

    final loadedPocketsState = ref.read(pocketsProvider(pocketsParams));

    final report = buildMonthlyFinancialReport(
      MonthlyReportInput(
        monthStart: monthStart,
        periodStart: period.start,
        periodEnd: period.end,
        financialMonthStartDay: financialMonthStartDay,
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
        budgetItems: _budgetInputs(
          loadedPocketsState.editing,
          sourceError: loadedPocketsState.error,
          currencyCode: currencyCode,
          selectedCurrencies: selectedCurrencies,
          rates: rates,
          aggregateSpentByEnvelopeId:
              loadedPocketsState.aggregateSpentByEnvelopeId,
          transactions: reportCurrentTransactions,
          envelopeCategories: loadedPocketsState.envelopeCategories,
        ),
        futureTransactions: futureTransactions
            .map(
              (transaction) => _transactionInput(
                transaction,
                nativeEntry: nativeFutureTransactionsById[transaction.id],
              ),
            )
            .toList(growable: false),
        recurringItems: recurringItems,
        previousNetWorth: previousNetWorth,
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
      ]),
    );
    await _writeCachedSnapshot(cacheKey, snapshot);
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
  required int financialMonthStartDay,
  required MonthlyReportRange range,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String currencyCode,
  List<String>? selectedCurrencies,
  required String localeTag,
}) {
  final month = formatFinancialPeriodDate(monthStart);
  final start = formatFinancialPeriodDate(periodStart);
  final end = formatFinancialPeriodDate(periodEnd);
  return 'monthly-report:v8:$userId:$scope:${householdId ?? 'personal'}:$month:fmsd$financialMonthStartDay:${range.key}:$start:$end:${currencyCode.toUpperCase()}:${_currencySelectionCacheSegment(selectedCurrencies)}:$localeTag';
}

String _currencySelectionCacheSegment(List<String>? currencies) {
  final values = (currencies ?? const <String>[])
      .map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return values.isEmpty ? 'default' : values.join(',');
}

MonthlyReportPeriod resolveMonthlyReportPeriod(
  MonthlyReportQuery query, {
  required DateTime now,
}) {
  final financialMonthStartDay = query.financialMonthStartDay;
  final monthStart = financialCycleStartForDate(
    query.monthStart,
    startDay: financialMonthStartDay,
  );
  final monthEnd = nextFinancialCycleStart(
    monthStart,
    startDay: financialMonthStartDay,
  ).subtract(const Duration(days: 1));
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
        historicalStart: _addCalendarMonthsClamped(start, -6),
        compareMonthToDate: false,
      );
    case MonthlyReportRange.month:
      final isCurrentPeriod =
          !today.isBefore(monthStart) && !today.isAfter(monthEnd);
      return MonthlyReportPeriod(
        start: monthStart,
        end: monthEnd,
        previousStart: previousFinancialCycleStart(
          monthStart,
          startDay: financialMonthStartDay,
        ),
        previousEnd: monthStart.subtract(const Duration(days: 1)),
        historicalStart: addFinancialCycles(
          monthStart,
          -6,
          startDay: financialMonthStartDay,
        ),
        compareMonthToDate: isCurrentPeriod,
      );
    case MonthlyReportRange.sixMonths:
      final start = addFinancialCycles(
        monthStart,
        -5,
        startDay: financialMonthStartDay,
      );
      final previousStart = addFinancialCycles(
        start,
        -6,
        startDay: financialMonthStartDay,
      );
      final previousEnd = start.subtract(const Duration(days: 1));
      return MonthlyReportPeriod(
        start: start,
        end: monthEnd,
        previousStart: previousStart,
        previousEnd: previousEnd,
        historicalStart: addFinancialCycles(
          start,
          -6,
          startDay: financialMonthStartDay,
        ),
        compareMonthToDate: false,
      );
    case MonthlyReportRange.year:
      final start = addFinancialCycles(
        monthStart,
        -11,
        startDay: financialMonthStartDay,
      );
      final previousStart = addFinancialCycles(
        start,
        -12,
        startDay: financialMonthStartDay,
      );
      final previousEnd = start.subtract(const Duration(days: 1));
      return MonthlyReportPeriod(
        start: start,
        end: monthEnd,
        previousStart: previousStart,
        previousEnd: previousEnd,
        historicalStart: addFinancialCycles(
          start,
          -12,
          startDay: financialMonthStartDay,
        ),
        compareMonthToDate: false,
      );
  }
}

DateTime _addCalendarMonthsClamped(DateTime date, int months) {
  final firstOfTargetMonth = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(
    firstOfTargetMonth.year,
    firstOfTargetMonth.month + 1,
    0,
  ).day;
  return DateTime(
    firstOfTargetMonth.year,
    firstOfTargetMonth.month,
    math.min(date.day, lastDay),
  );
}

@foundation.visibleForTesting
MonthlyReportPeriod monthlyReportPeriodForTesting(
  MonthlyReportQuery query, {
  required DateTime now,
}) =>
    resolveMonthlyReportPeriod(query, now: now);

({
  List<ExpenseEntry> current,
  List<ExpenseEntry> previous,
  List<ExpenseEntry> historical,
}) _partitionMonthlyReportTransactions(
  List<ExpenseEntry> transactions,
  MonthlyReportPeriod period,
) {
  DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  bool isWithin(DateTime date, DateTime start, DateTime end) {
    final day = dateOnly(date);
    return !day.isBefore(dateOnly(start)) && !day.isAfter(dateOnly(end));
  }

  return (
    current: transactions
        .where((entry) => isWithin(entry.date, period.start, period.end))
        .toList(growable: false),
    previous: transactions
        .where(
          (entry) =>
              isWithin(entry.date, period.previousStart, period.previousEnd),
        )
        .toList(growable: false),
    historical: transactions
        .where(
          (entry) =>
              isWithin(entry.date, period.historicalStart, period.previousEnd),
        )
        .toList(growable: false),
  );
}

@foundation.visibleForTesting
({
  List<ExpenseEntry> current,
  List<ExpenseEntry> previous,
  List<ExpenseEntry> historical,
}) partitionMonthlyReportTransactionsForTesting(
  List<ExpenseEntry> transactions,
  MonthlyReportPeriod period,
) =>
    _partitionMonthlyReportTransactions(transactions, period);

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
  final futureTransactionSets = _futureTransactionsForReport(
    actualTransactions: currentTransactions,
    recurringTransactions: recurringTransactions,
    now: now,
    monthEnd: period.end,
    currencyCode: currencyCode,
    rates: previewRates,
  );
  final futureTransactions = futureTransactionSets.report;
  final nativeFutureTransactionsById = <String, ExpenseEntry>{
    for (final transaction in futureTransactionSets.native)
      transaction.id: transaction,
  };
  final recurringItems = _recurringItemsForReport(
    recurringTransactions,
    previousTransactions: previousTransactions,
    now: now,
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
      financialMonthStartDay: query.financialMonthStartDay,
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
      futureTransactions: futureTransactions
          .map(
            (transaction) => _transactionInput(
              transaction,
              nativeEntry: nativeFutureTransactionsById[transaction.id],
            ),
          )
          .toList(growable: false),
      recurringItems: recurringItems,
      previousNetWorth: previousNetWorth,
    ),
    l10n: l10n,
  );
  final sourceTransactions = _dedupeSourceTransactions([
    ...currentTransactions,
    ...previousTransactions,
    ...historicalTransactions,
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
                'monthly_amount': item.monthlyAmount,
                'currency_code': item.currencyCode,
                'aggregate_amount': item.aggregateAmount,
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
              'currency_code': item.currencyCode,
              'source_transaction_id': item.sourceTransactionId,
              'recurring_id': item.recurringId,
            })
        .toList(growable: false),
    'cash_flow_forecast': report.cashFlowForecast
        .map((item) => {
              'label': item.label,
              'balance': item.balance,
              'source_transaction_id': item.sourceTransactionId,
              'recurring_id': item.recurringId,
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
                monthlyAmount: _num(
                  json: item,
                  key: 'monthly_amount',
                ),
                currencyCode: item['currency_code'] as String? ??
                    json['currency_code'] as String? ??
                    'USD',
                aggregateAmount: _num(
                  json: item,
                  key: 'aggregate_amount',
                ),
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
              currencyCode: item['currency_code'] as String? ??
                  json['currency_code'] as String? ??
                  'USD',
              sourceTransactionId: item['source_transaction_id'] as String?,
              recurringId: item['recurring_id'] as String?,
            ))
        .toList(growable: false),
    cashFlowForecast: _list(json['cash_flow_forecast'])
        .map((item) => MonthlyCashFlowPoint(
              label: item['label'] as String? ?? '',
              balance: _num(json: item, key: 'balance'),
              sourceTransactionId: item['source_transaction_id'] as String?,
              recurringId: item['recurring_id'] as String?,
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
    summary: json['summary'] as String? ?? '',
  );
}

@foundation.visibleForTesting
MonthlyFinancialReport roundTripMonthlyReportForTesting(
  MonthlyFinancialReport report,
) =>
    _monthlyReportFromJson(_monthlyReportToJson(report));

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
  List<String>? selectedCurrencies,
  required DateTime monthStart,
  required int financialMonthStartDay,
  required bool watchDependencies,
}) async {
  final provider = walletsMonthSnapshotProvider(
    WalletsMonthQuery(
      scope: WalletsScopeQuery(
        userId: userId,
        householdId: householdId,
        selectedCurrency: currencyCode,
        selectedCurrencies: selectedCurrencies,
        currentMonthStart: monthStart,
        financialMonthStartDay: financialMonthStartDay,
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
  List<String>? selectedCurrencies,
  required DateTime monthStart,
  required int financialMonthStartDay,
  required bool watchDependencies,
}) async {
  final provider = walletsHistoryProvider(
    WalletsScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
      currentMonthStart: monthStart,
      financialMonthStartDay: financialMonthStartDay,
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

({List<ExpenseEntry> native, List<ExpenseEntry> report})
    _futureTransactionsForReport({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime now,
  required DateTime monthEnd,
  required String currencyCode,
  List<String>? selectedCurrencies,
  required CurrencyRateTable rates,
  Iterable<ExpenseEntry> confirmedOccurrenceSuppressionEntries =
      const <ExpenseEntry>[],
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
    actualExpenses: <ExpenseEntry>[
      ...actualFuture,
      ...confirmedOccurrenceSuppressionEntries,
    ],
  );

  final futureTransactions = <ExpenseEntry>[
    ...actualFuture,
    ...dedupedProjected
  ]..sort((a, b) => a.date.compareTo(b.date));

  final reportTransactions = (selectedCurrencies?.length ?? 0) > 1
      ? convertTransactionsToCurrency(
          futureTransactions,
          targetCurrency: currencyCode,
          rates: rates,
        )
      : futureTransactions;
  return (native: futureTransactions, report: reportTransactions);
}

List<MonthlyReportRecurringInput> _recurringItemsForReport(
  List<RecurringTransaction> recurringTransactions, {
  required List<ExpenseEntry> previousTransactions,
  required DateTime now,
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
    final aggregateAmount = hasMultiCurrencySelection
        ? rates.convert(item.amount.abs(), itemCurrency, currencyCode)
        : item.amount.abs();
    final nativeMonthlyAmount = _normalizedMonthlyRecurringAmount(item);
    final aggregateMonthlyAmount = hasMultiCurrencySelection
        ? rates.convert(nativeMonthlyAmount, itemCurrency, currencyCode)
        : nativeMonthlyAmount;
    return MonthlyReportRecurringInput(
      id: item.id,
      name: _recurringName(item),
      amount: item.amount.abs(),
      monthlyAmount: nativeMonthlyAmount,
      aggregateAmount: aggregateAmount,
      aggregateMonthlyAmount: aggregateMonthlyAmount,
      type: item.type,
      currencyCode: itemCurrency,
      nextDate: nextDate,
      previousAmount: _previousAmountForRecurring(item, previousTransactions),
    );
  }).toList(growable: false);
}

double _normalizedMonthlyRecurringAmount(RecurringTransaction item) {
  final amount = item.amount.abs();
  final rule = item.recurrenceRule;
  if (rule == null) return amount;
  final interval = math.max(rule.interval ?? 1, 1);
  switch (rule.frequency.trim().toLowerCase()) {
    case 'daily':
      return amount * 365.2425 / 12 / interval;
    case 'weekly':
      return amount * 52 / 12 / interval;
    case 'biweekly':
      return amount * 26 / 12 / interval;
    case 'monthly':
      return amount / interval;
    case 'yearly':
      return amount / (12 * interval);
    default:
      return amount;
  }
}

@foundation.visibleForTesting
double normalizedMonthlyRecurringAmountForTesting(RecurringTransaction item) =>
    _normalizedMonthlyRecurringAmount(item);

List<MonthlyReportBudgetInput> _budgetInputs(
  List<PocketEnvelope> pockets, {
  String? sourceError,
  required String currencyCode,
  List<String>? selectedCurrencies,
  required CurrencyRateTable rates,
  required Map<String, double> aggregateSpentByEnvelopeId,
  List<ExpenseEntry> transactions = const <ExpenseEntry>[],
  Map<String, List<String>> envelopeCategories = const <String, List<String>>{},
}) {
  if (sourceError?.trim().isNotEmpty == true) {
    return const <MonthlyReportBudgetInput>[];
  }
  final hasMultiCurrencySelection = (selectedCurrencies?.length ?? 0) > 1;
  final targetCurrency = currencyCode.trim().toUpperCase();
  return pockets.map(
    (pocket) {
      final sourceCurrency = pocket.currency.trim().toUpperCase();
      final budgetAmount = hasMultiCurrencySelection
          ? convertAmountCentsToCurrency(
                pocket.availableBudgetCents,
                fromCurrency:
                    sourceCurrency.isEmpty ? targetCurrency : sourceCurrency,
                targetCurrency: targetCurrency,
                rates: rates,
              ) /
              100.0
          : pocket.availableBudgetCents / 100.0;
      final spent = hasMultiCurrencySelection
          ? aggregateSpentByEnvelopeId[pocket.id] ??
              convertAmountCentsToCurrency(
                    (pocket.spent * 100).round(),
                    fromCurrency: sourceCurrency.isEmpty
                        ? targetCurrency
                        : sourceCurrency,
                    targetCurrency: targetCurrency,
                    rates: rates,
                  ) /
                  100.0
          : pocket.spent;
      final linkedCategories =
          (envelopeCategories[pocket.id] ?? const <String>[])
              .map((category) => category.trim().toLowerCase())
              .where((category) => category.isNotEmpty)
              .toSet();
      if (linkedCategories.isEmpty && pocket.name.trim().isNotEmpty) {
        linkedCategories.add(pocket.name.trim().toLowerCase());
      }
      final sourceTransactionIds = transactions
          .where((transaction) =>
              (transaction.type ?? 'expense').toLowerCase() != 'income')
          .where((transaction) => linkedCategories.contains(
                (transaction.category ?? 'uncategorized').trim().toLowerCase(),
              ))
          .map((transaction) => transaction.id)
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      return MonthlyReportBudgetInput(
        name: pocket.name,
        budgetAmount: budgetAmount,
        spent: spent,
        sourceTransactionIds: sourceTransactionIds,
      );
    },
  ).toList(growable: false);
}

@foundation.visibleForTesting
List<MonthlyReportBudgetInput> buildMonthlyReportBudgetInputsForTesting(
  List<PocketEnvelope> pockets, {
  String? sourceError,
  required String currencyCode,
  List<String>? selectedCurrencies,
  required CurrencyRateTable rates,
  required Map<String, double> aggregateSpentByEnvelopeId,
  List<ExpenseEntry> transactions = const <ExpenseEntry>[],
  Map<String, List<String>> envelopeCategories = const <String, List<String>>{},
}) {
  return _budgetInputs(
    pockets,
    sourceError: sourceError,
    currencyCode: currencyCode,
    selectedCurrencies: selectedCurrencies,
    rates: rates,
    aggregateSpentByEnvelopeId: aggregateSpentByEnvelopeId,
    transactions: transactions,
    envelopeCategories: envelopeCategories,
  );
}

MonthlyReportTransactionInput _transactionInput(
  ExpenseEntry entry, {
  ExpenseEntry? nativeEntry,
}) {
  final sourceEntry = nativeEntry ?? entry;
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
    recurringId: sourceEntry.parentRecurringId ??
        extractRecurringTransactionIdFromProjectedExpenseId(entry.id),
    currencyCode: (entry.currency ?? '').toUpperCase(),
    nativeAmount: sourceEntry.amount.abs(),
    nativeCurrencyCode: (sourceEntry.currency ?? '').toUpperCase(),
  );
}

bool shouldReadMonthlyReportCache({
  required int dashboardRefreshSignal,
  required int transactionsRefreshSignal,
}) =>
    dashboardRefreshSignal == 0 && transactionsRefreshSignal == 0;

MonthlyReportTransactionInput monthlyReportTransactionInputForTesting(
  ExpenseEntry entry, {
  ExpenseEntry? nativeEntry,
}) =>
    _transactionInput(entry, nativeEntry: nativeEntry);

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
