import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_sqlite_cache.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');

  void switchTo(String uid) {
    state = AppUser(uid: uid, email: '$uid@example.com');
  }
}

ExpenseEntry _entry(
  String id,
  DateTime date, {
  int amountCents = 1000,
  String currency = 'USD',
  String? userId,
  String? category,
  String? rawText,
  String? merchant,
  String? clientRecordId,
  String? clientMutationId,
  String? idempotencyKey,
}) =>
    ExpenseEntry(
      id: id,
      userId: userId,
      date: date,
      amountCents: amountCents,
      createdAt: date,
      type: 'expense',
      category: category ?? 'food',
      currency: currency,
      rawText: rawText,
      merchant: merchant,
      clientRecordId: clientRecordId,
      clientMutationId: clientMutationId,
      idempotencyKey: idempotencyKey,
    );

class _FakeTransactionsFeedService extends TransactionsFeedService {
  _FakeTransactionsFeedService({
    List<ExpenseEntry>? allPageEntries,
    List<ExpenseEntry>? pageEntries,
  })  : pageEntries = pageEntries ??
            <ExpenseEntry>[_entry('recent', DateTime(2026, 4, 2))],
        allPageEntries = allPageEntries ??
            <ExpenseEntry>[_entry('range', DateTime(2026, 4, 3))];

  final List<ExpenseEntry> allPageEntries;
  final List<ExpenseEntry> pageEntries;
  Completer<TransactionsFeedPageResult>? pageCompleter;
  int pageCallCount = 0;
  TransactionsFeedQuery? lastSummaryQuery;
  TransactionsFeedQuery? lastPageQuery;
  TransactionsFeedQuery? lastAllPagesQuery;
  late final TransactionsFeedSummary summary = TransactionsFeedSummary(
      transactionCount: 2,
      expenseTotal: 20,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: const <TransactionsFeedCategorySummary>[],
      yearlyPeriodTotals: const <DateTime, double>{},
      periodTotals: <DateTime, double>{DateTime(2026, 4, 1): 20});

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    lastPageQuery = query;
    pageCallCount += 1;
    final completer = pageCompleter;
    if (completer != null) return completer.future;
    return TransactionsFeedPageResult(
      items: pageEntries,
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    lastAllPagesQuery = query;
    return allPageEntries;
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    lastSummaryQuery = query;
    return summary;
  }
}

class _SequencedTransactionsFeedService extends _FakeTransactionsFeedService {
  _SequencedTransactionsFeedService(this.completers);

  final List<Completer<TransactionsFeedPageResult>> completers;

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) {
    lastPageQuery = query;
    final index = pageCallCount;
    pageCallCount += 1;
    return completers[index].future;
  }
}

