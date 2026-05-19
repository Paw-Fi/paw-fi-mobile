import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';

void main() {
  const rates = CurrencyRateTable(
    baseCurrency: 'USD',
    rates: {
      'USD': 1,
      'EUR': 2,
      'JPY': 100,
    },
  );

  test('converts mixed-currency rows before aggregating totals', () {
    final summary = summarizeTransactionsInCurrency(
      [
        _entry(
          id: 'usd-food',
          amountCents: 10000,
          currency: 'USD',
          category: 'Food',
          date: DateTime(2026, 4, 10),
        ),
        _entry(
          id: 'eur-food',
          amountCents: 10000,
          currency: 'EUR',
          category: 'Food',
          date: DateTime(2026, 4, 11),
        ),
        _entry(
          id: 'jpy-income',
          amountCents: 100000,
          currency: 'JPY',
          category: 'Salary',
          type: 'income',
          date: DateTime(2026, 5, 1),
        ),
      ],
      targetCurrency: 'USD',
      rates: rates,
      intervalGranularity: 'monthly',
    );

    expect(summary.expenseTotal, 150);
    expect(summary.incomeTotal, 10);
    expect(summary.hasMultipleCurrencies, isTrue);
    expect(summary.categorySummaries.single.category, 'food & drinks');
    expect(summary.categorySummaries.single.amount, 150);
    expect(summary.yearlyPeriodTotals, {DateTime(2026): 150});
    expect(summary.periodTotals, {DateTime(2026, 4): 150});
  });

  test('converts signed cents while preserving sign', () {
    expect(
      convertAmountCentsToCurrency(
        -10000,
        fromCurrency: 'EUR',
        targetCurrency: 'USD',
        rates: rates,
      ),
      -5000,
    );
  });
}

ExpenseEntry _entry({
  required String id,
  required int amountCents,
  required String currency,
  required String category,
  required DateTime date,
  String type = 'expense',
}) {
  return ExpenseEntry(
    id: id,
    amountCents: amountCents,
    currency: currency,
    category: category,
    date: date,
    createdAt: DateTime.utc(2026, 4, 1),
    type: type,
  );
}
