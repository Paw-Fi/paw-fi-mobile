import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';

void main() {
  test('purchase and refund net consistently across pocket detail aggregates',
      () {
    final date = DateTime(2026, 7, 10);
    final transactions = <ExpenseEntry>[
      ExpenseEntry(
        id: 'purchase',
        date: date,
        amountCents: 10000,
        category: 'groceries',
        createdAt: date,
        analyticsClass: 'consumer_spend',
        analyticsSpendingMultiplier: 1,
      ),
      ExpenseEntry(
        id: 'refund',
        date: date,
        amountCents: 2500,
        category: 'groceries',
        createdAt: date,
        analyticsClass: 'refund_or_reversal',
        analyticsSpendingMultiplier: -1,
      ),
      ExpenseEntry(
        id: 'transfer',
        date: date,
        amountCents: 50000,
        category: 'transfer',
        createdAt: date,
        analyticsClass: 'transfer_out',
        analyticsSpendingMultiplier: 0,
      ),
      ExpenseEntry(
        id: 'pending',
        date: date,
        amountCents: 8000,
        category: 'groceries',
        createdAt: date,
        bankAccountId: 'bank-1',
        analyticsClass: 'consumer_spend',
        analyticsIsFinal: false,
        analyticsSpendingMultiplier: 0,
      ),
    ];

    final spending = calculatePocketDetailSpending(transactions);

    expect(spending.total, 75);
    expect(spending.categories, <String, double>{
      'groceries': 75,
      'transfer': 0,
    });
    expect(spending.days, <int, double>{10: 75});
  });
}