void main() {
  setUp(clearDashboardSessionCache);

  DashboardScopeQuery buildQuery() => const DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        selectedCurrencies: ['USD', 'EUR'],
        startDate: null,
        endDate: null,
      );

  test(
      'dashboard query identity includes display currency for aggregate caches',
      () {
    final usdPrimary = buildQuery();
    final eurPrimary = buildQuery().copyWith(
      selectedCurrency: 'EUR',
      selectedCurrencies: const ['eur', 'usd'],
    );

    expect(usdPrimary, isNot(eurPrimary));
    expect(usdPrimary.hashCode, isNot(eurPrimary.hashCode));
  });

  test('dashboardSummaryProvider delegates single currency to summary service',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final summary = await container.read(
      dashboardSummaryProvider(
        buildQuery().copyWith(selectedCurrencies: const ['USD']),
      ).future,
    );

    expect(summary.expenseTotal, 20);
    expect(service.lastSummaryQuery?.selectedCurrency, 'USD');
    expect(service.lastSummaryQuery?.selectedCurrencies, ['USD']);
    expect(service.lastSummaryQuery?.summaryIntervalGranularity, isNull);
  });

  test('dashboardSummaryProvider converts selected currencies before summing',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _FakeTransactionsFeedService(allPageEntries: [
      _entry('range-usd', DateTime(2026, 4, 3)),
      _entry('range-eur', DateTime(2026, 4, 4), currency: 'EUR'),
    ]);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      currencyRateTableProvider.overrideWith(
        (ref) async => const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 0.5},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final summary =
        await container.read(dashboardSummaryProvider(buildQuery()).future);

    expect(summary.expenseTotal, 30);
    expect(summary.hasMultipleCurrencies, isTrue);
    expect(service.lastAllPagesQuery?.selectedCurrencies, ['EUR', 'USD']);
    expect(service.lastSummaryQuery, isNull);
  });

  test('dashboardRecentTransactionsProvider requests local-first limited page',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardRecentTransactionsProvider(
        DashboardRecentTransactionsRequest(query: buildQuery(), limit: 5),
      ).future,
    );

    expect(result.single.id, 'recent');
    expect(service.lastPageQuery?.pageSize, 5);
    expect(service.lastPageQuery?.selectedCurrencies, ['EUR', 'USD']);
  });

  test('household dashboard overlay excludes confirmed server rows', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const householdId = '00000000-0000-0000-0000-000000000001';
    final notifier =
        container.read(householdOptimisticExpensesProvider.notifier);
    notifier.addExpense(
      householdId,
      _entry(
        'server-confirmed',
        DateTime(2026, 7, 18),
        userId: 'member-2',
      ).copyWith(householdId: householdId),
    );
    notifier.addExpense(
      householdId,
      _entry(
        'optimistic_local-create',
        DateTime(2026, 7, 18),
        userId: 'user-1',
      ).copyWith(householdId: householdId),
    );

    final overlay = container.read(
      dashboardLocalOverlayTransactionsProvider(
        const DashboardScopeQuery(
          userId: 'user-1',
          householdId: householdId,
          selectedCurrency: 'USD',
          selectedCurrencies: ['USD'],
          startDate: null,
          endDate: null,
        ),
      ),
    );

    expect(overlay.map((entry) => entry.id), ['optimistic_local-create']);
  });

  test(
      'recent provider hydrates SQLite snapshot before remote refresh finishes',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    await DashboardSqliteCache(database).writeRecent(
      request,
      [_entry('cached', DateTime(2026, 4, 1), currency: 'EUR')],
    );
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    container.listen(
      dashboardRecentTransactionsProvider(request),
      (_, __) {},
    );
    final result = await container
        .read(dashboardRecentTransactionsProvider(request).future)
        .timeout(const Duration(seconds: 1));

    expect(result.single.id, 'cached');
    expect(result.single.currency, 'EUR');
    await Future<void>.delayed(Duration.zero);
    expect(service.pageCallCount, 1);

    service.pageCompleter!.complete(
      TransactionsFeedPageResult(
        items: [_entry('fresh', DateTime(2026, 4, 2), currency: 'USD')],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('cached recent snapshot is merged with pending SQLite mutations',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    await DashboardSqliteCache(database).writeRecent(
      request,
      [_entry('cached', DateTime(2026, 4, 1), userId: 'user-1')],
    );
    final optimistic = _entry(
      'optimistic_queued',
      DateTime(2026, 4, 3),
      userId: 'user-1',
      clientMutationId: 'mobile:optimistic_queued',
      idempotencyKey: 'mobile:optimistic_queued',
    );
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:optimistic_queued',
      operation: 'save-expense',
      payload: const <String, dynamic>{},
    );
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );

    expect(result.map((entry) => entry.id), [
      'optimistic_queued',
      'cached',
    ]);
    service.pageCompleter!.complete(
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('cached recent snapshot keeps a newly reconciled synced update visible',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery().copyWith(selectedCurrencies: const ['USD']),
      limit: 5,
    );
    final original = _entry(
      'server-update',
      DateTime(2026, 7, 10),
      userId: 'user-1',
      amountCents: 1000,
    );
    await DashboardSqliteCache(
      database,
      now: () => DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    ).writeRecent(request, <ExpenseEntry>[original]);
    final reconciled = original.copyWith(
      amountCents: 2500,
      updatedAt: DateTime.utc(2026, 7, 10, 9),
    );
    await database.upsertTransactions(<ExpenseEntry>[reconciled]);
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final visible = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );

    expect(visible.single.id, reconciled.id);
    expect(visible.single.amountCents, 2500);
    service.pageCompleter!.complete(
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('cached household snapshot reconciles another member synced update',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    const householdId = '00000000-0000-0000-0000-000000000001';
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery().copyWith(
        householdId: householdId,
        selectedCurrencies: const ['USD'],
      ),
      limit: 5,
    );
    final original = _entry(
      'shared-update',
      DateTime(2026, 7, 10),
      userId: 'member-2',
      amountCents: 1000,
    ).copyWith(householdId: householdId);
    await DashboardSqliteCache(
      database,
      now: () => DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    ).writeRecent(request, <ExpenseEntry>[original]);
    await database.upsertTransactions(<ExpenseEntry>[
      original.copyWith(
        amountCents: 4200,
        updatedAt: DateTime.utc(2026, 7, 10, 9),
      ),
    ]);
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final visible = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );

    expect(visible.single.id, original.id);
    expect(visible.single.amountCents, 4200);
    service.pageCompleter!.complete(
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('cached recent snapshot cannot resurrect a locally deleted row',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    final deleted = _entry(
      'deleted-locally',
      DateTime(2026, 4, 3),
      userId: 'user-1',
    );
    await DashboardSqliteCache(database).writeRecent(request, <ExpenseEntry>[
      deleted,
    ]);
    await database.writeOptimisticTransactionDelete(
      entries: <ExpenseEntry>[deleted],
      clientMutationId: 'mobile:delete:deleted-locally',
      actingUserId: 'user-1',
      payload: const <String, dynamic>{},
    );
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );

    expect(result, isEmpty);
    service.pageCompleter!.complete(
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('cached row is hidden when a queued update moves it out of scope',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery().copyWith(selectedCurrencies: const ['USD']),
      limit: 5,
    );
    final original = _entry(
      'updated-locally',
      DateTime(2026, 4, 3),
      userId: 'user-1',
      currency: 'USD',
    );
    final updated = original.copyWith(currency: 'EUR');
    await DashboardSqliteCache(database).writeRecent(
      request,
      <ExpenseEntry>[original],
    );
    await database.writeOptimisticTransactionUpdate(
      originalEntry: original,
      updatedEntry: updated,
      clientMutationId: 'mobile:update:updated-locally',
      payload: const <String, dynamic>{},
    );
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
      transactionsRemoteFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );

    expect(result, isEmpty);
    service.pageCompleter!.complete(
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    );
  });

  test('recent snapshot persists the full confirmed limit, not merged optimism',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    final pending = _entry(
      'optimistic_pending',
      DateTime(2026, 4, 10),
      userId: 'user-1',
      clientMutationId: 'mobile:optimistic_pending',
      idempotencyKey: 'mobile:optimistic_pending',
    );
    await database.writeOptimisticTransaction(
      entry: pending,
      clientMutationId: 'mobile:optimistic_pending',
      operation: 'save-expense',
      payload: const <String, dynamic>{},
    );
    final confirmed = List<ExpenseEntry>.generate(
      5,
      (index) => _entry(
        'confirmed-$index',
        DateTime(2026, 4, 9 - index),
        userId: 'user-1',
      ),
    );
    final service = _FakeTransactionsFeedService(
      pageEntries: <ExpenseEntry>[pending, ...confirmed],
    );
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final visible = await container.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    final persisted = await DashboardSqliteCache(database).readRecent(request);

    expect(visible, hasLength(5));
    expect(visible.first.id, pending.id);
    expect(service.lastPageQuery?.pageSize, 6);
    expect(persisted, isNotNull);
    expect(persisted!.value, hasLength(5));
    expect(persisted.value.map((entry) => entry.id),
        confirmed.map((entry) => entry.id));
  });

  test('three rapid generations can only persist the newest response',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    final completers = List.generate(
      3,
      (_) => Completer<TransactionsFeedPageResult>(),
    );
    final service = _SequencedTransactionsFeedService(completers);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    container.listen(
      dashboardRecentTransactionsProvider(request),
      (_, __) {},
    );
    final first = container.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await Future<void>.delayed(Duration.zero);
    container.read(dashboardRefreshSignalProvider.notifier).state += 1;
    final second = container.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await Future<void>.delayed(Duration.zero);
    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    final third = container.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.pageCallCount, 3);
    completers[2].complete(
      TransactionsFeedPageResult(
        items: [_entry('newest', DateTime(2026, 4, 3), userId: 'user-1')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    expect((await third).single.id, 'newest');
    completers[1].complete(
      TransactionsFeedPageResult(
        items: [_entry('middle', DateTime(2026, 4, 2), userId: 'user-1')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    completers[0].complete(
      TransactionsFeedPageResult(
        items: [_entry('oldest', DateTime(2026, 4, 1), userId: 'user-1')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    await second;
    await first;
    final cached = await DashboardSqliteCache(database).readRecent(request);

    expect(cached, isNotNull);
    expect(cached!.value.single.id, 'newest');
  });

  test('an auth switch cannot return or persist the previous user response',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    final service = _FakeTransactionsFeedService()
      ..pageCompleter = Completer<TransactionsFeedPageResult>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final pending = container.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await Future<void>.delayed(Duration.zero);
    (container.read(authProvider.notifier) as _TestAuth).switchTo('user-2');
    service.pageCompleter!.complete(
      TransactionsFeedPageResult(
        items: [_entry('old-user-row', DateTime(2026, 4, 1))],
        hasMore: false,
        nextCursor: null,
      ),
    );

    expect(await pending, isEmpty);
    expect(await DashboardSqliteCache(database).readRecent(request), isNull);
  });

  test('request deduplication is isolated to one ProviderContainer', () async {
    final request = DashboardRecentTransactionsRequest(
      query: buildQuery(),
      limit: 5,
    );
    final firstDatabase = MonekoDatabase.inMemory();
    final secondDatabase = MonekoDatabase.inMemory();
    addTearDown(firstDatabase.close);
    addTearDown(secondDatabase.close);
    await DashboardSqliteCache(firstDatabase).writeRecent(
      request,
      [_entry('cached', DateTime(2026, 4, 1), userId: 'user-1')],
    );
    await DashboardSqliteCache(secondDatabase).writeRecent(
      request,
      [_entry('cached', DateTime(2026, 4, 1), userId: 'user-1')],
    );
    final firstService = _FakeTransactionsFeedService();
    final secondService = _FakeTransactionsFeedService();
    final firstContainer = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => firstDatabase),
      transactionsFeedServiceProvider.overrideWithValue(firstService),
      transactionsRemoteFeedServiceProvider.overrideWithValue(firstService),
    ]);
    final secondContainer = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => secondDatabase),
      transactionsFeedServiceProvider.overrideWithValue(secondService),
      transactionsRemoteFeedServiceProvider.overrideWithValue(secondService),
    ]);
    addTearDown(firstContainer.dispose);
    addTearDown(secondContainer.dispose);

    await firstContainer.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await secondContainer.read(
      dashboardRecentTransactionsProvider(request).future,
    );
    await Future<void>.delayed(Duration.zero);

    expect(firstService.pageCallCount, 1);
    expect(secondService.pageCallCount, 1);
  });

  test('dashboardCalendarTransactionsProvider fetches local-first all pages',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardCalendarTransactionsProvider(buildQuery()).future,
    );

    expect(result.single.id, 'range');
    expect(service.lastAllPagesQuery?.selectedCurrency, 'USD');
    expect(service.lastAllPagesQuery?.selectedCurrencies, ['EUR', 'USD']);
  });

  test('owned MoM range paginates beyond the PostgREST max_rows cap', () async {
    final requestedCursors = <String?>[];
    final client = SupabaseClient(
      'https://example.test',
      'anon-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/rest/v1/rpc/get_home_mom_transactions_v2'),
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final beforeId = body['p_before_id'] as String?;
        requestedCursors.add(beforeId);
        final rowCount = beforeId == null ? 1000 : 1;
        final firstId = beforeId == null ? 0 : 1000;
        final rows = List<Map<String, dynamic>>.generate(
          rowCount,
          (index) => <String, dynamic>{
            'id': '00000000-0000-0000-0000-'
                '${(firstId + index).toString().padLeft(12, '0')}',
            'user_id': 'user-1',
            'household_id': null,
            'date': '2026-07-10',
            'amount_cents': 100,
            'currency': 'USD',
            'category': 'food',
            'created_at': '2026-07-10T12:00:00.000Z',
            'updated_at': '2026-07-10T12:00:00.000Z',
            'bank_account_id': 'bank-account-1',
            'type': 'expense',
            'analytics_class': 'transfer_out',
            'analytics_is_final': true,
            'analytics_spending_multiplier': 0,
            'analytics_counts_toward_income': false,
            'is_recurring': false,
          },
        );
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      dashboardSupabaseClientProvider.overrideWithValue(client),
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final query = DashboardScopeQuery(
      userId: 'user-1',
      householdId: null,
      selectedCurrency: 'USD',
      selectedCurrencies: const ['USD'],
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 7, 31),
    );

    container.listen(
      dashboardOwnedRangeTransactionsProvider(query),
      (_, __) {},
    );
    final rows = await container.read(
      dashboardOwnedRangeTransactionsProvider(query).future,
    );

    expect(rows, hasLength(1001));
    expect(requestedCursors, [null, isNotNull]);
    expect(rows.first.bankAccountId, 'bank-account-1');
    expect(rows.first.analyticsClass, 'transfer_out');
    expect(rows.first.analyticsIsFinal, isTrue);
    expect(rows.first.spendingEffect, 0);
  });

  test('owned MoM RPC preserves the complete Plaid economic matrix', () async {
    final classes = <(String, bool, int, bool)>[
      ('consumer_spend', true, 1, false),
      ('refund_or_reversal', true, -1, false),
      ('transfer_in', true, 0, false),
      ('transfer_out', true, 0, false),
      ('debt_payment', true, 0, false),
      ('bank_fee', true, 0, false),
      ('cash_movement', true, 0, false),
      ('loan_disbursement', true, 0, false),
      ('income', true, 0, true),
      ('unknown', true, 0, false),
      ('consumer_spend', false, 0, false),
    ];
    final client = SupabaseClient(
      'https://example.test',
      'anon-key',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/rest/v1/rpc/get_home_mom_transactions_v2'),
        );
        final rows = <Map<String, dynamic>>[
          for (var index = 0; index < classes.length; index++)
            <String, dynamic>{
              'id': '00000000-0000-0000-0000-'
                  '${index.toString().padLeft(12, '0')}',
              'user_id': 'user-1',
              'date': '2026-07-10',
              'amount_cents': 100,
              'currency': 'USD',
              'category': 'test',
              'created_at': '2026-07-10T12:00:00.000Z',
              'updated_at': '2026-07-10T12:00:00.000Z',
              'bank_account_id': 'bank-account-1',
              'type': classes[index].$4 ? 'income' : 'expense',
              'analytics_class': classes[index].$1,
              'analytics_is_final': classes[index].$2,
              'analytics_spending_multiplier': classes[index].$3,
              'analytics_counts_toward_income': classes[index].$4,
              'is_recurring': false,
            },
        ];
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      dashboardSupabaseClientProvider.overrideWithValue(client),
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    addTearDown(container.dispose);
    final query = DashboardScopeQuery(
      userId: 'user-1',
      householdId: null,
      selectedCurrency: 'USD',
      selectedCurrencies: const ['USD'],
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 7, 31),
    );

    container.listen(
      dashboardOwnedRangeTransactionsProvider(query),
      (_, __) {},
    );
    final rows = await container.read(
      dashboardOwnedRangeTransactionsProvider(query).future,
    );
    final totals = calculateMomTrend(
      actualTransactions: rows,
      recurringTransactions: const [],
      now: DateTime(2026, 7, 20),
      financialMonthStartDay: 1,
      selectedCurrency: 'USD',
    );

    expect(rows, hasLength(classes.length));
    expect(rows.where((row) => row.isProviderPending), hasLength(1));
    expect(rows.where((row) => row.countsTowardIncome), hasLength(1));
    expect(
      rows.map((row) => row.effectiveSpendingMultiplier).toList(),
      containsAll(<int>[1, -1, 0]),
    );
    expect(totals['2026-07-01'], 0);
  });

  test(
      'mergeDashboardTransactionsWithLocalOverlay collapses a saved row with its stale optimistic row',
      () {
    final date = DateTime(2026, 4, 3);
    final query = buildQuery().copyWith(selectedCurrencies: const ['USD']);
    final optimistic = _entry(
      'optimistic_1',
      date,
      userId: 'user-1',
      amountCents: 1299,
      category: 'food',
      rawText: 'coffee',
    );
    final saved = _entry(
      'server_1',
      date,
      userId: 'user-1',
      amountCents: 1299,
      category: 'cafes',
      merchant: 'Coffee Shop',
      clientRecordId: optimistic.id,
      clientMutationId: 'mobile:${optimistic.id}',
      idempotencyKey: 'mobile:${optimistic.id}',
    );

    final merged = mergeDashboardTransactionsWithLocalOverlay(
      base: [optimistic],
      localOverlay: [saved],
      query: query,
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, 'server_1');
  });

  test('mergeDashboardTransactionsWithLocalOverlay keeps distinct server rows',
      () {
    final date = DateTime(2026, 4, 3);
    final query = buildQuery().copyWith(selectedCurrencies: const ['USD']);
    final first = _entry(
      'server_1',
      date,
      userId: 'user-1',
      amountCents: 1299,
      rawText: 'coffee',
    );
    final second = _entry(
      'server_2',
      date,
      userId: 'user-1',
      amountCents: 1299,
      rawText: 'coffee',
    );

    final merged = mergeDashboardTransactionsWithLocalOverlay(
      base: [second],
      localOverlay: [first],
      query: query,
    );

    expect(merged.map((entry) => entry.id), ['server_1', 'server_2']);
  });
}
