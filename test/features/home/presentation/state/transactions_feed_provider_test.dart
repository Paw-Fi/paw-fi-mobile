import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ExpenseEntry _entry(String id, DateTime date) => ExpenseEntry(
      id: id,
      userId: 'user-1',
      date: date,
      amountCents: 1000,
      createdAt: date,
      type: 'expense',
      category: 'food',
      currency: 'USD',
    );

class _FakeTransactionsFeedService extends TransactionsFeedService {
  int summaryCallCount = 0;
  int pageCallCount = 0;
  int allPagesCallCount = 0;
  final fetchedQueries = <TransactionsFeedQuery>[];

  TransactionsFeedSummary summary = const TransactionsFeedSummary(
    transactionCount: 3,
    expenseTotal: 30,
    incomeTotal: 0,
    hasMultipleCurrencies: false,
    categorySummaries: <TransactionsFeedCategorySummary>[
      TransactionsFeedCategorySummary(
        category: 'food',
        amount: 30,
        transactionCount: 3,
      ),
    ],
    yearlyPeriodTotals: <DateTime, double>{},
  );

  final List<TransactionsFeedPageResult> pages;
  final Object? allPagesError;

  _FakeTransactionsFeedService(this.pages, {this.allPagesError});

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    fetchedQueries.add(query);
    final pageIndex = pageCallCount;
    pageCallCount += 1;
    return pages[pageIndex];
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    allPagesCallCount += 1;
    if (allPagesError != null) throw allPagesError!;
    final items = <ExpenseEntry>[];
    for (final page in pages) {
      items.addAll(page.items);
      if (!page.hasMore) {
        break;
      }
    }
    return items;
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
      TransactionsFeedQuery query) async {
    fetchedQueries.add(query);
    summaryCallCount += 1;
    return summary;
  }
}

