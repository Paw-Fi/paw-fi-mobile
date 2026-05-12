import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardDataService {
  Future<DashboardSnapshotSummary> fetchSnapshot(DashboardScopeQuery query);

  Future<List<ExpenseEntry>> fetchRecentTransactions(
    DashboardRecentTransactionsRequest request,
  );

  Future<List<ExpenseEntry>> fetchCalendarTransactions(
      DashboardScopeQuery query);
}

class PreviewDashboardDataService implements DashboardDataService {
  const PreviewDashboardDataService();

  @override
  Future<DashboardSnapshotSummary> fetchSnapshot(
      DashboardScopeQuery query) async {
    final expenses = PreviewMockData.expenses.where((entry) {
      final matchesHousehold = query.householdId == null
          ? (entry.householdId == null || (entry.householdId?.isEmpty ?? false))
          : entry.householdId == query.householdId;
      final matchesCurrency = query.normalizedCurrency == null ||
          (entry.currency ?? '').toUpperCase() == query.normalizedCurrency;
      final matchesStart =
          query.startDate == null || !entry.date.isBefore(query.startDate!);
      final matchesEnd =
          query.endDate == null || !entry.date.isAfter(query.endDate!);
      return matchesHousehold && matchesCurrency && matchesStart && matchesEnd;
    }).toList();

    final expenseRows = expenses
        .where((entry) => (entry.type ?? 'expense').toLowerCase() != 'income');
    final incomeRows = expenses
        .where((entry) => (entry.type ?? 'expense').toLowerCase() == 'income');
    final categoryTotals = <String, DashboardCategorySummary>{};
    for (final entry in expenseRows) {
      final category = (entry.category ?? 'uncategorized').toLowerCase();
      final existing = categoryTotals[category];
      categoryTotals[category] = DashboardCategorySummary(
        category: category,
        amount: (existing?.amount ?? 0) + entry.amount.abs(),
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    return DashboardSnapshotSummary(
      transactionCount: expenses.length,
      expenseTotal:
          expenseRows.fold<double>(0, (sum, entry) => sum + entry.amount.abs()),
      incomeTotal:
          incomeRows.fold<double>(0, (sum, entry) => sum + entry.amount.abs()),
      hasMultipleCurrencies: expenses
              .map((e) => (e.currency ?? '').toUpperCase())
              .where((e) => e.isNotEmpty)
              .toSet()
              .length >
          1,
      categorySummaries: categoryTotals.values.toList(growable: false),
      periodTotals: const <DateTime, double>{},
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchRecentTransactions(
      DashboardRecentTransactionsRequest request) async {
    final all = await fetchCalendarTransactions(request.query);
    all.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return all.take(request.limit).toList(growable: false);
  }

  @override
  Future<List<ExpenseEntry>> fetchCalendarTransactions(
      DashboardScopeQuery query) async {
    return PreviewMockData.expenses
        .where((entry) {
          final matchesHousehold = query.householdId == null
              ? (entry.householdId == null ||
                  (entry.householdId?.isEmpty ?? false))
              : entry.householdId == query.householdId;
          final matchesCurrency = query.normalizedCurrency == null ||
              (entry.currency ?? '').toUpperCase() == query.normalizedCurrency;
          final matchesStart =
              query.startDate == null || !entry.date.isBefore(query.startDate!);
          final matchesEnd =
              query.endDate == null || !entry.date.isAfter(query.endDate!);
          return matchesHousehold &&
              matchesCurrency &&
              matchesStart &&
              matchesEnd;
        })
        .map((entry) => entry.copyWith())
        .toList(growable: false);
  }
}

class SupabaseDashboardDataService implements DashboardDataService {
  const SupabaseDashboardDataService(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSnapshotSummary> fetchSnapshot(
      DashboardScopeQuery query) async {
    final trace = HomeDebugTrace(
      label: 'DashboardSnapshotRpc',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': query.userId,
        'household': query.householdId ?? '<none>',
        'currency': query.normalizedCurrency ?? '<none>',
        'start': query.startDate,
        'end': query.endDate,
      },
    );
    trace.mark('rpc-start');
    final response = await _client.rpc(
      'get_dashboard_snapshot_v1',
      params: <String, dynamic>{
        'p_user_id': query.userId,
        'p_household_id': query.householdId,
        'p_currency': query.normalizedCurrency,
        'p_start_date': query.formattedStartDate,
        'p_end_date': query.formattedEndDate,
        'p_interval_granularity': query.normalizedIntervalGranularity,
      },
    );

    final payload = Map<String, dynamic>.from(response as Map);
    final categorySummaries = ((payload['category_summaries'] as List?) ??
            const [])
        .cast<Map>()
        .map(
          (row) => DashboardCategorySummary(
            category:
                (row['category'] as String? ?? 'uncategorized').toLowerCase(),
            amount: _centsToDouble(row['amount_cents']),
            transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);

    final periodTotals = <DateTime, double>{};
    for (final row
        in ((payload['period_totals'] as List?) ?? const []).cast<Map>()) {
      final bucketRaw = row['bucket_start'];
      if (bucketRaw == null) {
        continue;
      }
      periodTotals[DateTime.parse(bucketRaw.toString())] =
          _centsToDouble(row['amount_cents']);
    }

    final summary = DashboardSnapshotSummary(
      transactionCount: (payload['transaction_count'] as num?)?.toInt() ?? 0,
      expenseTotal: _centsToDouble(payload['expense_total_cents']),
      incomeTotal: _centsToDouble(payload['income_total_cents']),
      hasMultipleCurrencies: payload['has_multiple_currencies'] == true,
      categorySummaries: categorySummaries,
      periodTotals: periodTotals,
    );
    trace.mark('rpc-success', {
      'transactionCount': summary.transactionCount,
      'expenseTotal': summary.expenseTotal,
      'incomeTotal': summary.incomeTotal,
    });
    return summary;
  }

  @override
  Future<List<ExpenseEntry>> fetchRecentTransactions(
    DashboardRecentTransactionsRequest request,
  ) async {
    final trace = HomeDebugTrace(
      label: 'DashboardRecentTransactionsRpc',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': request.query.userId,
        'household': request.query.householdId ?? '<none>',
        'currency': request.query.normalizedCurrency ?? '<none>',
        'limit': request.limit,
      },
    );
    trace.mark('rpc-start');
    final response = await _client.rpc(
      'get_dashboard_recent_transactions_v1',
      params: <String, dynamic>{
        'p_user_id': request.query.userId,
        'p_household_id': request.query.householdId,
        'p_currency': request.query.normalizedCurrency,
        'p_limit': request.limit,
      },
    );

    final entries = _parseExpenseEntries(response);
    trace.mark('rpc-success', {'count': entries.length});
    return entries;
  }

  @override
  Future<List<ExpenseEntry>> fetchCalendarTransactions(
      DashboardScopeQuery query) async {
    final trace = HomeDebugTrace(
      label: 'DashboardCalendarTransactionsRpc',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': query.userId,
        'household': query.householdId ?? '<none>',
        'currency': query.normalizedCurrency ?? '<none>',
        'start': query.startDate,
        'end': query.endDate,
      },
    );
    trace.mark('rpc-start');
    final response = await _client.rpc(
      'get_dashboard_calendar_transactions_v1',
      params: <String, dynamic>{
        'p_user_id': query.userId,
        'p_household_id': query.householdId,
        'p_currency': query.normalizedCurrency,
        'p_start_date': query.formattedStartDate,
        'p_end_date': query.formattedEndDate,
      },
    );

    final entries = _parseExpenseEntries(response);
    trace.mark('rpc-success', {'count': entries.length});
    return entries;
  }

  List<ExpenseEntry> _parseExpenseEntries(dynamic response) {
    final rows = (response as List? ?? const [])
        .cast<Map>()
        .map((row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return rows;
  }

  double _centsToDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble() / 100;
    }
    return (num.tryParse(value.toString()) ?? 0).toDouble() / 100;
  }
}

final dashboardDataServiceProvider = Provider<DashboardDataService>((ref) {
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return const PreviewDashboardDataService();
  }
  return SupabaseDashboardDataService(supabase);
});

final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);

final dashboardLocalOverlayTransactionsProvider =
    Provider.family<List<ExpenseEntry>, DashboardScopeQuery>((ref, query) {
  final householdId = query.householdId?.trim();
  if (householdId == null || householdId.isEmpty) {
    // Personal mode: get optimistic transactions from analyticsProvider
    final analyticsData = ref.watch(analyticsProvider);
    final optimistic = analyticsData.expenses;
    return mergeDashboardTransactionsWithLocalOverlay(
      base: const <ExpenseEntry>[],
      localOverlay: optimistic,
      query: query,
    );
  }

  final optimistic = ref.watch(
    householdOptimisticExpensesProvider.select(
      (state) => state[householdId] ?? const <ExpenseEntry>[],
    ),
  );
  return mergeDashboardTransactionsWithLocalOverlay(
    base: const <ExpenseEntry>[],
    localOverlay: optimistic,
    query: query,
  );
});

List<ExpenseEntry> mergeDashboardTransactionsWithLocalOverlay({
  required List<ExpenseEntry> base,
  required Iterable<ExpenseEntry> localOverlay,
  required DashboardScopeQuery query,
  int? limit,
}) {
  final merged = <ExpenseEntry>[];
  final seen = <String>{};

  void addIfUnique(ExpenseEntry entry) {
    if (entry.id.isEmpty) return;
    if (!_matchesDashboardQuery(entry, query)) return;
    if (seen.add(entry.id)) {
      merged.add(entry);
    }
  }

  for (final entry in localOverlay) {
    addIfUnique(entry);
  }
  for (final entry in base) {
    addIfUnique(entry);
  }

  merged.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  });

  if (limit != null && limit >= 0 && merged.length > limit) {
    return merged.take(limit).toList(growable: false);
  }
  return merged;
}

