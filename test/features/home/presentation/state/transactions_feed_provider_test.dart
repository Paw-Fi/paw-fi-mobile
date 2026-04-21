import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
}
