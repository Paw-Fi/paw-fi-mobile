import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/domain/sync_status.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';

ExpenseEntry _entry(String id, DateTime date) => ExpenseEntry(
      id: id,
      date: date,
      amountCents: 1000,
      createdAt: date,
      type: 'expense',
      category: 'food',
      currency: 'USD',
    );

class _FakeTransactionsFeedService implements TransactionsFeedService {
  int summaryCallCount = 0;
  int pageCallCount = 0;
  int allPagesCallCount = 0;

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

  _FakeTransactionsFeedService(this.pages);

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    final pageIndex = pageCallCount;
    pageCallCount += 1;
    return pages[pageIndex];
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    allPagesCallCount += 1;
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
    summaryCallCount += 1;
    return summary;
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

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

  test('local-first feed service merges local rows into page and summary',
      () async {
    await database.insertLocalTransaction(
      id: 'local-tx-1',
      clientMutationId: 'mutation-1',
      userId: 'user-1',
      householdId: null,
      walletId: 'wallet-1',
      type: 'expense',
      amountCents: 1299,
      currency: 'USD',
      category: 'food',
      merchant: 'Cafe Nero',
      rawText: 'Lunch',
      description: 'Lunch',
      breakdownJson: '[]',
      dateYmd: '2026-04-30',
      createdAt: '2026-04-30T12:00:00.000Z',
      updatedAt: '2026-04-30T12:00:00.000Z',
      captureSource: 'aiText',
      syncStatus: SyncStatus.localOnly.name,
      reviewReasonsJson: '[]',
    );
    final remote = _FakeTransactionsFeedService([
      TransactionsFeedPageResult(
        items: [_entry('remote-tx-1', DateTime(2026, 4, 29))],
        hasMore: false,
        nextCursor: null,
      ),
    ]);
    remote.summary = const TransactionsFeedSummary(
      transactionCount: 1,
      expenseTotal: 10,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <TransactionsFeedCategorySummary>[
        TransactionsFeedCategorySummary(
          category: 'food',
          amount: 10,
          transactionCount: 1,
        ),
      ],
      yearlyPeriodTotals: <DateTime, double>{},
    );

    final service = LocalFirstTransactionsFeedService(
      remote: remote,
      database: database,
    );

    final query = buildQuery();
    final page = await service.fetchPage(query);
    final summary = await service.fetchSummary(query);
    final allItems = await service.fetchAllPages(query);

    expect(
      page.items.map((expense) => expense.id).toList(),
      ['local-tx-1', 'remote-tx-1'],
    );
    expect(
      allItems.map((expense) => expense.id).toList(),
      ['local-tx-1', 'remote-tx-1'],
    );
    expect(summary.transactionCount, 2);
    expect(summary.expenseTotal, closeTo(22.99, 0.001));
    expect(summary.categorySummaries.single.amount, closeTo(22.99, 0.001));
    expect(summary.categorySummaries.single.transactionCount, 2);
  });
}
