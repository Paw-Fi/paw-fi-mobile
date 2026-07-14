import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';

const int dashboardSqliteCacheSchemaVersion = 2;
const String dashboardSqliteCacheNamespace = 'home_dashboard_snapshot';
const Duration dashboardSqliteSnapshotMaxAge = Duration(days: 2);
const int dashboardSqliteSnapshotMaxEntries = 96;

typedef DashboardCacheClock = DateTime Function();

class DashboardCachedValue<T> {
  const DashboardCachedValue({
    required this.value,
    required this.cachedAt,
  });

  final T value;
  final DateTime cachedAt;
}

String dashboardSummarySqliteCacheKey(DashboardScopeQuery query) {
  return '${_dashboardScopeCachePrefix(query)}:summary';
}

String dashboardCalendarSqliteCacheKey(DashboardScopeQuery query) {
  return '${_dashboardScopeCachePrefix(query)}:calendar';
}

String dashboardOwnedRangeSqliteCacheKey(DashboardScopeQuery query) {
  return '${_dashboardScopeCachePrefix(query)}:owned-range';
}

String dashboardRecentSqliteCacheKey(
  DashboardRecentTransactionsRequest request,
) {
  return '${_dashboardScopeCachePrefix(request.query)}:recent:${request.limit}';
}

String _dashboardScopeCachePrefix(DashboardScopeQuery query) {
  final currencies = query.normalizedCurrencies?.join(',') ?? '<none>';
  return [
    'u=${_cacheComponent(query.userId)}',
    'v$dashboardSqliteCacheSchemaVersion',
    's=${_cacheComponent(query.householdId ?? 'personal')}',
    'base=${_cacheComponent(query.normalizedCurrency ?? '<none>')}',
    'currencies=${_cacheComponent(currencies)}',
    'from=${_cacheComponent(query.formattedStartDate ?? '<none>')}',
    'to=${_cacheComponent(query.formattedEndDate ?? '<none>')}',
    'interval=${_cacheComponent(query.normalizedIntervalGranularity ?? '<none>')}',
  ].join(':');
}

String _dashboardUserCachePrefix(String userId) {
  return 'u=${_cacheComponent(userId)}:';
}

String _cacheComponent(String value) => Uri.encodeComponent(value.trim());

class DashboardSqliteCache {
  DashboardSqliteCache(
    this._database, {
    DashboardCacheClock? now,
  }) : _now = now ?? DateTime.now;

  final MonekoDatabase _database;
  final DashboardCacheClock _now;

