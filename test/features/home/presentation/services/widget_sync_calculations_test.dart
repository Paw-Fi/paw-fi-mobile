import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_calculations.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

ExpenseEntry _entry({
  required String id,
  required int amountCents,
  required String type,
  String? category,
}) {
  return ExpenseEntry(
    id: id,
    userId: 'user-1',
    date: DateTime(2026, 4, 12),
    amountCents: amountCents,
    currency: 'USD',
    category: category,
    type: type,
    createdAt: DateTime(2026, 4, 12),
  );
}

void main() {
  test('widget this-month range matches dashboard thisMonth filter', () {
    final range = buildWidgetThisMonthRange(DateTime(2026, 4, 29, 18, 45));

    expect(range['from'], DateTime(2026, 4, 1));
    expect(range['to'], DateTime(2026, 4, 29));
  });

  test('widget spending total matches dashboard cards', () {
    final entries = [
      _entry(
        id: 'expense-negative',
        amountCents: -1250,
        type: 'expense',
        category: 'food',
      ),
      _entry(
        id: 'expense-positive',
        amountCents: 500,
        type: 'expense',
        category: 'transport',
      ),
      _entry(
        id: 'income',
        amountCents: 3000,
        type: 'income',
        category: 'salary',
      ),
    ];

    expect(calculateWidgetSpentCents(entries), 1750);
  });

  test('widget category totals match dashboard category widgets', () {
    final entries = [
      _entry(
        id: 'food-1',
        amountCents: -1250,
        type: 'expense',
        category: 'food',
      ),
      _entry(
        id: 'food-2',
        amountCents: 500,
        type: 'expense',
        category: 'food',
      ),
      _entry(
        id: 'income',
        amountCents: 3000,
        type: 'income',
        category: 'salary',
      ),
    ];

    expect(calculateWidgetCategorySpentCents(entries), {'food': 1750});
  });

  test('personal widget scope matches personal home dashboard scope', () {
    expect(
      widgetSourceHouseholdIds(
        scopeId: 'personal',
        portfolioHouseholdIds: {'portfolio-1', 'portfolio-2'},
      ),
      [null],
    );
  });

  test('generic widget summary keeps zero-budget currencies syncable', () {
    final summary = buildWidgetSummaryFromSpentAndBudget(
      totalSpent: 24.5,
      totalBudget: 0,
    );

    expect(summary.totalSpent, 24.5);
    expect(summary.totalBudget, 0);
    expect(summary.remainingBudget, -24.5);
    expect(summary.progress, 0);
  });

  test('household widget summary matches household budget overview math', () {
    final summary = buildHouseholdWidgetSummary(
      totalSpent: 240,
      budgets: const [
        BudgetStatus(
          budgetId: 'budget-1',
          name: 'Groceries',
          currency: 'USD',
          period: 'monthly',
          amountCents: 20000,
          spentCents: 12500,
          remainingCents: 7500,
          percentageUsed: 62.5,
          isOverBudget: false,
          isAtWarnThreshold: false,
          isAtAlertThreshold: false,
        ),
        BudgetStatus(
          budgetId: 'budget-2',
          name: 'Dining',
          currency: 'USD',
          period: 'monthly',
          amountCents: 10000,
          spentCents: 2500,
          remainingCents: 7500,
          percentageUsed: 25,
          isOverBudget: false,
          isAtWarnThreshold: false,
          isAtAlertThreshold: false,
        ),
      ],
    );

    expect(summary.totalSpent, 240);
    expect(summary.totalBudget, 300);
    expect(summary.remainingBudget, 150);
    expect(summary.progress, closeTo(0.5, 0.0001));
  });
}
