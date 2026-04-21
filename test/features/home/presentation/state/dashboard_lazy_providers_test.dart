import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';

ExpenseEntry _entry(String id, DateTime date) => ExpenseEntry(
      id: id,
      date: date,
      amountCents: 1000,
      createdAt: date,
      type: 'expense',
      category: 'food',
      currency: 'USD',
    );

class _FakeDashboardDataService implements DashboardDataService {
  DashboardScopeQuery? lastSummaryQuery;
  DashboardRecentTransactionsRequest? lastRecentRequest;
  DashboardScopeQuery? lastCalendarQuery;

  @override
  Future<DashboardSnapshotSummary> fetchSnapshot(
      DashboardScopeQuery query) async {
    lastSummaryQuery = query;
    return DashboardSnapshotSummary(
      transactionCount: 2,
      expenseTotal: 20,
      incomeTotal: 0,
      hasMultipleCurrencies: false,
      categorySummaries: <DashboardCategorySummary>[],
      periodTotals: <DateTime, double>{DateTime(2026, 4, 1): 20},
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchRecentTransactions(
    DashboardRecentTransactionsRequest request,
  ) async {
    lastRecentRequest = request;
    return [_entry('recent', DateTime(2026, 4, 2))];
  }

  @override
  Future<List<ExpenseEntry>> fetchCalendarTransactions(
    DashboardScopeQuery query,
  ) async {
    lastCalendarQuery = query;
    return [_entry('range', DateTime(2026, 4, 3))];
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
    final service = _FakeDashboardDataService();
    final container = ProviderContainer(overrides: [
      dashboardDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final summary =
        await container.read(dashboardSummaryProvider(buildQuery()).future);

    expect(summary.expenseTotal, 20);
    expect(service.lastSummaryQuery, buildQuery());
  });

  test('dashboardRecentTransactionsProvider requests limited first page',
      () async {
    final service = _FakeDashboardDataService();
    final container = ProviderContainer(overrides: [
      dashboardDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardRecentTransactionsProvider(
        DashboardRecentTransactionsRequest(query: buildQuery(), limit: 5),
      ).future,
    );

    expect(result.single.id, 'recent');
    expect(service.lastRecentRequest?.limit, 5);
  });

  test('dashboardCalendarTransactionsProvider fetches all pages for range',
      () async {
    final service = _FakeDashboardDataService();
    final container = ProviderContainer(overrides: [
      dashboardDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      dashboardCalendarTransactionsProvider(buildQuery()).future,
    );

    expect(result.single.id, 'range');
    expect(service.lastCalendarQuery, buildQuery());
  });
}