bool _matchesDashboardQuery(ExpenseEntry entry, DashboardScopeQuery query) {
  final queryHouseholdId = query.householdId?.trim();
  final entryHouseholdId = entry.householdId?.trim();
  final matchesHousehold = queryHouseholdId == null || queryHouseholdId.isEmpty
      ? entryHouseholdId == null || entryHouseholdId.isEmpty
      : entryHouseholdId == queryHouseholdId;
  if (!matchesHousehold) return false;

  final currency = query.normalizedCurrency;
  if (currency != null &&
      (entry.currency ?? '').trim().toUpperCase() != currency) {
    return false;
  }

  final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
  final start = query.startDate;
  if (start != null) {
    final startDate = DateTime(start.year, start.month, start.day);
    if (entryDate.isBefore(startDate)) return false;
  }

  final end = query.endDate;
  if (end != null) {
    final endDate = DateTime(end.year, end.month, end.day);
    if (entryDate.isAfter(endDate)) return false;
  }

  return true;
}

TransactionsFeedQuery dashboardTransactionsQuery(
  DashboardScopeQuery query, {
  int pageSize = 60,
}) {
  return TransactionsFeedQuery(
    userId: query.userId,
    householdId: query.householdId,
    selectedCurrency: query.selectedCurrency,
    selectedCategory: null,
    selectedType: 'all',
    searchQuery: '',
    startDate: query.startDate,
    endDate: query.endDate,
    pageSize: pageSize,
    summaryIntervalGranularity: query.intervalGranularity,
  );
}

