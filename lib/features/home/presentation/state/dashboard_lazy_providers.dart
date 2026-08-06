import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_sqlite_cache.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _homeSpendTrace(String message) {
  assert(() {
    foundation.debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

double _traceExpenseTotal(Iterable<ExpenseEntry> entries) {
  return entries.fold<double>(
    0,
    (sum, entry) => sum + entry.spendingEffect,
  );
}

String _traceAmount(num value) => value.toStringAsFixed(2);

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
    final expenses = PreviewMockData.dashboardExpenses.where((entry) {
      final matchesHousehold = query.householdId == null
          ? (entry.householdId == null || (entry.householdId?.isEmpty ?? false))
          : entry.householdId == query.householdId;
      final matchesCurrency = query.allowsCurrency(entry.currency);
      final matchesStart =
          query.startDate == null || !entry.date.isBefore(query.startDate!);
      final matchesEnd =
          query.endDate == null || !entry.date.isAfter(query.endDate!);
      return matchesHousehold && matchesCurrency && matchesStart && matchesEnd;
    }).toList();

    if ((query.normalizedCurrencies?.length ?? 0) > 1) {
      return _dashboardSummaryFromTransactionsFeedSummary(
        summarizeTransactionsInCurrency(
          expenses,
          targetCurrency: query.normalizedCurrency ?? 'USD',
          rates: const CurrencyRateTable(
            baseCurrency: 'USD',
            rates: CurrencyRates.rates,
            isStale: true,
          ),
          intervalGranularity: query.normalizedIntervalGranularity ?? 'yearly',
        ),
      );
    }

    final expenseRows =
        expenses.where((entry) => entry.effectiveSpendingMultiplier != 0);
    final incomeRows = expenses.where((entry) => entry.countsTowardIncome);
    final categoryTotals = <String, DashboardCategorySummary>{};
    for (final entry in expenseRows) {
      final category = (entry.category ?? 'uncategorized').toLowerCase();
      final existing = categoryTotals[category];
      categoryTotals[category] = DashboardCategorySummary(
        category: category,
        amount: (existing?.amount ?? 0) + entry.spendingEffect,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    return DashboardSnapshotSummary(
      transactionCount: expenses.length,
      expenseTotal: expenseRows.fold<double>(
          0, (sum, entry) => sum + entry.spendingEffect),
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
    return PreviewMockData.dashboardExpenses
        .where((entry) {
          final matchesHousehold = query.householdId == null
              ? (entry.householdId == null ||
                  (entry.householdId?.isEmpty ?? false))
              : entry.householdId == query.householdId;
          final matchesCurrency = query.allowsCurrency(entry.currency);
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
        'currencies': query.normalizedCurrencies ?? const <String>[],
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
        'currencies': request.query.normalizedCurrencies ?? const <String>[],
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
        'currencies': query.normalizedCurrencies ?? const <String>[],
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

Future<TransactionsFeedService> _dashboardTransactionFeedService(
    Ref ref) async {
  final current = ref.watch(transactionsFeedServiceProvider);
  if (current is! EmptyTransactionsFeedService) {
    _homeSpendTrace('dashboard-feed-service source=${current.runtimeType}');
    return current;
  }

  final remote = ref.watch(transactionsRemoteFeedServiceProvider);
  final hasNetworkAccess =
      ref.watch(networkReachabilityProvider).valueOrNull ?? true;

  try {
    final database = await ref.watch(localDatabaseProvider.future);
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
      remoteEnabled: hasNetworkAccess,
    );
    _homeSpendTrace(
      'dashboard-feed-service source=local-after-empty remoteEnabled=$hasNetworkAccess',
    );
    return service;
  } catch (error) {
    _homeSpendTrace(
        'dashboard-feed-service source=remote-fallback error=$error');
    return remote;
  }
}

final dashboardDataServiceProvider = Provider<DashboardDataService>((ref) {
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return const PreviewDashboardDataService();
  }
  return SupabaseDashboardDataService(supabase);
});

final dashboardSupabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});

final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);

const Duration _dashboardNetworkFreshness = Duration(minutes: 5);
const int _dashboardCoordinatorEntryLimit = 256;

class DashboardRefreshMetadata {
  const DashboardRefreshMetadata({
    this.isRefreshing = false,
    this.isFromCache = false,
    this.lastRefreshedAt,
    this.error,
  });

  final bool isRefreshing;
  final bool isFromCache;
  final DateTime? lastRefreshedAt;
  final Object? error;
}

final dashboardRefreshMetadataProvider =
    StateProvider.autoDispose.family<DashboardRefreshMetadata, String>(
  (ref, _) => const DashboardRefreshMetadata(),
);

class _DashboardFetchResult<T> {
  const _DashboardFetchResult({
    required this.value,
    required this.persisted,
  });

  final T value;
  final bool persisted;
}

class _DashboardTransactionLoad {
  const _DashboardTransactionLoad({
    required this.visible,
    required this.confirmedBase,
    required this.invalidIdsAtLoad,
  });

  final List<ExpenseEntry> visible;
  final List<ExpenseEntry> confirmedBase;
  final Set<String> invalidIdsAtLoad;
}

class _DashboardRequestGeneration {
  const _DashboardRequestGeneration({
    required this.cacheKey,
    required this.dashboardRefresh,
    required this.transactionsRefresh,
  });

  final String cacheKey;
  final int dashboardRefresh;
  final int transactionsRefresh;

  String get token =>
      '$cacheKey:dashboard=$dashboardRefresh:transactions=$transactionsRefresh';

  bool hasSameRevision(_DashboardRequestGeneration other) =>
      dashboardRefresh == other.dashboardRefresh &&
      transactionsRefresh == other.transactionsRefresh;

  bool dominates(_DashboardRequestGeneration other) =>
      dashboardRefresh >= other.dashboardRefresh &&
      transactionsRefresh >= other.transactionsRefresh;
}

class _DashboardRequestCoordinator {
  _DashboardRequestCoordinator({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, Future<Object>> _inFlight = {};
  final Map<String, Future<void>> _persisting = {};
  final Map<String, _DashboardRequestGeneration> _latestGeneration = {};
  final Map<String, DateTime> _freshGenerations = {};

  bool isFresh(_DashboardRequestGeneration generation) {
    _prune();
    final latest = _latestGeneration[generation.cacheKey];
    final refreshedAt = _freshGenerations[generation.token];
    return latest?.token == generation.token &&
        refreshedAt != null &&
        _now().difference(refreshedAt) <= _dashboardNetworkFreshness;
  }

  bool _isCurrent(_DashboardRequestGeneration generation) =>
      _latestGeneration[generation.cacheKey]?.token == generation.token;

  void _register(_DashboardRequestGeneration generation) {
    final latest = _latestGeneration[generation.cacheKey];
    if (latest != null &&
        !generation.hasSameRevision(latest) &&
        !generation.dominates(latest)) {
      return;
    }
    _latestGeneration[generation.cacheKey] = generation;
    _freshGenerations.removeWhere(
      (token, _) =>
          token.startsWith('${generation.cacheKey}:') &&
          token != generation.token,
    );
    _prune();
  }

  Future<_DashboardFetchResult<T>> run<T>({
    required _DashboardRequestGeneration generation,
    required bool Function() isActive,
    required Future<T> Function() load,
    required Future<void> Function(T value) persist,
  }) async {
    if (isActive()) _register(generation);
    final token = generation.token;
    final operation = _inFlight[token] ??= _executeLoad<T>(token, load);
    final value = await operation as T;

    if (isActive() && _isCurrent(generation)) {
      final existingPersist = _persisting[token];
      if (existingPersist != null) {
        await existingPersist;
      } else {
        final persistOperation = _executePersist<T>(
          token: token,
          generation: generation,
          isActive: isActive,
          value: value,
          persist: persist,
        );
        _persisting[token] = persistOperation;
        await persistOperation;
      }
    }

    return _DashboardFetchResult<T>(
      value: value,
      persisted: isActive() && _isCurrent(generation),
    );
  }

  Future<Object> _executeLoad<T>(
    String token,
    Future<T> Function() load,
  ) async {
    try {
      return await load() as Object;
    } finally {
      _inFlight.remove(token);
    }
  }

  Future<void> _executePersist<T>({
    required String token,
    required _DashboardRequestGeneration generation,
    required bool Function() isActive,
    required T value,
    required Future<void> Function(T value) persist,
  }) async {
    try {
      if (isActive() && _isCurrent(generation)) {
        try {
          await persist(value);
        } catch (_) {
          // A successful network response must remain usable even if a
          // best-effort SQLite write or prune fails.
        }
        if (_isCurrent(generation)) {
          _freshGenerations[token] = _now();
        }
      }
    } finally {
      _persisting.remove(token);
      _prune();
    }
  }

  void _prune() {
    final cutoff = _now().subtract(_dashboardNetworkFreshness);
    _freshGenerations
        .removeWhere((_, refreshedAt) => refreshedAt.isBefore(cutoff));
    if (_latestGeneration.length <= _dashboardCoordinatorEntryLimit) return;

    final removable = _latestGeneration.keys.where((key) {
      final token = _latestGeneration[key]?.token;
      return token != null &&
          !_inFlight.containsKey(token) &&
          !_persisting.containsKey(token) &&
          !_freshGenerations.containsKey(token);
    }).toList(growable: false);
    for (final key in removable) {
      if (_latestGeneration.length <= _dashboardCoordinatorEntryLimit) break;
      _latestGeneration.remove(key);
    }
  }

  void clearUser(String userId) {
    final userComponent = Uri.encodeComponent(userId.trim());
    final marker = 'u=$userComponent:';
    bool belongsToUser(String key) =>
        key.startsWith(marker) || key.contains(':$marker');
    _latestGeneration.removeWhere((key, _) => belongsToUser(key));
    _freshGenerations.removeWhere((token, _) => belongsToUser(token));
  }
}

final dashboardRequestCoordinatorProvider =
    Provider<_DashboardRequestCoordinator>((ref) {
  return _DashboardRequestCoordinator();
});

void clearDashboardProviderMemoryForUser(Ref ref, String userId) {
  ref.read(dashboardRequestCoordinatorProvider).clearUser(userId);
}

bool _dashboardRequestUserIsCurrent(Ref ref, String userId) {
  return ref.read(authProvider).uid == userId ||
      ref.read(previewModeProvider).isActive;
}

_DashboardRequestGeneration _dashboardRequestGeneration({
  required String cacheKey,
  required int dashboardRefresh,
  required int transactionsRefresh,
}) {
  return _DashboardRequestGeneration(
    cacheKey: cacheKey,
    dashboardRefresh: dashboardRefresh,
    transactionsRefresh: transactionsRefresh,
  );
}

final dashboardPersonalLocalOverlayProvider =
    Provider<List<ExpenseEntry>>((ref) {
  final expenses = ref.watch(
    analyticsProvider.select((state) => state.expenses),
  );
  return expenses
      .where(_isDashboardLocalOverlayCandidate)
      .toList(growable: false);
});

final dashboardLocalOverlayTransactionsProvider =
    Provider.family<List<ExpenseEntry>, DashboardScopeQuery>((ref, query) {
  final householdId = query.householdId?.trim();
  if (householdId == null || householdId.isEmpty) {
    final localOnlyOverlay = ref
        .watch(dashboardPersonalLocalOverlayProvider)
        .where((entry) => entry.userId?.trim() == query.userId)
        .toList(growable: false);
    final overlay = mergeDashboardTransactionsWithLocalOverlay(
      base: const <ExpenseEntry>[],
      localOverlay: localOnlyOverlay,
      query: query,
    );
    _homeSpendTrace(
      'dashboard-overlay scope=personal analyticsCount=${localOnlyOverlay.length} '
      'overlayCount=${overlay.length} overlayTotal=${_traceAmount(_traceExpenseTotal(overlay))}',
    );
    return overlay;
  }

  final optimistic = ref
      .watch(
        householdOptimisticExpensesProvider.select(
          (state) => state[householdId] ?? const <ExpenseEntry>[],
        ),
      )
      .where((entry) => _isOptimisticTransactionId(entry.id.trim()))
      .toList(
        growable: false,
      );
  final overlay = mergeDashboardTransactionsWithLocalOverlay(
    base: const <ExpenseEntry>[],
    localOverlay: optimistic,
    query: query,
  );
  _homeSpendTrace(
    'dashboard-overlay scope=household household=$householdId '
    'optimisticCount=${optimistic.length} overlayCount=${overlay.length} '
    'overlayTotal=${_traceAmount(_traceExpenseTotal(overlay))}',
  );
  return overlay;
});

List<ExpenseEntry> mergeDashboardTransactionsWithLocalOverlay({
  required List<ExpenseEntry> base,
  required Iterable<ExpenseEntry> localOverlay,
  required DashboardScopeQuery query,
  int? limit,
  bool matchHousehold = true,
  Set<String> deletedIds = const <String>{},
  Set<String> hiddenBaseIds = const <String>{},
}) {
  final merged = <ExpenseEntry>[];
  final seen = <String>{};
  final reconciliationKeyIndexes = <String, int>{};

  void indexReconciliationKeys(ExpenseEntry entry, int index) {
    for (final key in _dashboardTransactionReconciliationKeys(entry)) {
      reconciliationKeyIndexes[key] = index;
    }
  }

  void addIfUnique(ExpenseEntry entry) {
    if (entry.id.isEmpty) return;
    if (deletedIds.contains(entry.id)) return;
    if (!_matchesDashboardQuery(
      entry,
      query,
      matchHousehold: matchHousehold,
    )) {
      return;
    }
    if (!seen.add(entry.id)) return;

    for (final key in _dashboardTransactionReconciliationKeys(entry)) {
      final existingIndex = reconciliationKeyIndexes[key];
      if (existingIndex == null) continue;

      final existing = merged[existingIndex];
      if (_shouldReconcileDashboardTransactions(existing, entry, key)) {
        final replacement =
            _preferredDashboardTransaction(existing: existing, incoming: entry);
        merged[existingIndex] = replacement;
        indexReconciliationKeys(replacement, existingIndex);
        return;
      }
    }

    indexReconciliationKeys(entry, merged.length);
    merged.add(entry);
  }

  for (final entry in localOverlay) {
    addIfUnique(entry);
  }
  for (final entry in base) {
    if (hiddenBaseIds.contains(entry.id) && !seen.contains(entry.id)) continue;
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

bool _matchesDashboardQuery(
  ExpenseEntry entry,
  DashboardScopeQuery query, {
  required bool matchHousehold,
}) {
  if (matchHousehold) {
    final queryHouseholdId = query.householdId?.trim();
    final entryHouseholdId = entry.householdId?.trim();
    final matchesHousehold =
        queryHouseholdId == null || queryHouseholdId.isEmpty
            ? entryHouseholdId == null || entryHouseholdId.isEmpty
            : entryHouseholdId == queryHouseholdId;
    if (!matchesHousehold) return false;
  }

  if (!query.allowsCurrency(entry.currency)) {
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

bool _isOptimisticTransactionId(String id) => id.startsWith('optimistic_');

bool _isDashboardLocalOverlayCandidate(ExpenseEntry entry) {
  final id = entry.id.trim();
  if (_isOptimisticTransactionId(id)) return true;

  final clientRecordId = entry.clientRecordId?.trim();
  if (clientRecordId != null && _isOptimisticTransactionId(clientRecordId)) {
    return true;
  }

  final clientMutationId = entry.clientMutationId?.trim();
  if (clientMutationId != null &&
      clientMutationId.startsWith('mobile:optimistic_')) {
    return true;
  }

  final idempotencyKey = entry.idempotencyKey?.trim();
  return idempotencyKey != null &&
      idempotencyKey.startsWith('mobile:optimistic_');
}

List<String> _dashboardTransactionReconciliationKeys(ExpenseEntry entry) {
  final keys = <String>[];
  final id = entry.id.trim();
  final clientRecordId = entry.clientRecordId?.trim();
  final clientMutationId = entry.clientMutationId?.trim();
  final idempotencyKey = entry.idempotencyKey?.trim();

  if (_isOptimisticTransactionId(id)) {
    keys.add('client_record:$id');
  }
  if (clientRecordId != null && clientRecordId.isNotEmpty) {
    keys.add('client_record:$clientRecordId');
  }
  if (clientMutationId != null && clientMutationId.isNotEmpty) {
    keys.add('client_mutation:$clientMutationId');
  }
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    keys.add('idempotency:$idempotencyKey');
  }

  final contentKey = _dashboardTransactionContentFingerprint(entry);
  if (contentKey != null) {
    keys.add('content:$contentKey');
  }
  return keys;
}

bool _shouldReconcileDashboardTransactions(
  ExpenseEntry existing,
  ExpenseEntry incoming,
  String key,
) {
  final existingIsOptimistic = _isOptimisticTransactionId(existing.id);
  final incomingIsOptimistic = _isOptimisticTransactionId(incoming.id);
  if (existingIsOptimistic != incomingIsOptimistic) {
    return true;
  }

  return !key.startsWith('content:');
}

ExpenseEntry _preferredDashboardTransaction({
  required ExpenseEntry existing,
  required ExpenseEntry incoming,
}) {
  final existingIsOptimistic = _isOptimisticTransactionId(existing.id);
  final incomingIsOptimistic = _isOptimisticTransactionId(incoming.id);
  if (existingIsOptimistic != incomingIsOptimistic) {
    return incomingIsOptimistic ? existing : incoming;
  }

  final existingUpdatedAt = existing.updatedAt ?? existing.createdAt;
  final incomingUpdatedAt = incoming.updatedAt ?? incoming.createdAt;
  return incomingUpdatedAt.isAfter(existingUpdatedAt) ? incoming : existing;
}

String? _dashboardTransactionContentFingerprint(ExpenseEntry entry) {
  final normalizedText = _normalizedDashboardTransactionText(entry);
  if (normalizedText.isEmpty) return null;
  final dateKey = '${entry.date.year.toString().padLeft(4, '0')}-'
      '${entry.date.month.toString().padLeft(2, '0')}-'
      '${entry.date.day.toString().padLeft(2, '0')}';
  return [
    dateKey,
    entry.amountCents.toString(),
    (entry.currency ?? '').trim().toUpperCase(),
    (entry.type ?? 'expense').trim().toLowerCase(),
    entry.householdId?.trim() ?? '',
    entry.userId?.trim() ?? '',
    normalizedText,
  ].join('|');
}

String _normalizedDashboardTransactionText(ExpenseEntry entry) {
  final source = (entry.rawText?.trim().isNotEmpty == true)
      ? entry.rawText!.trim()
      : (entry.merchant?.trim().isNotEmpty == true)
          ? entry.merchant!.trim()
          : (entry.category ?? '').trim();
  return source
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
}

TransactionsFeedQuery dashboardTransactionsQuery(
  DashboardScopeQuery query, {
  int pageSize = 60,
}) {
  return TransactionsFeedQuery(
    userId: query.userId,
    householdId: query.householdId,
    selectedCurrency: query.selectedCurrency,
    selectedCurrencies: query.normalizedCurrencies,
    selectedCategory: null,
    selectedType: 'all',
    searchQuery: '',
    startDate: query.startDate,
    endDate: query.endDate,
    pageSize: pageSize,
    summaryIntervalGranularity: query.intervalGranularity,
  );
}

LocalTransactionsFeedQuery _dashboardLocalTransactionsQuery(
  DashboardScopeQuery query, {
  required int pageSize,
}) {
  return LocalTransactionsFeedQuery(
    userId: query.userId,
    householdId: query.householdId,
    currency: query.normalizedCurrency,
    currencies: query.normalizedCurrencies,
    type: 'all',
    searchQuery: '',
    startDate: query.startDate,
    endDate: query.endDate,
    pageSize: pageSize,
    intervalGranularity: query.normalizedIntervalGranularity ?? 'yearly',
  );
}

Future<List<ExpenseEntry>> _dashboardPendingLocalTransactions(
  MonekoDatabase? database,
  DashboardScopeQuery query, {
  required int pageSize,
  required bool allPages,
}) async {
  if (database == null) return const <ExpenseEntry>[];
  final localQuery = _dashboardLocalTransactionsQuery(
    query,
    pageSize: pageSize,
  );
  if (allPages) {
    return database.getTransactionsFeedItems(
      localQuery,
      syncStatus: localSyncStatusLocal,
    );
  }
  final page = await database.getTransactionsFeedPage(
    localQuery,
    syncStatus: localSyncStatusLocal,
  );
  return page.items;
}

Future<Set<String>> _dashboardLocalTombstoneIds(
  MonekoDatabase? database,
  DashboardScopeQuery query, {
  bool includeAllHouseholds = false,
}) {
  if (database == null) return Future<Set<String>>.value(const <String>{});
  return database.getActiveTransactionTombstoneIds(
    userId: query.userId,
    householdId: query.householdId,
    includeAllHouseholds: includeAllHouseholds,
  );
}

Future<Set<String>> _dashboardPendingUpdateIds(MonekoDatabase? database) {
  if (database == null) return Future<Set<String>>.value(const <String>{});
  return database.getPendingTransactionUpdateIds();
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

Future<CurrencyRateTable> _dashboardCurrencyRates(
  Future<CurrencyRateTable> ratesFuture,
) async {
  try {
    return await ratesFuture;
  } catch (_) {
    return const CurrencyRateTable(
      baseCurrency: 'USD',
      rates: CurrencyRates.rates,
      isStale: true,
    );
  }
}

Future<DashboardSnapshotSummary> _loadDashboardSummary(
  Ref ref,
  DashboardScopeQuery query, {
  required bool remoteOnly,
}) async {
  final preview = ref.read(previewModeProvider);
  if (preview.isActive) {
    return ref.read(dashboardDataServiceProvider).fetchSnapshot(query);
  }

  final feedService = remoteOnly
      ? ref.read(transactionsRemoteFeedServiceProvider)
      : await _dashboardTransactionFeedService(ref);
  final feedQuery = dashboardTransactionsQuery(query);
  final selectedCurrencies = query.normalizedCurrencies;
  final hasMultiCurrencySelection =
      selectedCurrencies != null && selectedCurrencies.length > 1;
  final ratesFuture = hasMultiCurrencySelection
      ? ref.read(currencyRateTableProvider.future)
      : Future<CurrencyRateTable>.value(
          const CurrencyRateTable(
            baseCurrency: 'USD',
            rates: CurrencyRates.rates,
            isStale: true,
          ),
        );

  // Keep the established per-row conversion path for multi-currency totals.
  // Converting a per-currency aggregate can differ by cents because the app's
  // current behavior rounds individual converted rows before widgets sum them.
  return hasMultiCurrencySelection
      ? _dashboardSummaryFromTransactionsFeedSummary(
          summarizeTransactionsInCurrency(
            await feedService.fetchAllPages(feedQuery),
            targetCurrency: query.normalizedCurrency ?? 'USD',
            rates: await _dashboardCurrencyRates(ratesFuture),
            intervalGranularity:
                query.normalizedIntervalGranularity ?? 'yearly',
          ),
        )
      : _dashboardSummaryFromTransactionsFeedSummary(
          await feedService.fetchSummary(feedQuery),
        );
}

Future<List<ExpenseEntry>> _loadDashboardRecentTransactions(
  Ref ref,
  DashboardRecentTransactionsRequest request, {
  required bool remoteOnly,
}) async {
  final preview = ref.read(previewModeProvider);
  if (preview.isActive) {
    return ref
        .read(dashboardDataServiceProvider)
        .fetchRecentTransactions(request);
  }
  final feedService = remoteOnly
      ? ref.read(transactionsRemoteFeedServiceProvider)
      : await _dashboardTransactionFeedService(ref);
  final page = await feedService.fetchPage(
    dashboardTransactionsQuery(request.query, pageSize: request.limit),
  );
  return page.items;
}

Future<List<ExpenseEntry>> _loadDashboardCalendarTransactions(
  Ref ref,
  DashboardScopeQuery query, {
  required bool remoteOnly,
}) async {
  final preview = ref.read(previewModeProvider);
  if (preview.isActive) {
    final entries = await ref
        .read(dashboardDataServiceProvider)
        .fetchCalendarTransactions(query);
    _homeSpendTrace(
      'dashboard-calendar source=preview count=${entries.length} '
      'total=${_traceAmount(_traceExpenseTotal(entries))}',
    );
    return entries;
  }

  final feedService = remoteOnly
      ? ref.read(transactionsRemoteFeedServiceProvider)
      : await _dashboardTransactionFeedService(ref);
  final entries = await feedService.fetchAllPages(
    dashboardTransactionsQuery(query, pageSize: 500),
  );
  _homeSpendTrace(
    'dashboard-calendar source=${feedService.runtimeType} '
    'count=${entries.length} total=${_traceAmount(_traceExpenseTotal(entries))} '
    'user=${query.userId} household=${query.householdId ?? '<personal>'} '
    'currency=${query.normalizedCurrency ?? '<none>'} currencies=${query.normalizedCurrencies ?? const <String>[]}',
  );
  return entries;
}

Future<List<ExpenseEntry>> _loadDashboardOwnedRangeTransactions(
  Ref ref,
  DashboardScopeQuery query,
) async {
  final preview = ref.read(previewModeProvider);
  if (preview.isActive) {
    return PreviewMockData.dashboardExpenses.where((entry) {
      return query.allowsCurrency(entry.currency) &&
          (query.startDate == null || !entry.date.isBefore(query.startDate!)) &&
          (query.endDate == null || !entry.date.isAfter(query.endDate!));
    }).toList(growable: false);
  }

  const pageSize = 1000;
  final client = ref.read(dashboardSupabaseClientProvider);
  final rows = <Map<String, dynamic>>[];
  try {
    DateTime? beforeDate;
    DateTime? beforeCreatedAt;
    String? beforeId;
    final seenCursors = <String>{};
    while (true) {
      final response = await client
          .rpc('get_home_mom_transactions_v2', params: <String, dynamic>{
        'p_user_id': query.userId,
        'p_start_date': query.formattedStartDate,
        'p_end_date': query.formattedEndDate,
        'p_before_date': beforeDate == null
            ? null
            : '${beforeDate.year.toString().padLeft(4, '0')}-'
                '${beforeDate.month.toString().padLeft(2, '0')}-'
                '${beforeDate.day.toString().padLeft(2, '0')}',
        'p_before_created_at': beforeCreatedAt?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': pageSize,
      });
      final pageRows = (response as List? ?? const <dynamic>[])
          .cast<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      rows.addAll(pageRows);
      if (pageRows.length < pageSize) break;

      final last = pageRows.last;
      beforeDate = DateTime.tryParse(last['date']?.toString() ?? '');
      beforeCreatedAt = DateTime.tryParse(last['created_at']?.toString() ?? '');
      beforeId = last['id']?.toString();
      if (beforeDate == null || beforeId == null || beforeId.isEmpty) {
        throw StateError('Home MoM RPC returned an invalid pagination cursor');
      }
      final cursor = '$beforeDate|$beforeCreatedAt|$beforeId';
      if (!seenCursors.add(cursor)) {
        throw StateError('Home MoM RPC pagination did not advance');
      }
    }
  } on PostgrestException catch (error) {
    if (error.code != 'PGRST202' && error.code != '42883') rethrow;
    rows.clear();
    final contactIds = <String>[];
    var contactOffset = 0;
    while (true) {
      final contactsResponse = await client
          .from('user_contacts')
          .select('id')
          .eq('user_id', query.userId)
          .order('id')
          .range(contactOffset, contactOffset + pageSize - 1);
      final contactPage = (contactsResponse as List? ?? const <dynamic>[])
          .cast<Map>()
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      contactIds.addAll(contactPage);
      if (contactPage.isEmpty) break;
      contactOffset += contactPage.length;
    }

    Future<void> fetchFallbackPageSet({List<String>? contacts}) async {
      var offset = 0;
      while (true) {
        dynamic fallback = client.from('expenses').select(
            'id,contact_id,user_id,household_id,date,amount_cents,currency,category,'
            'created_at,updated_at,raw_text,split_group_id,parent_recurring_id,'
            'scheduled_occurrence_date,recurring_confirmed_at,'
            'recurring_confirmation_source,bank_account_id,type,'
            'analytics_class,analytics_is_final,analytics_spending_multiplier,'
            'analytics_counts_toward_income,is_recurring');
        if (contacts == null) {
          fallback = fallback.eq('user_id', query.userId);
        } else {
          fallback = fallback.inFilter('contact_id', contacts);
        }
        fallback = fallback.isFilter('deleted_at', null);
        if (query.formattedStartDate != null) {
          fallback = fallback.gte('date', query.formattedStartDate!);
        }
        if (query.formattedEndDate != null) {
          fallback = fallback.lte('date', query.formattedEndDate!);
        }
        final response = await fallback
            .order('date', ascending: false)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + pageSize - 1);
        final pageRows = (response as List? ?? const <dynamic>[])
            .cast<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        rows.addAll(pageRows);
        if (pageRows.isEmpty) break;
        offset += pageRows.length;
      }
    }

    await fetchFallbackPageSet();
    const contactChunkSize = 200;
    for (var start = 0; start < contactIds.length; start += contactChunkSize) {
      final end = start + contactChunkSize < contactIds.length
          ? start + contactChunkSize
          : contactIds.length;
      await fetchFallbackPageSet(contacts: contactIds.sublist(start, end));
    }
  }

  final entriesById = <String, ExpenseEntry>{};
  for (final row in rows) {
    final entry = ExpenseEntry.fromJson(row);
    if (!query.allowsCurrency(entry.currency)) continue;
    if (entry.isRecurring || entry.splitGroupId?.trim().isNotEmpty == true) {
      continue;
    }
    entriesById[entry.id] = entry;
  }
  final entries = entriesById.values.toList(growable: false)
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      final byCreated = b.createdAt.compareTo(a.createdAt);
      if (byCreated != 0) return byCreated;
      return b.id.compareTo(a.id);
    });
  return entries;
}

Future<_DashboardFetchResult<T>> _loadCurrentDashboardGeneration<T>({
  required _DashboardRequestCoordinator coordinator,
  required _DashboardRequestGeneration generation,
  required bool Function() isActive,
  required Future<T> Function() load,
  required Future<void> Function(T value) persist,
}) {
  return coordinator.run<T>(
    generation: generation,
    isActive: isActive,
    load: load,
    persist: persist,
  );
}

final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSnapshotSummary, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(localTransactionRevisionProvider);
    final dashboardRefresh = ref.watch(dashboardRefreshSignalProvider);
    final transactionsRefresh =
        ref.watch(transactionsFeedRefreshSignalProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    if (query.userId.isEmpty) {
      return const DashboardSnapshotSummary.empty();
    }

    final cacheKey = dashboardSummarySqliteCacheKey(query);
    final generation = _dashboardRequestGeneration(
      cacheKey: cacheKey,
      dashboardRefresh: dashboardRefresh,
      transactionsRefresh: transactionsRefresh,
    );
    final coordinator = ref.read(dashboardRequestCoordinatorProvider);
    MonekoDatabase? database;
    DashboardSqliteCache? cache;
    DashboardCachedValue<DashboardSnapshotSummary>? cached;
    var hasLocalDatabaseMutation = false;
    try {
      final resolvedDatabase = await ref.watch(localDatabaseProvider.future);
      database = resolvedDatabase;
      cache = DashboardSqliteCache(resolvedDatabase);
      cached = await cache.readSummary(query);
      final cachedSnapshot = cached;
      if (cachedSnapshot != null) {
        final reconciled =
            await resolvedDatabase.getSyncedTransactionsChangedSince(
          userId: query.userId,
          householdId: query.householdId,
          changedAfter: cachedSnapshot.cachedAt,
        );
        if (reconciled.isNotEmpty) cached = null;
      }
      final pendingFuture = _dashboardPendingLocalTransactions(
        resolvedDatabase,
        query,
        pageSize: 1,
        allPages: false,
      );
      final deletedIdsFuture = _dashboardLocalTombstoneIds(
        resolvedDatabase,
        query,
      );
      final pendingUpdateIdsFuture =
          _dashboardPendingUpdateIds(resolvedDatabase);
      final pending = await pendingFuture;
      final deletedIds = await deletedIdsFuture;
      final pendingUpdateIds = await pendingUpdateIdsFuture;
      hasLocalDatabaseMutation = pending.isNotEmpty ||
          deletedIds.isNotEmpty ||
          pendingUpdateIds.isNotEmpty;
      if (hasLocalDatabaseMutation) cached = null;
    } catch (_) {
      database = null;
      cache = null;
    }
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const DashboardSnapshotSummary.empty();
    }

    final hasPendingOverlay = hasLocalDatabaseMutation ||
        ref.read(dashboardLocalOverlayTransactionsProvider(query)).isNotEmpty;
    Future<_DashboardFetchResult<DashboardSnapshotSummary>> loadFresh() {
      return _loadCurrentDashboardGeneration(
        coordinator: coordinator,
        generation: generation,
        isActive: () =>
            !disposed && _dashboardRequestUserIsCurrent(ref, query.userId),
        load: () => _loadDashboardSummary(
          ref,
          query,
          remoteOnly: cached != null,
        ),
        persist: (value) async {
          final localCache = cache;
          final localDatabase = database;
          if (localCache == null ||
              localDatabase == null ||
              (cached == null && hasPendingOverlay)) {
            return;
          }
          final pending = await _dashboardPendingLocalTransactions(
            localDatabase,
            query,
            pageSize: 1,
            allPages: false,
          );
          final deletedIds =
              await _dashboardLocalTombstoneIds(localDatabase, query);
          final pendingUpdateIds =
              await _dashboardPendingUpdateIds(localDatabase);
          if (pending.isNotEmpty ||
              deletedIds.isNotEmpty ||
              pendingUpdateIds.isNotEmpty) {
            return;
          }
          await localCache.writeSummary(query, value);
        },
      );
    }

    if (cached != null) {
      if (!coordinator.isFresh(generation)) {
        unawaited(() async {
          try {
            final result = await loadFresh();
            if (!disposed &&
                _dashboardRequestUserIsCurrent(ref, query.userId) &&
                result.persisted) {
              ref.invalidateSelf();
            }
          } catch (error) {
            if (!disposed) {
              ref
                  .read(dashboardRefreshMetadataProvider(cacheKey).notifier)
                  .state = DashboardRefreshMetadata(
                isFromCache: true,
                error: error,
              );
            }
          }
        }());
      }
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(
        isRefreshing: !coordinator.isFresh(generation),
        isFromCache: true,
        lastRefreshedAt: cached.cachedAt,
      );
      return cached.value;
    }

    final result = await loadFresh();
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const DashboardSnapshotSummary.empty();
    }
    if (!disposed) {
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(lastRefreshedAt: DateTime.now());
    }
    return result.value;
  },
);

final dashboardRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, DashboardRecentTransactionsRequest>(
  (ref, request) async {
    ref.watch(localTransactionRevisionProvider);
    final dashboardRefresh = ref.watch(dashboardRefreshSignalProvider);
    final transactionsRefresh =
        ref.watch(transactionsFeedRefreshSignalProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    if (request.query.userId.isEmpty) return const <ExpenseEntry>[];

    final cacheKey = dashboardRecentSqliteCacheKey(request);
    final generation = _dashboardRequestGeneration(
      cacheKey: cacheKey,
      dashboardRefresh: dashboardRefresh,
      transactionsRefresh: transactionsRefresh,
    );
    final coordinator = ref.read(dashboardRequestCoordinatorProvider);
    MonekoDatabase? database;
    DashboardSqliteCache? cache;
    DashboardCachedValue<List<ExpenseEntry>>? cached;
    try {
      final resolvedDatabase = await ref.watch(localDatabaseProvider.future);
      database = resolvedDatabase;
      cache = DashboardSqliteCache(resolvedDatabase);
      cached = await cache.readRecent(request);
      final cachedSnapshot = cached;
      if (cachedSnapshot != null) {
        final reconciledFuture =
            resolvedDatabase.getSyncedTransactionsChangedSince(
          userId: request.query.userId,
          householdId: request.query.householdId,
          changedAfter: cachedSnapshot.cachedAt,
          includeAllHouseholds: request.query.householdId == null,
        );
        final pendingFuture = _dashboardPendingLocalTransactions(
          database,
          request.query,
          pageSize: request.limit,
          allPages: false,
        );
        final deletedIdsFuture = _dashboardLocalTombstoneIds(
          database,
          request.query,
        );
        final pendingUpdateIdsFuture = _dashboardPendingUpdateIds(database);
        final pending = await pendingFuture;
        final deletedIds = await deletedIdsFuture;
        final pendingUpdateIds = await pendingUpdateIdsFuture;
        final reconciled = await reconciledFuture;
        cached = DashboardCachedValue<List<ExpenseEntry>>(
          value: mergeDashboardTransactionsWithLocalOverlay(
            base: cachedSnapshot.value,
            localOverlay: <ExpenseEntry>[...pending, ...reconciled],
            query: request.query,
            limit: request.limit,
            deletedIds: deletedIds,
            hiddenBaseIds: <String>{
              ...pendingUpdateIds,
              ...reconciled.map((entry) => entry.id),
            },
          ),
          cachedAt: cachedSnapshot.cachedAt,
        );
      }
    } catch (_) {
      cache = null;
    }
    if (disposed ||
        !_dashboardRequestUserIsCurrent(ref, request.query.userId)) {
      return const <ExpenseEntry>[];
    }

    Future<_DashboardFetchResult<_DashboardTransactionLoad>> loadFresh() {
      return _loadCurrentDashboardGeneration(
        coordinator: coordinator,
        generation: generation,
        isActive: () =>
            !disposed &&
            _dashboardRequestUserIsCurrent(ref, request.query.userId),
        load: () async {
          final pending = await _dashboardPendingLocalTransactions(
            database,
            request.query,
            pageSize: request.limit,
            allPages: false,
          );
          final deletedIds = await _dashboardLocalTombstoneIds(
            database,
            request.query,
          );
          final pendingUpdateIds = await _dashboardPendingUpdateIds(database);
          final expandedRequest = DashboardRecentTransactionsRequest(
            query: request.query,
            limit: request.limit + pending.length + pendingUpdateIds.length,
          );
          final base = await _loadDashboardRecentTransactions(
            ref,
            expandedRequest,
            remoteOnly: cached != null,
          );
          return _DashboardTransactionLoad(
            visible: mergeDashboardTransactionsWithLocalOverlay(
              base: base,
              localOverlay: pending,
              query: request.query,
              limit: request.limit,
              deletedIds: deletedIds,
              hiddenBaseIds: pendingUpdateIds,
            ),
            confirmedBase: base,
            invalidIdsAtLoad: <String>{
              ...pending.map((entry) => entry.id),
              ...deletedIds,
              ...pendingUpdateIds,
            },
          );
        },
        persist: (value) async {
          final localCache = cache;
          if (localCache == null) return;
          final deletedIds = await _dashboardLocalTombstoneIds(
            database,
            request.query,
          );
          final pendingUpdateIds = await _dashboardPendingUpdateIds(database);
          final invalidIds = <String>{
            ...value.invalidIdsAtLoad,
            ...deletedIds,
            ...pendingUpdateIds,
          };
          final confirmed = value.confirmedBase
              .where((entry) => !invalidIds.contains(entry.id))
              .take(request.limit)
              .toList(growable: false);
          await localCache.writeRecent(request, confirmed);
        },
      );
    }

    if (cached != null) {
      if (!coordinator.isFresh(generation)) {
        unawaited(() async {
          try {
            final result = await loadFresh();
            if (!disposed &&
                _dashboardRequestUserIsCurrent(ref, request.query.userId) &&
                result.persisted) {
              ref.invalidateSelf();
            }
          } catch (error) {
            if (!disposed) {
              ref
                  .read(dashboardRefreshMetadataProvider(cacheKey).notifier)
                  .state = DashboardRefreshMetadata(
                isFromCache: true,
                error: error,
              );
            }
          }
        }());
      }
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(
        isRefreshing: !coordinator.isFresh(generation),
        isFromCache: true,
        lastRefreshedAt: cached.cachedAt,
      );
      return cached.value;
    }

    final result = await loadFresh();
    if (disposed ||
        !_dashboardRequestUserIsCurrent(ref, request.query.userId)) {
      return const <ExpenseEntry>[];
    }
    if (!disposed) {
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(lastRefreshedAt: DateTime.now());
    }
    return result.value.visible;
  },
);

final dashboardCalendarTransactionsProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntry>, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(localTransactionRevisionProvider);
    final dashboardRefresh = ref.watch(dashboardRefreshSignalProvider);
    final transactionsRefresh =
        ref.watch(transactionsFeedRefreshSignalProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    if (query.userId.isEmpty) return const <ExpenseEntry>[];

    final cacheKey = dashboardCalendarSqliteCacheKey(query);
    final generation = _dashboardRequestGeneration(
      cacheKey: cacheKey,
      dashboardRefresh: dashboardRefresh,
      transactionsRefresh: transactionsRefresh,
    );
    final coordinator = ref.read(dashboardRequestCoordinatorProvider);
    MonekoDatabase? database;
    DashboardSqliteCache? cache;
    DashboardCachedValue<List<ExpenseEntry>>? cached;
    try {
      final resolvedDatabase = await ref.watch(localDatabaseProvider.future);
      database = resolvedDatabase;
      cache = DashboardSqliteCache(resolvedDatabase);
      cached = await cache.readCalendar(query);
      final cachedSnapshot = cached;
      if (cachedSnapshot != null) {
        final reconciledFuture =
            resolvedDatabase.getSyncedTransactionsChangedSince(
          userId: query.userId,
          householdId: query.householdId,
          changedAfter: cachedSnapshot.cachedAt,
          includeAllHouseholds: query.householdId == null,
        );
        final pendingFuture = _dashboardPendingLocalTransactions(
          database,
          query,
          pageSize: 500,
          allPages: true,
        );
        final deletedIdsFuture = _dashboardLocalTombstoneIds(database, query);
        final pendingUpdateIdsFuture = _dashboardPendingUpdateIds(database);
        final pending = await pendingFuture;
        final deletedIds = await deletedIdsFuture;
        final pendingUpdateIds = await pendingUpdateIdsFuture;
        final reconciled = await reconciledFuture;
        cached = DashboardCachedValue<List<ExpenseEntry>>(
          value: mergeDashboardTransactionsWithLocalOverlay(
            base: cachedSnapshot.value,
            localOverlay: <ExpenseEntry>[...pending, ...reconciled],
            query: query,
            deletedIds: deletedIds,
            hiddenBaseIds: <String>{
              ...pendingUpdateIds,
              ...reconciled.map((entry) => entry.id),
            },
          ),
          cachedAt: cachedSnapshot.cachedAt,
        );
      }
    } catch (_) {
      cache = null;
    }
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const <ExpenseEntry>[];
    }

    Future<_DashboardFetchResult<_DashboardTransactionLoad>> loadFresh() {
      return _loadCurrentDashboardGeneration(
        coordinator: coordinator,
        generation: generation,
        isActive: () =>
            !disposed && _dashboardRequestUserIsCurrent(ref, query.userId),
        load: () async {
          final base = await _loadDashboardCalendarTransactions(
            ref,
            query,
            remoteOnly: cached != null,
          );
          final pending = await _dashboardPendingLocalTransactions(
            database,
            query,
            pageSize: 500,
            allPages: true,
          );
          final deletedIds = await _dashboardLocalTombstoneIds(database, query);
          final pendingUpdateIds = await _dashboardPendingUpdateIds(database);
          return _DashboardTransactionLoad(
            visible: mergeDashboardTransactionsWithLocalOverlay(
              base: base,
              localOverlay: pending,
              query: query,
              deletedIds: deletedIds,
              hiddenBaseIds: pendingUpdateIds,
            ),
            confirmedBase: base,
            invalidIdsAtLoad: <String>{
              ...pending.map((entry) => entry.id),
              ...deletedIds,
              ...pendingUpdateIds,
            },
          );
        },
        persist: (value) async {
          final localCache = cache;
          if (localCache == null) return;
          final deletedIds = await _dashboardLocalTombstoneIds(database, query);
          final pendingUpdateIds = await _dashboardPendingUpdateIds(database);
          final invalidIds = <String>{
            ...value.invalidIdsAtLoad,
            ...deletedIds,
            ...pendingUpdateIds,
          };
          final confirmed = value.confirmedBase
              .where((entry) => !invalidIds.contains(entry.id))
              .toList(growable: false);
          await localCache.writeCalendar(query, confirmed);
        },
      );
    }

    if (cached != null) {
      if (!coordinator.isFresh(generation)) {
        unawaited(() async {
          try {
            final result = await loadFresh();
            if (!disposed &&
                _dashboardRequestUserIsCurrent(ref, query.userId) &&
                result.persisted) {
              ref.invalidateSelf();
            }
          } catch (error) {
            if (!disposed) {
              ref
                  .read(dashboardRefreshMetadataProvider(cacheKey).notifier)
                  .state = DashboardRefreshMetadata(
                isFromCache: true,
                error: error,
              );
            }
          }
        }());
      }
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(
        isRefreshing: !coordinator.isFresh(generation),
        isFromCache: true,
        lastRefreshedAt: cached.cachedAt,
      );
      return cached.value;
    }

    final result = await loadFresh();
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const <ExpenseEntry>[];
    }
    if (!disposed) {
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(lastRefreshedAt: DateTime.now());
    }
    return result.value.visible;
  },
);

final dashboardOwnedRangeTransactionsProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntry>, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(localTransactionRevisionProvider);
    final dashboardRefresh = ref.watch(dashboardRefreshSignalProvider);
    final transactionsRefresh =
        ref.watch(transactionsFeedRefreshSignalProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    if (query.userId.isEmpty ||
        query.startDate == null ||
        query.endDate == null) {
      return const <ExpenseEntry>[];
    }

    final cacheKey = dashboardOwnedRangeSqliteCacheKey(query);
    final generation = _dashboardRequestGeneration(
      cacheKey: cacheKey,
      dashboardRefresh: dashboardRefresh,
      transactionsRefresh: transactionsRefresh,
    );
    final coordinator = ref.read(dashboardRequestCoordinatorProvider);
    MonekoDatabase? database;
    DashboardSqliteCache? cache;
    DashboardCachedValue<List<ExpenseEntry>>? cached;
    try {
      final resolvedDatabase = await ref.watch(localDatabaseProvider.future);
      database = resolvedDatabase;
      cache = DashboardSqliteCache(resolvedDatabase);
      cached = await cache.readOwnedRange(query);
      final cachedSnapshot = cached;
      if (cachedSnapshot != null) {
        final reconciledFuture =
            resolvedDatabase.getSyncedTransactionsChangedSince(
          userId: query.userId,
          changedAfter: cachedSnapshot.cachedAt,
          includeAllHouseholds: true,
        );
        final pendingFuture = resolvedDatabase.getPendingOwnedTransactions(
          userId: query.userId,
          startDate: query.startDate!,
          endDate: query.endDate!,
          currency: query.normalizedCurrency,
        );
        final deletedIdsFuture = _dashboardLocalTombstoneIds(
          resolvedDatabase,
          query,
          includeAllHouseholds: true,
        );
        final pendingUpdateIdsFuture =
            _dashboardPendingUpdateIds(resolvedDatabase);
        final pending = await pendingFuture;
        final deletedIds = await deletedIdsFuture;
        final pendingUpdateIds = await pendingUpdateIdsFuture;
        final reconciled = await reconciledFuture;
        cached = DashboardCachedValue<List<ExpenseEntry>>(
          value: mergeDashboardTransactionsWithLocalOverlay(
            base: cachedSnapshot.value,
            localOverlay: <ExpenseEntry>[...pending, ...reconciled],
            query: query,
            matchHousehold: false,
            deletedIds: deletedIds,
            hiddenBaseIds: <String>{
              ...pendingUpdateIds,
              ...reconciled.map((entry) => entry.id),
            },
          ),
          cachedAt: cachedSnapshot.cachedAt,
        );
      }
    } catch (_) {
      cache = null;
    }
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const <ExpenseEntry>[];
    }

    Future<_DashboardFetchResult<_DashboardTransactionLoad>> loadFresh() {
      return _loadCurrentDashboardGeneration(
        coordinator: coordinator,
        generation: generation,
        isActive: () =>
            !disposed && _dashboardRequestUserIsCurrent(ref, query.userId),
        load: () async {
          final base = await _loadDashboardOwnedRangeTransactions(ref, query);
          final localDatabase = database;
          final pending = localDatabase == null
              ? const <ExpenseEntry>[]
              : await localDatabase.getPendingOwnedTransactions(
                  userId: query.userId,
                  startDate: query.startDate!,
                  endDate: query.endDate!,
                  currency: query.normalizedCurrency,
                );
          final deletedIds = await _dashboardLocalTombstoneIds(
            localDatabase,
            query,
            includeAllHouseholds: true,
          );
          final pendingUpdateIds =
              await _dashboardPendingUpdateIds(localDatabase);
          return _DashboardTransactionLoad(
            visible: mergeDashboardTransactionsWithLocalOverlay(
              base: base,
              localOverlay: pending,
              query: query,
              matchHousehold: false,
              deletedIds: deletedIds,
              hiddenBaseIds: pendingUpdateIds,
            ),
            confirmedBase: base,
            invalidIdsAtLoad: <String>{
              ...pending.map((entry) => entry.id),
              ...deletedIds,
              ...pendingUpdateIds,
            },
          );
        },
        persist: (value) async {
          final localCache = cache;
          if (localCache == null) return;
          final deletedIds = await _dashboardLocalTombstoneIds(
            database,
            query,
            includeAllHouseholds: true,
          );
          final pendingUpdateIds = await _dashboardPendingUpdateIds(database);
          final invalidIds = <String>{
            ...value.invalidIdsAtLoad,
            ...deletedIds,
            ...pendingUpdateIds,
          };
          final confirmed = value.confirmedBase
              .where((entry) => !invalidIds.contains(entry.id))
              .toList(growable: false);
          await localCache.writeOwnedRange(query, confirmed);
        },
      );
    }

    if (cached != null) {
      if (!coordinator.isFresh(generation)) {
        unawaited(() async {
          try {
            final result = await loadFresh();
            if (!disposed &&
                _dashboardRequestUserIsCurrent(ref, query.userId) &&
                result.persisted) {
              ref.invalidateSelf();
            }
          } catch (error) {
            if (!disposed) {
              ref
                  .read(dashboardRefreshMetadataProvider(cacheKey).notifier)
                  .state = DashboardRefreshMetadata(
                isFromCache: true,
                error: error,
              );
            }
          }
        }());
      }
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(
        isRefreshing: !coordinator.isFresh(generation),
        isFromCache: true,
        lastRefreshedAt: cached.cachedAt,
      );
      return cached.value;
    }

    final result = await loadFresh();
    if (disposed || !_dashboardRequestUserIsCurrent(ref, query.userId)) {
      return const <ExpenseEntry>[];
    }
    if (!disposed) {
      ref.read(dashboardRefreshMetadataProvider(cacheKey).notifier).state =
          DashboardRefreshMetadata(lastRefreshedAt: DateTime.now());
    }
    return result.value.visible;
  },
);