  Future<DashboardCachedValue<DashboardSnapshotSummary>?> readSummary(
    DashboardScopeQuery query,
  ) async {
    final key = dashboardSummarySqliteCacheKey(query);
    final cached = await _readPayload(key, query);
    if (cached == null) return null;
    final value = cached.value['value'];
    if (value is! Map) return null;
    try {
      return DashboardCachedValue(
        value: DashboardSnapshotSummary.fromJson(
          Map<String, dynamic>.from(value),
        ),
        cachedAt: cached.cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSummary(
    DashboardScopeQuery query,
    DashboardSnapshotSummary summary,
  ) {
    final key = dashboardSummarySqliteCacheKey(query);
    return _writePayload(
      key: key,
      query: query,
      value: summary.toJson(),
    );
  }

  Future<DashboardCachedValue<List<ExpenseEntry>>?> readRecent(
    DashboardRecentTransactionsRequest request,
  ) {
    return _readTransactions(
      dashboardRecentSqliteCacheKey(request),
      request.query,
    );
  }

  Future<void> writeRecent(
    DashboardRecentTransactionsRequest request,
    List<ExpenseEntry> entries,
  ) {
    return _writePayload(
      key: dashboardRecentSqliteCacheKey(request),
      query: request.query,
      value: entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<DashboardCachedValue<List<ExpenseEntry>>?> readCalendar(
    DashboardScopeQuery query,
  ) {
    return _readTransactions(dashboardCalendarSqliteCacheKey(query), query);
  }

  Future<void> writeCalendar(
    DashboardScopeQuery query,
    List<ExpenseEntry> entries,
  ) {
    return _writePayload(
      key: dashboardCalendarSqliteCacheKey(query),
      query: query,
      value: entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<DashboardCachedValue<List<ExpenseEntry>>?> readOwnedRange(
    DashboardScopeQuery query,
  ) {
    return _readTransactions(dashboardOwnedRangeSqliteCacheKey(query), query);
  }

  Future<void> writeOwnedRange(
    DashboardScopeQuery query,
    List<ExpenseEntry> entries,
  ) {
    return _writePayload(
      key: dashboardOwnedRangeSqliteCacheKey(query),
      query: query,
      value: entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<void> clearUser(String userId) async {
    final encodedUser = Uri.encodeComponent(userId.trim());
    await Future.wait(<Future<void>>[
      _database.deleteJsonCacheByPrefix(
        namespace: dashboardSqliteCacheNamespace,
        cacheKeyPrefix: _dashboardUserCachePrefix(userId),
      ),
      _database.deleteJsonCacheByPrefix(
        namespace: 'household_home_split_snapshot',
        cacheKeyPrefix: 'u=$encodedUser:',
      ),
    ]);
  }

  Future<DashboardCachedValue<List<ExpenseEntry>>?> _readTransactions(
    String key,
    DashboardScopeQuery query,
  ) async {
    final cached = await _readPayload(key, query);
    if (cached == null) return null;
    final value = cached.value['value'];
    if (value is! List) return null;
    try {
      final entries = value
          .cast<Map>()
          .map(
            (row) => ExpenseEntry.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return DashboardCachedValue(value: entries, cachedAt: cached.cachedAt);
    } catch (_) {
      return null;
    }
  }

  Future<DashboardCachedValue<Map<String, dynamic>>?> _readPayload(
    String key,
    DashboardScopeQuery query,
  ) async {
    final entry = await _database.getJsonCache(
      namespace: dashboardSqliteCacheNamespace,
      cacheKey: key,
    );
    if (entry == null) return null;
    final age = _now().toUtc().difference(entry.cachedAt.toUtc());
    if (age > dashboardSqliteSnapshotMaxAge) return null;
    final payload = entry.payload;
    final cachedCurrencies = (payload['currencies'] as List?)
        ?.map((value) => value.toString())
        .toList(growable: false);
    if (payload['schema_version'] != dashboardSqliteCacheSchemaVersion ||
        payload['complete'] != true ||
        payload['cache_key'] != key ||
        payload['user_id'] != query.userId ||
        payload['household_id'] != query.householdId ||
        payload['base_currency'] != query.normalizedCurrency ||
        !_stringListsEqual(cachedCurrencies, query.normalizedCurrencies) ||
        payload['start_date'] != query.formattedStartDate ||
        payload['end_date'] != query.formattedEndDate ||
        payload['interval_granularity'] !=
            query.normalizedIntervalGranularity) {
      return null;
    }
    return DashboardCachedValue(value: payload, cachedAt: entry.cachedAt);
  }

  Future<void> _writePayload({
    required String key,
    required DashboardScopeQuery query,
    required Object value,
  }) async {
    final cachedAt = _now().toUtc();
    await _database.upsertJsonCache(
      namespace: dashboardSqliteCacheNamespace,
      cacheKey: key,
      cachedAt: cachedAt,
      payload: {
        'schema_version': dashboardSqliteCacheSchemaVersion,
        'complete': true,
        'cache_key': key,
        'user_id': query.userId,
        'household_id': query.householdId,
        'base_currency': query.normalizedCurrency,
        'currencies': query.normalizedCurrencies,
        'start_date': query.formattedStartDate,
        'end_date': query.formattedEndDate,
        'interval_granularity': query.normalizedIntervalGranularity,
        'value': value,
      },
    );
    await _database.pruneJsonCacheNamespace(
      namespace: dashboardSqliteCacheNamespace,
      maxEntries: dashboardSqliteSnapshotMaxEntries,
      olderThan: cachedAt.subtract(dashboardSqliteSnapshotMaxAge),
    );
  }
}

bool _stringListsEqual(List<String>? left, List<String>? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