DashboardSnapshotSummary _dashboardSummaryFromTransactionsFeedSummary(
  TransactionsFeedSummary summary,
) {
  return DashboardSnapshotSummary(
    transactionCount: summary.transactionCount,
    expenseTotal: summary.expenseTotal,
    incomeTotal: summary.incomeTotal,
    hasMultipleCurrencies: summary.hasMultipleCurrencies,
    categorySummaries: summary.categorySummaries
        .map(
          (category) => DashboardCategorySummary(
            category: category.category,
            amount: category.amount,
            transactionCount: category.transactionCount,
          ),
        )
        .toList(growable: false),
    periodTotals: summary.periodTotals.isNotEmpty
        ? summary.periodTotals
        : summary.yearlyPeriodTotals,
  );
}

final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSnapshotSummary, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(dashboardCacheInvalidationProvider);
    final preview = ref.watch(previewModeProvider);
    final trace = HomeDebugTrace(
      label: 'DashboardSummaryProvider',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': query.userId,
        'household': query.householdId ?? '<none>',
        'currency': query.normalizedCurrency ?? '<none>',
        'start': query.startDate,
        'end': query.endDate,
      },
    );
    final cacheKey =
        'dashboard:summary:v1:${query.userId}:${query.householdId ?? 'personal'}:${query.normalizedCurrency ?? '<none>'}:${query.formattedStartDate ?? '<none>'}:${query.formattedEndDate ?? '<none>'}:${query.normalizedIntervalGranularity ?? '<none>'}';
    final sessionCached =
        readDashboardSessionCache<DashboardSnapshotSummary>(cacheKey);
    if (sessionCached != null &&
        DateTime.now().difference(sessionCached.cachedAt) <=
            dashboardTransactionsCacheTtl(query.startDate, query.endDate)) {
      trace.mark('session-cache-hit');
      return sessionCached.value;
    }
    final summary = preview.isActive
        ? await ref.watch(dashboardDataServiceProvider).fetchSnapshot(query)
        : _dashboardSummaryFromTransactionsFeedSummary(
            await ref.watch(transactionsFeedServiceProvider).fetchSummary(
                  dashboardTransactionsQuery(query),
                ),
          );
    writeDashboardSessionCache(cacheKey, summary);
    return summary;
  },
);

final dashboardRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, DashboardRecentTransactionsRequest>(
  (ref, request) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(dashboardCacheInvalidationProvider);
    final preview = ref.watch(previewModeProvider);
    final cacheKey = dashboardRecentCacheKey(
      userId: request.query.userId,
      householdId: request.query.householdId,
      currency: request.query.normalizedCurrency,
      limit: request.limit,
    );
    final sessionCached =
        readDashboardSessionCache<List<ExpenseEntry>>(cacheKey);
    final trace = HomeDebugTrace(
      label: 'DashboardRecentTransactionsProvider',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': request.query.userId,
        'household': request.query.householdId ?? '<none>',
        'currency': request.query.normalizedCurrency ?? '<none>',
        'limit': request.limit,
      },
    );
    final bypassPersistedCache =
        ref.read(dashboardPersistedCacheBypassCountProvider) > 0;
    if (sessionCached != null &&
        DateTime.now().difference(sessionCached.cachedAt) <=
            dashboardRecentTransactionsCacheTtl) {
      trace.mark('session-cache-hit', {'count': sessionCached.value.length});
      return sessionCached.value;
    }
    if (!bypassPersistedCache) {
      final persistedPayload = readDashboardPersistedCache(ref, cacheKey);
      final statePayload = persistedPayload == null
          ? null
          : readDashboardStatePayload(persistedPayload);
      final cachedAt = persistedPayload == null
          ? null
          : readDashboardCachedAt(persistedPayload);
      if (statePayload != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) <=
              dashboardRecentTransactionsCacheTtl) {
        final entries = ((statePayload['items'] as List?) ?? const [])
            .cast<Map>()
            .map((row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        trace.mark('persisted-cache-hit', {'count': entries.length});
        writeDashboardSessionCache(cacheKey, entries);
        return entries;
      }
    }
    final entries = preview.isActive
        ? await ref
            .watch(dashboardDataServiceProvider)
            .fetchRecentTransactions(request)
        : (await ref.watch(transactionsFeedServiceProvider).fetchPage(
                  dashboardTransactionsQuery(
                    request.query,
                    pageSize: request.limit,
                  ),
                ))
            .items;
    writeDashboardSessionCache(cacheKey, entries);
    unawaited(writeDashboardPersistedCache(ref, cacheKey, {
      'cached_at': DateTime.now().toIso8601String(),
      'state': {
        'items': entries.map((item) => item.toJson()).toList(growable: false),
      },
    }));
    return entries;
  },
);

final dashboardCalendarTransactionsProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntry>, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(dashboardCacheInvalidationProvider);
    final preview = ref.watch(previewModeProvider);
    final cacheKey = dashboardCalendarCacheKey(
      userId: query.userId,
      householdId: query.householdId,
      currency: query.normalizedCurrency,
      start: query.formattedStartDate,
      end: query.formattedEndDate,
    );
    final ttl = dashboardTransactionsCacheTtl(query.startDate, query.endDate);
    final bypassPersistedCache =
        ref.read(dashboardPersistedCacheBypassCountProvider) > 0;
    final sessionCached =
        readDashboardSessionCache<List<ExpenseEntry>>(cacheKey);
    final trace = HomeDebugTrace(
      label: 'DashboardCalendarTransactionsProvider',
      enabled: foundation.kDebugMode,
      logSink: foundation.debugPrint,
      contextFields: {
        'user': query.userId,
        'household': query.householdId ?? '<none>',
        'currency': query.normalizedCurrency ?? '<none>',
        'start': query.startDate,
        'end': query.endDate,
      },
    );
    if (sessionCached != null &&
        DateTime.now().difference(sessionCached.cachedAt) <= ttl) {
      trace.mark('session-cache-hit', {'count': sessionCached.value.length});
      return sessionCached.value;
    }
    if (!bypassPersistedCache) {
      final persistedPayload = readDashboardPersistedCache(ref, cacheKey);
      final statePayload = persistedPayload == null
          ? null
          : readDashboardStatePayload(persistedPayload);
      final cachedAt = persistedPayload == null
          ? null
          : readDashboardCachedAt(persistedPayload);
      if (statePayload != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) <= ttl) {
        final entries = ((statePayload['items'] as List?) ?? const [])
            .cast<Map>()
            .map((row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        trace.mark('persisted-cache-hit', {'count': entries.length});
        writeDashboardSessionCache(cacheKey, entries);
        return entries;
      }
    }
    final entries = preview.isActive
        ? await ref
            .watch(dashboardDataServiceProvider)
            .fetchCalendarTransactions(query)
        : await ref
            .watch(transactionsFeedServiceProvider)
            .fetchAllPages(dashboardTransactionsQuery(query, pageSize: 500));
    writeDashboardSessionCache(cacheKey, entries);
    unawaited(writeDashboardPersistedCache(ref, cacheKey, {
      'cached_at': DateTime.now().toIso8601String(),
      'state': {
        'items': entries.map((item) => item.toJson()).toList(growable: false),
      },
    }));
    return entries;
  },
);
