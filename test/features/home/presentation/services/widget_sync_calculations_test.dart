import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_calculations.dart';

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
}
