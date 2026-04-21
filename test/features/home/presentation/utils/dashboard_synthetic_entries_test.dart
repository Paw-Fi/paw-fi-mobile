import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/utils/dashboard_synthetic_entries.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

void main() {
  test('buildSyntheticExpensesFromPeriodTotals creates sorted expense entries',
      () {
    final entries = buildSyntheticExpensesFromPeriodTotals(
      periodTotals: {
        DateTime(2026, 4, 2): 30.5,
        DateTime(2026, 4, 1): 10.0,
      },
      currency: 'USD',
    );

    expect(entries.map((entry) => entry.id).toList(), [
      'dashboard-period-2026-04-01T00:00:00.000',
      'dashboard-period-2026-04-02T00:00:00.000',
    ]);
    expect(entries.map((entry) => entry.amountCents).toList(), [1000, 3050]);
    expect(entries.every((entry) => entry.type == 'expense'), isTrue);
  });

  test('buildSyntheticExpensesFromCategorySummaries preserves category totals',
      () {
    final entries = buildSyntheticExpensesFromCategorySummaries(
      categorySummaries: const [
        DashboardCategorySummary(
          category: 'food',
          amount: 42.75,
          transactionCount: 2,
        ),
        DashboardCategorySummary(
          category: 'travel',
          amount: 10,
          transactionCount: 1,
        ),
      ],
      currency: 'EUR',
      anchorDate: DateTime(2026, 4, 10),
      householdId: 'household-1',
    );

    expect(entries.length, 2);
    expect(entries.first.category, 'food');
    expect(entries.first.amountCents, 4275);
    expect(entries.first.householdId, 'household-1');
    expect(entries.last.category, 'travel');
    expect(entries.last.amountCents, 1000);
  });

  test(
      'buildSyntheticNetCashflowTransactions creates current and previous income/expense rows',
      () {
    final entries = buildSyntheticNetCashflowTransactions(
      currency: 'USD',
      currentAnchorDate: DateTime(2026, 4, 10),
      previousAnchorDate: DateTime(2026, 3, 31),
      currentExpenseTotal: 80,
      currentIncomeTotal: 100,
      previousExpenseTotal: 50,
      previousIncomeTotal: 60,
    );

    expect(entries.map((entry) => entry.id).toList(), [
      'net-current-income',
      'net-current-expense',
      'net-previous-income',
      'net-previous-expense',
    ]);
    expect(entries.where((entry) => entry.type == 'income').length, 2);
    expect(entries.where((entry) => entry.type == 'expense').length, 2);
  });

  test('buildSyntheticExpensesFromHouseholdCategories preserves cents', () {
    final entries = buildSyntheticExpensesFromHouseholdCategories(
      categoryBreakdown: const [
        CategoryBreakdown(
          category: 'groceries',
          amountCents: 1234,
          percentage: 55,
          transactionCount: 2,
        ),
      ],
      currency: 'USD',
      anchorDate: DateTime(2026, 4, 12),
    );

    expect(entries.single.amountCents, 1234);
    expect(entries.single.category, 'groceries');
  });
}
