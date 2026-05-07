import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

ExpenseEntry _entry(
  String id,
  String currency, {
  String? householdId,
}) {
  return ExpenseEntry(
    id: id,
    date: DateTime(2026, 5, 7),
    amountCents: 1000,
    createdAt: DateTime(2026, 5, 7),
    type: 'expense',
    category: 'food',
    currency: currency,
    householdId: householdId,
  );
}

void main() {
  test('counts only personal transactions in personal scope', () {
    final counts = buildCurrencyTransactionCountsForScope(
      expenses: [
        _entry('personal-usd-1', 'usd'),
        _entry('personal-eur-1', 'EUR'),
        _entry('household-usd-1', 'USD', householdId: 'household-1'),
      ],
      activeAccountType: ActiveWalletType.personal,
      activeHouseholdId: null,
    );

    expect(counts, {'USD': 1, 'EUR': 1});
  });

  test('counts only selected household transactions in household scope', () {
    final counts = buildCurrencyTransactionCountsForScope(
      expenses: [
        _entry('personal-usd-1', 'USD'),
        _entry('household-usd-1', 'USD', householdId: 'household-1'),
        _entry('household-usd-2', 'USD', householdId: 'household-1'),
        _entry('household-gbp-1', 'GBP', householdId: 'household-2'),
      ],
      activeAccountType: ActiveWalletType.household,
      activeHouseholdId: 'household-1',
    );

    expect(counts, {'USD': 2});
  });
}
