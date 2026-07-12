import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_sqlite_cache.dart';

void main() {
  late MonekoDatabase database;
  late DateTime now;
  late DashboardSqliteCache cache;

  setUp(() {
    database = MonekoDatabase.inMemory();
    now = DateTime.utc(2026, 7, 10, 12);
    cache = DashboardSqliteCache(database, now: () => now);
  });

  tearDown(() async {
    await database.close();
  });

  DashboardScopeQuery query({
    String userId = 'user-1',
    String? householdId,
    String selectedCurrency = 'EUR',
    List<String>? selectedCurrencies = const ['USD', 'EUR'],
    DateTime? startDate,
    DateTime? endDate,
    String? intervalGranularity = 'monthly',
  }) {
    return DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      startDate: startDate ?? DateTime(2026, 7, 1),
      endDate: endDate ?? DateTime(2026, 7, 31),
      intervalGranularity: intervalGranularity,
    );
  }

  test('cache key is canonical but isolates every result dimension', () {
    final base = dashboardSummarySqliteCacheKey(query());

    expect(
      dashboardSummarySqliteCacheKey(
        query(selectedCurrencies: const ['eur', 'USD', 'EUR']),
      ),
      base,
    );
    expect(
      dashboardSummarySqliteCacheKey(query(userId: 'user-2')),
      isNot(base),
    );
    expect(
      dashboardSummarySqliteCacheKey(query(householdId: 'household-1')),
      isNot(base),
    );
    expect(
      dashboardSummarySqliteCacheKey(query(selectedCurrency: 'USD')),
      isNot(base),
    );
    expect(
      dashboardSummarySqliteCacheKey(
        query(startDate: DateTime(2026, 6, 1)),
      ),
      isNot(base),
    );
    expect(
      dashboardSummarySqliteCacheKey(
        query(endDate: DateTime(2026, 7, 30)),
      ),
      isNot(base),
    );
    expect(
      dashboardSummarySqliteCacheKey(query(intervalGranularity: 'daily')),
      isNot(base),
    );
    expect(
      dashboardRecentSqliteCacheKey(
        DashboardRecentTransactionsRequest(query: query(), limit: 5),
      ),
      isNot(
        dashboardRecentSqliteCacheKey(
          DashboardRecentTransactionsRequest(query: query(), limit: 10),
        ),
      ),
    );
    expect(dashboardCalendarSqliteCacheKey(query()), isNot(base));
    expect(dashboardOwnedRangeSqliteCacheKey(query()), isNot(base));
  });

  test('round trips a complete summary without changing financial values',
      () async {
    final summary = DashboardSnapshotSummary(
      transactionCount: 3,
      expenseTotal: 1056.79,
      incomeTotal: 3427.17,
      hasMultipleCurrencies: true,
      categorySummaries: const [
        DashboardCategorySummary(
          category: 'groceries',
          amount: 456.79,
          transactionCount: 2,
        ),
      ],
      periodTotals: {DateTime(2026, 7, 1): 1056.79},
    );

    await cache.writeSummary(query(), summary);
    final cached = await cache.readSummary(query());

    expect(cached, isNotNull);
    expect(cached!.value.transactionCount, summary.transactionCount);
    expect(cached.value.expenseTotal, summary.expenseTotal);
    expect(cached.value.incomeTotal, summary.incomeTotal);
    expect(
      cached.value.categorySummaries.single.amount,
      summary.categorySummaries.single.amount,
    );
    expect(cached.value.periodTotals, summary.periodTotals);
    expect(cached.cachedAt, now);
  });

  test('round trips recent rows in their exact native-currency order',
      () async {
    final request = DashboardRecentTransactionsRequest(query: query(), limit: 5);
    final rows = [
      ExpenseEntry(
        id: 'newest-usd',
        userId: 'user-1',
        userName: 'Alex',
        userAvatarUrl: 'https://example.test/alex.png',
        date: DateTime(2026, 7, 10),
        amountCents: 1299,
        currency: 'USD',
        category: 'groceries',
        createdAt: DateTime.utc(2026, 7, 10, 10),
        type: 'expense',
      ),
      ExpenseEntry(
        id: 'older-eur',
        userId: 'user-1',
        date: DateTime(2026, 7, 9),
        amountCents: 845,
        currency: 'EUR',
        category: 'transport',
        createdAt: DateTime.utc(2026, 7, 9, 10),
        type: 'expense',
      ),
    ];

    await cache.writeRecent(request, rows);
    final cached = await cache.readRecent(request);

    expect(cached, isNotNull);
    expect(cached!.value.map((row) => row.id), ['newest-usd', 'older-eur']);
    expect(cached.value.map((row) => row.currency), ['USD', 'EUR']);
    expect(cached.value.map((row) => row.amountCents), [1299, 845]);
    expect(cached.value.first.userName, 'Alex');
    expect(
      cached.value.first.userAvatarUrl,
      'https://example.test/alex.png',
    );
  });

  test('rejects expired, incomplete, and incompatible snapshots', () async {
    const summary = DashboardSnapshotSummary(
      transactionCount: 1,
      expenseTotal: 10,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: [],
      periodTotals: {},
    );
    final scope = query(selectedCurrencies: const ['EUR']);
    final key = dashboardSummarySqliteCacheKey(scope);

    await cache.writeSummary(scope, summary);
    now = now.add(dashboardSqliteSnapshotMaxAge + const Duration(seconds: 1));
    expect(await cache.readSummary(scope), isNull);

    now = DateTime.utc(2026, 7, 10, 12);
    await database.upsertJsonCache(
      namespace: dashboardSqliteCacheNamespace,
      cacheKey: key,
      cachedAt: now,
      payload: {
        'schema_version': dashboardSqliteCacheSchemaVersion,
        'complete': false,
        'cache_key': key,
        'value': summary.toJson(),
      },
    );
    expect(await cache.readSummary(scope), isNull);

    await database.upsertJsonCache(
      namespace: dashboardSqliteCacheNamespace,
      cacheKey: key,
      cachedAt: now,
      payload: {
        'schema_version': dashboardSqliteCacheSchemaVersion - 1,
        'complete': true,
        'cache_key': key,
        'value': summary.toJson(),
      },
    );
    expect(await cache.readSummary(scope), isNull);
  });

  test('clearing one user cannot remove another user snapshot', () async {
    const summary = DashboardSnapshotSummary(
      transactionCount: 1,
      expenseTotal: 10,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: [],
      periodTotals: {},
    );
    final firstUser = query(userId: 'user-1');
    final secondUser = query(userId: 'user-2');
    await cache.writeSummary(firstUser, summary);
    await cache.writeSummary(secondUser, summary);

    await cache.clearUser('user-1');

    expect(await cache.readSummary(firstUser), isNull);
    expect(await cache.readSummary(secondUser), isNotNull);
  });

  test('user cleanup removes every cache schema for that user only', () async {
    await database.upsertJsonCache(
      namespace: dashboardSqliteCacheNamespace,
      cacheKey: 'u=user-1:v999:future-schema',
      payload: const <String, dynamic>{'complete': true},
    );
    await database.upsertJsonCache(
      namespace: 'household_home_split_snapshot',
      cacheKey: 'u=user-1:v999:future-schema',
      payload: const <String, dynamic>{'complete': true},
    );
    await database.upsertJsonCache(
      namespace: 'household_home_split_snapshot',
      cacheKey: 'u=user-2:v999:future-schema',
      payload: const <String, dynamic>{'complete': true},
    );

    await cache.clearUser('user-1');

    expect(
      await database.getJsonCache(
        namespace: dashboardSqliteCacheNamespace,
        cacheKey: 'u=user-1:v999:future-schema',
      ),
      isNull,
    );
    expect(
      await database.getJsonCache(
        namespace: 'household_home_split_snapshot',
        cacheKey: 'u=user-1:v999:future-schema',
      ),
      isNull,
    );
    expect(
      await database.getJsonCache(
        namespace: 'household_home_split_snapshot',
        cacheKey: 'u=user-2:v999:future-schema',
      ),
      isNotNull,
    );
  });

  test('bounds the snapshot namespace instead of growing per range forever',
      () async {
    const summary = DashboardSnapshotSummary(
      transactionCount: 1,
      expenseTotal: 10,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: [],
      periodTotals: {},
    );
    final scopes = <DashboardScopeQuery>[];
    for (var index = 0;
        index < dashboardSqliteSnapshotMaxEntries + 1;
        index++) {
      final start = DateTime(2026, 1, 1).add(Duration(days: index));
      final scope = query(
        startDate: start,
        endDate: start,
        selectedCurrencies: const ['EUR'],
      );
      scopes.add(scope);
      now = now.add(const Duration(seconds: 1));
      await cache.writeSummary(scope, summary);
    }

    expect(await cache.readSummary(scopes.first), isNull);
    expect(await cache.readSummary(scopes.last), isNotNull);
  });
}
