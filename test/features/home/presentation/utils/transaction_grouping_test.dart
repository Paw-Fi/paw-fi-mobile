import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  required int amountCents,
  String? type,
}) {
  return ExpenseEntry(
    id: id,
    date: date,
    amountCents: amountCents,
    createdAt: date,
    type: type,
  );
}

void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  test('groups transactions by month descending', () {
    final items = [
      _entry(id: 'a', date: DateTime(2026, 2, 10), amountCents: 1200),
      _entry(id: 'b', date: DateTime(2026, 1, 5), amountCents: 500),
      _entry(id: 'c', date: DateTime(2026, 2, 1), amountCents: 300),
    ];

    final groups = groupTransactionsByMonth(items);
    expect(groups.length, 2);
    expect(groups.first.monthStart, DateTime(2026, 2, 1));
    expect(groups.last.monthStart, DateTime(2026, 1, 1));
  });

  test('sorts items within each month by newest first', () {
    final items = [
      _entry(id: 'a', date: DateTime(2026, 2, 1), amountCents: 100),
      _entry(id: 'b', date: DateTime(2026, 2, 20), amountCents: 200),
      _entry(id: 'c', date: DateTime(2026, 2, 10), amountCents: 300),
    ];

    final groups = groupTransactionsByMonth(items);
    final ids = groups.first.expenses.map((e) => e.id).toList();
    expect(ids, ['b', 'c', 'a']);
  });

  test('computes month totals with income positive and expense negative', () {
    final items = [
      _entry(id: 'a', date: DateTime(2026, 2, 10), amountCents: 500),
      _entry(
        id: 'b',
        date: DateTime(2026, 2, 11),
        amountCents: 200,
        type: 'income',
      ),
    ];

    final groups = groupTransactionsByMonth(items);
    expect(groups.first.total, closeTo(-3.0, 0.001));
  });

  test('formats month header with full month and year', () {
    final label = formatMonthHeader(DateTime(2026, 2, 1));
    expect(label, 'February 2026');
  });
}