void main() {
  TransactionsFeedQuery buildQuery({String userId = 'user-1'}) {
    return TransactionsFeedQuery(
      userId: userId,
      householdId: null,
      selectedCurrency: 'USD',
      selectedCategory: null,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: null,
    );
  }

  test('query identity ignores primary currency when selected set is present',
      () {
    final usdPrimary = buildQuery().copyWith(
      selectedCurrency: 'USD',
      selectedCurrencies: const ['USD', 'EUR'],
    );
    final eurPrimary = buildQuery().copyWith(
      selectedCurrency: 'EUR',
      selectedCurrencies: const ['eur', 'usd'],
    );

    expect(usdPrimary, eurPrimary);
    expect(usdPrimary.hashCode, eurPrimary.hashCode);
  });

  test('bounded unfiltered pages use the analytics-aware RPC', () {
    final query = buildQuery().copyWith(
      startDate: DateTime(2025, 11, 1),
      endDate: DateTime(2026, 5, 31),
      selectedCurrencies: const ['USD', 'EUR'],
    );

    expect(
      transactionsPageRpcNameForTesting(query),
      'get_user_transactions_page_v5',
    );
  });

  test('filtered pages use the analytics-aware transaction RPC', () {
    final query = buildQuery().copyWith(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 31),
      selectedCategory: 'food',
    );

    expect(
      transactionsPageRpcNameForTesting(query),
      'get_user_transactions_page_v5',
    );
  });

  test('ranges over 800 days use the analytics-aware transaction RPC', () {
    final query = buildQuery().copyWith(
      startDate: DateTime(2023, 1, 1),
      endDate: DateTime(2026, 1, 1),
    );

    expect(
      transactionsPageRpcNameForTesting(query),
      'get_user_transactions_page_v5',
    );
  });

  test('transaction summaries use analytics-aware RPC', () {
    expect(
      transactionsSummaryRpcNameForTesting(),
      'get_user_transactions_summary_v2',
    );
  });

  test('loads summary and first page initially', () async {
    final service = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('a', DateTime(2026, 4, 2))],
        hasMore: true,
        nextCursor: TransactionsFeedCursor(
          date: DateTime(2026, 4, 2),
          createdAt: DateTime(2026, 4, 2, 10),
          id: 'a',
        ),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final query = buildQuery();
    await container
        .read(transactionsFeedProvider(query).notifier)
        .loadInitial();

    final state = container.read(transactionsFeedProvider(query));
    expect(service.summaryCallCount, 1);
    expect(service.pageCallCount, 1);
    expect(state.items.map((expense) => expense.id).toList(), ['a']);
    expect(state.summary.expenseTotal, 30);
    expect(state.hasMore, isTrue);
  });

  test('loadMore appends next page and preserves summary', () async {
    final service = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('a', DateTime(2026, 4, 2))],
        hasMore: true,
        nextCursor: TransactionsFeedCursor(
          date: DateTime(2026, 4, 2),
          createdAt: DateTime(2026, 4, 2, 10),
          id: 'a',
        ),
      ),
      TransactionsFeedPageResult(
        items: [_entry('b', DateTime(2026, 4, 1))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final query = buildQuery();
    final notifier = container.read(transactionsFeedProvider(query).notifier);
    await notifier.loadInitial();
    await notifier.loadMore();

    final state = container.read(transactionsFeedProvider(query));
    expect(state.items.map((expense) => expense.id).toList(), ['a', 'b']);
    expect(state.summary.expenseTotal, 30);
    expect(state.hasMore, isFalse);
  });

  test(
      'addingExpenses merges built-in category variants into canonical summary',
      () {
    final summary = const TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: 11,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <TransactionsFeedCategorySummary>[
        TransactionsFeedCategorySummary(
          category: 'takeout/delivery',
          amount: 11,
          transactionCount: 1,
        ),
      ],
      yearlyPeriodTotals: <DateTime, double>{},
    ).addingExpenses([
      ExpenseEntry(
        id: 'projected',
        date: DateTime(2026, 4, 4),
        amountCents: 2200,
        createdAt: DateTime(2026, 4, 4),
        category: 'Takeout / Delivery',
        type: 'expense',
        currency: 'USD',
      ),
      ExpenseEntry(
        id: 'custom',
        date: DateTime(2026, 4, 4),
        amountCents: 3300,
        createdAt: DateTime(2026, 4, 4),
        category: 'cat insurance',
        type: 'expense',
        currency: 'USD',
      ),
    ]);

    expect(summary.categorySummaries.map((entry) => entry.category), [
      'takeout & delivery',
      'cat insurance',
    ]);
    expect(summary.categorySummaries.first.amount, 33);
    expect(summary.categorySummaries.first.transactionCount, 2);
    expect(summary.categorySummaries.last.amount, 33);
    expect(summary.categorySummaries.last.transactionCount, 1);
  });

  test('empty user skips remote fetches', () async {
    final service = _FakeTransactionsFeedService(const []);
    final container = ProviderContainer(
      overrides: [
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final query = buildQuery(userId: '');
    await container
        .read(transactionsFeedProvider(query).notifier)
        .loadInitial();

    final state = container.read(transactionsFeedProvider(query));
    expect(service.summaryCallCount, 0);
    expect(service.pageCallCount, 0);
    expect(state.items, isEmpty);
    expect(state.summary.expenseTotal, 0);
  });

  test('refresh reloads summary and first page', () async {
    final service = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('a', DateTime(2026, 4, 2))],
        hasMore: false,
        nextCursor: null,
      ),
      TransactionsFeedPageResult(
        items: [_entry('b', DateTime(2026, 4, 1))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final query = buildQuery();
    final notifier = container.read(transactionsFeedProvider(query).notifier);
    await notifier.loadInitial();
    await notifier.refresh();

    final state = container.read(transactionsFeedProvider(query));
    expect(service.summaryCallCount, 2);
    expect(service.pageCallCount, 2);
    expect(state.items.map((expense) => expense.id).toList(), ['b']);
  });

  test('all items provider fetches every page and reacts to refresh signal',
      () async {
    final service = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('a', DateTime(2026, 4, 2))],
        hasMore: true,
        nextCursor: TransactionsFeedCursor(
          date: DateTime(2026, 4, 2),
          createdAt: DateTime(2026, 4, 2, 10),
          id: 'a',
        ),
      ),
      TransactionsFeedPageResult(
        items: [_entry('b', DateTime(2026, 4, 1))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final query = buildQuery();
    final initialItems =
        await container.read(transactionsFeedAllItemsProvider(query).future);

    expect(initialItems.map((expense) => expense.id).toList(), ['a', 'b']);
    expect(service.allPagesCallCount, 1);

    service.pages
      ..clear()
      ..add(
        TransactionsFeedPageResult(
          items: [_entry('c', DateTime(2026, 4, 3))],
          hasMore: false,
          nextCursor: null,
        ),
      );
    container.read(transactionsFeedRefreshSignalProvider.notifier).state++;

    final refreshedItems =
        await container.read(transactionsFeedAllItemsProvider(query).future);

    expect(refreshedItems.map((expense) => expense.id).toList(), ['c']);
    expect(service.allPagesCallCount, 2);
  });

  test('local-first service returns cached page before remote', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'local_1',
        userId: 'user-1',
        date: DateTime(2026, 4, 4),
        amountCents: 1100,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 4, 10),
        type: 'expense',
      ),
    ]);
    final remote = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('remote_1', DateTime(2026, 4, 5))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    remote.summary = const TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: 22,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <TransactionsFeedCategorySummary>[
        TransactionsFeedCategorySummary(
          category: 'food',
          amount: 22,
          transactionCount: 1,
        ),
      ],
      yearlyPeriodTotals: <DateTime, double>{},
    );
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    final query = buildQuery();
    final page = await service.fetchPage(query);
    final summary = await service.fetchSummary(query);
    final allItems = await service.fetchAllPages(query);

    expect(page.items.map((entry) => entry.id), ['local_1']);
    expect(summary.transactionCount, 1);
    expect(summary.expenseTotal, 22);
    expect(allItems.map((entry) => entry.id), ['remote_1']);
    expect(remote.pageCallCount, 0);
    expect(remote.summaryCallCount, 1);
    expect(remote.allPagesCallCount, 1);

    await service.refreshFromRemote(query);

    final refreshed = await service.fetchPage(query);
    expect(remote.pageCallCount, 1);
    expect(remote.summaryCallCount, 2);
    expect(refreshed.items.map((entry) => entry.id), ['remote_1']);
  });

  test('local-first service merges pending rows into remote all-pages history',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final pending = ExpenseEntry(
      id: 'pending_1',
      userId: 'user-1',
      date: DateTime(2026, 4, 6),
      amountCents: 1100,
      currency: 'USD',
      category: 'food',
      createdAt: DateTime.utc(2026, 4, 6, 10),
      type: 'expense',
    );
    await database.writeOptimisticTransaction(
      entry: pending,
      clientMutationId: 'mutation-1',
      operation: 'create',
      payload: {'id': pending.id},
    );
    final remote = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('remote_1', DateTime(2026, 4, 5))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    remote.summary = const TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: 22,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <TransactionsFeedCategorySummary>[
        TransactionsFeedCategorySummary(
          category: 'food',
          amount: 22,
          transactionCount: 1,
        ),
      ],
      yearlyPeriodTotals: <DateTime, double>{},
    );
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    final query = buildQuery();
    final summary = await service.fetchSummary(query);
    final allItems = await service.fetchAllPages(query);

    expect(summary.transactionCount, 2);
    expect(summary.expenseTotal, 33);
    expect(allItems.map((entry) => entry.id), ['pending_1', 'remote_1']);
    expect(remote.summaryCallCount, 1);
    expect(remote.allPagesCallCount, 1);
  });

  test('local-first summary keeps optimistic deletes out of totals', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final deleted = _entry('deleted_1', DateTime(2026, 4, 5));
    await database.upsertTransactions([deleted]);
    await database.writeOptimisticTransactionDelete(
      entries: [deleted],
      clientMutationId: 'delete-mutation-1',
      payload: {'id': deleted.id},
    );
    final remote = _FakeTransactionsFeedService(const []);
    remote.summary = const TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: 10,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <TransactionsFeedCategorySummary>[],
      yearlyPeriodTotals: <DateTime, double>{},
    );
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    final summary = await service.fetchSummary(buildQuery());

    expect(summary.transactionCount, 0);
    expect(summary.expenseTotal, 0);
    expect(remote.summaryCallCount, 0);
  });

  test('local-first service does not hide remote authorization failures',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions([
      _entry('cached-household-row', DateTime(2026, 4, 5)),
    ]);
    final remote = _FakeTransactionsFeedService(
      const <TransactionsFeedPageResult>[],
      allPagesError: const PostgrestException(
        message: 'Unauthorized household bounded transaction access',
        code: '42501',
      ),
    );
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    await expectLater(
      service.fetchAllPages(buildQuery()),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          '42501',
        ),
      ),
    );
  });

  test('local-first service removes synced local rows missing from remote page',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'stale_deleted',
        userId: 'user-1',
        date: DateTime(2026, 4, 4),
        amountCents: 1100,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime.utc(2026, 4, 4, 10),
        type: 'expense',
      ),
    ]);
    final remote = _FakeTransactionsFeedService([
      const TransactionsFeedPageResult(
        items: <ExpenseEntry>[],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    remote.summary = const TransactionsFeedSummary.empty();
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    await service.refreshFromRemote(buildQuery());

    final rows = await database.getRecentTransactions(
      userId: 'user-1',
      householdId: null,
      limit: 20,
    );
    expect(rows, isEmpty);
  });

  test('local-first service falls back to remote when cache is empty',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final remote = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('remote_1', DateTime(2026, 4, 5))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    final service = LocalFirstTransactionsFeedService(
      database: database,
      remote: remote,
    );

    final page = await service.fetchPage(buildQuery());
    final cached = await database.getRecentTransactions(
      userId: 'user-1',
      householdId: null,
      limit: 10,
    );

    expect(page.items.map((entry) => entry.id), ['remote_1']);
    expect(remote.pageCallCount, 1);
    expect(cached.map((entry) => entry.id), ['remote_1']);
  });
}
