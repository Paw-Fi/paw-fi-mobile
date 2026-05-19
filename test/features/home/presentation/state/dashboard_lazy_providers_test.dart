import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';

ExpenseEntry _entry(
  String id,
  DateTime date, {
  int amountCents = 1000,
  String currency = 'USD',
}) =>
    ExpenseEntry(
      id: id,
      date: date,
      amountCents: amountCents,
      createdAt: date,
      type: 'expense',
      category: 'food',
      currency: currency,
    );

class _FakeTransactionsFeedService extends TransactionsFeedService {
  _FakeTransactionsFeedService({List<ExpenseEntry>? allPageEntries})
      : allPageEntries = allPageEntries ??
            <ExpenseEntry>[_entry('range', DateTime(2026, 4, 3))];

  final List<ExpenseEntry> allPageEntries;
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

  test('dashboard query identity ignores primary when selected set is present',
      () {
    final usdPrimary = buildQuery();
    final eurPrimary = buildQuery().copyWith(
      selectedCurrency: 'EUR',
      selectedCurrencies: const ['eur', 'usd'],
    );

    expect(usdPrimary, eurPrimary);
    expect(usdPrimary.hashCode, eurPrimary.hashCode);
  });

  test('dashboardSummaryProvider delegates single currency to summary service',
      () async {
    final service = _FakeTransactionsFeedService();
    final container = ProviderContainer(overrides: [
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
    final service = _FakeTransactionsFeedService(allPageEntries: [
      _entry('range-usd', DateTime(2026, 4, 3)),
      _entry('range-eur', DateTime(2026, 4, 4), currency: 'EUR'),
    ]);
    final container = ProviderContainer(overrides: [
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
    expect(service.lastPageQuery?.selectedCurrencies, ['EUR', 'USD']);
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
    expect(service.lastAllPagesQuery?.selectedCurrencies, ['EUR', 'USD']);
  });
}
