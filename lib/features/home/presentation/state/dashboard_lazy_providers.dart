import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
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
  return entries.fold<double>(0, (sum, entry) {
    final type = (entry.type ?? 'expense').toLowerCase();
    if (type == 'income') return sum;
    return sum + entry.amount.abs();
  });
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
    final expenses = PreviewMockData.expenses.where((entry) {
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

Future<TransactionsFeedService> _dashboardTransactionFeedService(Ref ref) async {
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
    _homeSpendTrace('dashboard-feed-service source=remote-fallback error=$error');
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

final dashboardRefreshSignalProvider = StateProvider<int>((ref) => 0);

final dashboardLocalOverlayTransactionsProvider =
    Provider.family<List<ExpenseEntry>, DashboardScopeQuery>((ref, query) {
  final householdId = query.householdId?.trim();
  if (householdId == null || householdId.isEmpty) {
    final analyticsData = ref.watch(analyticsProvider);
    final localOnlyOverlay = analyticsData.expenses.where(
      _isDashboardLocalOverlayCandidate,
    );
    final overlay = mergeDashboardTransactionsWithLocalOverlay(
      base: const <ExpenseEntry>[],
      localOverlay: localOnlyOverlay,
      query: query,
    );
    _homeSpendTrace(
      'dashboard-overlay scope=personal analyticsCount=${analyticsData.expenses.length} '
      'overlayCount=${overlay.length} overlayTotal=${_traceAmount(_traceExpenseTotal(overlay))}',
    );
    return overlay;
  }

  final optimistic = ref.watch(
    householdOptimisticExpensesProvider.select(
      (state) => state[householdId] ?? const <ExpenseEntry>[],
    ),
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
    if (!_matchesDashboardQuery(entry, query)) return;
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

final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSnapshotSummary, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(transactionsFeedRefreshSignalProvider);
    final preview = ref.watch(previewModeProvider);
    if (preview.isActive) {
      return ref.watch(dashboardDataServiceProvider).fetchSnapshot(query);
    }

    final feedService = await _dashboardTransactionFeedService(ref);
    final feedQuery = dashboardTransactionsQuery(query);
    final selectedCurrencies = query.normalizedCurrencies;
    final hasMultiCurrencySelection =
        selectedCurrencies != null && selectedCurrencies.length > 1;

    // Transaction-backed dashboard summaries must be derived from the
    // local-first transaction feed on every provider evaluation. A second
    // dashboard-level session/prefs cache can lag behind SQLite after AI saves
    // and app restarts, briefly rendering stale totals before local hydration.
    return hasMultiCurrencySelection
        ? _dashboardSummaryFromTransactionsFeedSummary(
            summarizeTransactionsInCurrency(
              await feedService.fetchAllPages(feedQuery),
              targetCurrency: query.normalizedCurrency ?? 'USD',
              rates: await _dashboardCurrencyRates(
                ref.watch(currencyRateTableProvider.future),
              ),
              intervalGranularity:
                  query.normalizedIntervalGranularity ?? 'yearly',
            ),
          )
        : _dashboardSummaryFromTransactionsFeedSummary(
            await feedService.fetchSummary(feedQuery),
          );
  },
);

final dashboardRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, DashboardRecentTransactionsRequest>(
  (ref, request) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(transactionsFeedRefreshSignalProvider);
    final preview = ref.watch(previewModeProvider);
    if (preview.isActive) {
      return ref
          .watch(dashboardDataServiceProvider)
          .fetchRecentTransactions(request);
    }

    // Recent transaction rows are transaction-backed and must come directly
    // from the local-first feed. Reusing a separate dashboard cache can replay
    // stale rows after an optimistic save/reconciliation cycle.
    final feedService = await _dashboardTransactionFeedService(ref);
    final page = await feedService.fetchPage(
      dashboardTransactionsQuery(
        request.query,
        pageSize: request.limit,
      ),
    );
    return page.items;
  },
);

final dashboardCalendarTransactionsProvider =
    FutureProvider.autoDispose.family<List<ExpenseEntry>, DashboardScopeQuery>(
  (ref, query) async {
    ref.watch(dashboardRefreshSignalProvider);
    ref.watch(transactionsFeedRefreshSignalProvider);
    final preview = ref.watch(previewModeProvider);
    if (preview.isActive) {
      final entries = await ref
          .watch(dashboardDataServiceProvider)
          .fetchCalendarTransactions(query);
      _homeSpendTrace(
        'dashboard-calendar source=preview count=${entries.length} '
        'total=${_traceAmount(_traceExpenseTotal(entries))}',
      );
      return entries;
    }

    // Calendar/range transactions power the Home spending total. They must use
    // the local-first transaction feed as the single source of truth so a stale
    // dashboard session/prefs cache cannot show an old total on app restart or
    // during AI save reconciliation.
    final feedService = await _dashboardTransactionFeedService(ref);
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
  },
);
