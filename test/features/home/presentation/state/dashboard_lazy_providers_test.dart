import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
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

class _FakeTransactionsFeedService extends TransactionsFeedService {
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
    return TransactionsFeedPageResult(
      items: [_entry('recent', DateTime(2026, 4, 2))],
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    lastAllPagesQuery = query;
    return [_entry('range', DateTime(2026, 4, 3))];
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    lastSummaryQuery = query;
    return summary;
  }
}

void main() {
  DashboardScopeQuery buildQuery() => const DashboardScopeQuery(
        userId: 'user-1',
        householdId: null,
        selectedCurrency: 'USD',
        startDate: null,
        endDate: null,
      );

  test('dashboardSummaryProvider delegates to dashboard snapshot service',
      () async {
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final summary =
        await container.read(dashboardSummaryProvider(buildQuery()).future);

    expect(summary.expenseTotal, 20);
    expect(service.lastSummaryQuery?.selectedCurrency, 'USD');
    expect(service.lastSummaryQuery?.summaryIntervalGranularity, isNull);
  });

  test('dashboardRecentTransactionsProvider requests local-first limited page',
      () async {
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
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
  });

  test('dashboardCalendarTransactionsProvider fetches local-first all pages',
      () async {
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
      transactionsFeedServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardCalendarTransactionsProvider(buildQuery()).future,
    );

    expect(result.single.id, 'range');
    expect(service.lastAllPagesQuery?.selectedCurrency, 'USD');
  });
}
