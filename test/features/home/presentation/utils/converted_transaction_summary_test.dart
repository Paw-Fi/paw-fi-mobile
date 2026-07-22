import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

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

  test('rounds every converted row to target cents before summing', () {
    final summary = summarizeTransactionsInCurrency(
      [
        _entry(
          id: 'eur-cent-1',
          amountCents: 1,
          currency: 'EUR',
          category: 'Food',
          date: DateTime(2026, 4, 10),
        ),
        _entry(
          id: 'eur-cent-2',
          amountCents: 1,
          currency: 'EUR',
          category: 'Food',
          date: DateTime(2026, 4, 11),
        ),
      ],
      targetCurrency: 'USD',
      rates: rates,
      intervalGranularity: 'monthly',
    );

    expect(summary.expenseTotal, 0.02);
    expect(summary.categorySummaries.single.amount, 0.02);
    expect(summary.periodTotals, {DateTime(2026, 4): 0.02});
  });

  test('adds projected recurring rows to a single-currency chart summary', () {
    final summary = addProjectedTransactionsToSummary(
      const TransactionsFeedSummary(
        transactionCount: 1,
        expenseTotal: 5,
        incomeTotal: 0,
        hasMultipleCurrencies: false,
        categorySummaries: [
          TransactionsFeedCategorySummary(
            category: 'utilities',
            amount: 5,
            transactionCount: 1,
          ),
        ],
        yearlyPeriodTotals: {},
      ),
      [
        _entry(
          id: 'recurring_power_20260611',
          amountCents: 1000,
          currency: 'SGD',
          category: 'utilities',
          date: DateTime(2026, 6, 11),
        ),
        _entry(
          id: 'recurring_salary_20260601',
          amountCents: 85000,
          currency: 'SGD',
          category: 'income',
          type: 'income',
          date: DateTime(2026, 6, 1),
        ),
      ],
    );

    expect(summary.transactionCount, 3);
    expect(summary.expenseTotal, 15);
    expect(summary.incomeTotal, 850);
    expect(summary.categorySummaries.single.amount, 15);
    expect(summary.categorySummaries.single.transactionCount, 2);
    expect(summary.yearlyPeriodTotals[DateTime(2026)], 10);
  });

  test('converts projected recurring rows before adding them to chart totals',
      () {
    final summary = addProjectedTransactionsToSummary(
      const TransactionsFeedSummary.empty(),
      [
        _entry(
          id: 'recurring_rent_20260610',
          amountCents: 10000,
          currency: 'EUR',
          category: 'housing',
          date: DateTime(2026, 6, 10),
        ),
      ],
      targetCurrency: 'USD',
      rates: rates,
      intervalGranularity: 'monthly',
    );

    expect(summary.expenseTotal, 50);
    expect(summary.categorySummaries.single.amount, 50);
    expect(summary.periodTotals, {DateTime(2026, 6): 50});
  });

  test('detects multiple currencies split between actual and projected rows',
      () {
    final summary = addProjectedTransactionsToSummary(
      const TransactionsFeedSummary(
        transactionCount: 1,
        expenseTotal: 100,
        incomeTotal: 0,
        hasMultipleCurrencies: false,
        categorySummaries: [],
        yearlyPeriodTotals: {},
        currencyTypeTotals: [
          TransactionsFeedCurrencyTypeTotal(
            currency: 'USD',
            expenseTotal: 100,
            incomeTotal: 0,
            transactionCount: 1,
          ),
        ],
      ),
      [
        _entry(
          id: 'recurring_eur_20260610',
          amountCents: 10000,
          currency: 'EUR',
          category: 'housing',
          date: DateTime(2026, 6, 10),
        ),
      ],
      targetCurrency: 'USD',
      rates: rates,
    );

    expect(summary.hasMultipleCurrencies, isTrue);
    expect(summary.currencyTypeTotals, hasLength(2));
  });

  test('reported monthly schedules produce the expected filtered chart totals',
      () {
    final recurring = <RecurringTransaction>[
      _recurring('income', 85000, 1, type: 'income'),
      _recurring('property-tax', 1241, 7),
      _recurring('power', 21120, 11),
      _recurring('trust-card', 5000, 25),
      _recurring('phone', 13335, 24),
      _recurring('recycling', 8500, 4),
      _recurring('iras', 9850, 7),
      _recurring('uob', 10, 27),
      _recurring('ocbc', 5000, 20),
      _recurring('insurance', 16000, 7),
    ];

    TransactionsFeedSummary summarize(DateTime start, DateTime end) {
      final projected = projectRecurringTransactionsAsExpenseEntries(
        recurringTransactions: recurring,
        rangeStart: start,
        rangeEnd: end,
        selectedCurrency: 'SGD',
      );
      return addProjectedTransactionsToSummary(
        const TransactionsFeedSummary.empty(),
        projected,
        targetCurrency: 'SGD',
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'SGD': 1.35},
        ),
        intervalGranularity: 'daily',
      );
    }

    final lastMonth = summarize(DateTime(2026, 6, 1), DateTime(2026, 6, 30));
    expect(lastMonth.transactionCount, 10);
    expect(lastMonth.expenseTotal, closeTo(800.56, 0.001));
    expect(lastMonth.incomeTotal, 850);
    expect(
      lastMonth.periodTotals[DateTime(2026, 6, 7)],
      closeTo(270.91, 0.001),
    );

    final lastThreeMonths =
        summarize(DateTime(2026, 5, 1), DateTime(2026, 7, 22));
    expect(lastThreeMonths.transactionCount, 27);
    expect(lastThreeMonths.expenseTotal, closeTo(2218.23, 0.001));
    expect(lastThreeMonths.incomeTotal, 2550);
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

RecurringTransaction _recurring(
  String id,
  int amountCents,
  int anchorDay, {
  String type = 'expense',
}) {
  final anchor = DateTime(2026, type == 'income' ? 4 : 3, anchorDay);
  return RecurringTransaction(
    id: id,
    date: anchor,
    category: type == 'income' ? 'income' : 'bills',
    amount: amountCents / 100,
    currency: 'SGD',
    ownerType: 'me',
    privacyScope: 'full',
    recurrenceRule: RecurrenceRule(
      frequency: 'monthly',
      anchorDate: anchor,
    ),
    type: type,
    attachments: const [],
    createdAt: anchor,
    analyticsClass: type == 'income' ? 'income' : 'consumer_spend',
    analyticsSpendingMultiplier: type == 'income' ? 0 : 1,
    analyticsCountsTowardIncome: type == 'income',
  );
}
