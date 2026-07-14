import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

ExpenseEntry _entry(String id, DateTime date) => ExpenseEntry(
      id: id,
      userId: 'user-1',
      date: date,
      amountCents: 1000,
      createdAt: date,
      type: 'expense',
      category: 'food',
      currency: 'USD',
    );

void main() {
  group('buildMonthlyReportBudgetInputsForTesting', () {
    test('uses rollover-adjusted available budget for report budget health',
        () {
      final inputs = buildMonthlyReportBudgetInputsForTesting(
        [
          PocketEnvelope(
            id: 'env-food',
            name: 'Food',
            budgetAmountCents: 40000,
            spent: 425,
            currency: 'EUR',
            rolloverEnabled: true,
            rolloverFromPreviousCents: 5000,
            availableBudgetCents: 45000,
            remainingCents: 2500,
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        currencyCode: 'EUR',
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 1},
        ),
        aggregateSpentByEnvelopeId: const {},
      );

      expect(inputs.single.budgetAmount, 450);
      expect(inputs.single.spent, 425);
    });

    test('converts available budgets for multi-currency report selections', () {
      final inputs = buildMonthlyReportBudgetInputsForTesting(
        [
          PocketEnvelope(
            id: 'env-food',
            name: 'Food',
            budgetAmountCents: 40000,
            spent: 200,
            currency: 'USD',
            availableBudgetCents: 50000,
            remainingCents: 30000,
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        currencyCode: 'EUR',
        selectedCurrencies: const ['EUR', 'USD'],
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 0.5},
        ),
        aggregateSpentByEnvelopeId: const {'env-food': 100},
      );

      expect(inputs.single.budgetAmount, 250);
      expect(inputs.single.spent, 100);
    });

    test('uses linked categories for pocket drilldown transaction ids', () {
      final inputs = buildMonthlyReportBudgetInputsForTesting(
        [
          PocketEnvelope(
            id: 'env-food',
            name: 'Food pocket',
            budgetAmountCents: 40000,
            spent: 100,
            currency: 'EUR',
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        currencyCode: 'EUR',
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 1},
        ),
        aggregateSpentByEnvelopeId: const {},
        transactions: [
          _entry('groceries', DateTime(2026, 5, 2)).copyWith(
            category: 'Groceries',
            currency: 'EUR',
          ),
          _entry('transport', DateTime(2026, 5, 3)).copyWith(
            category: 'Transport',
            currency: 'EUR',
          ),
        ],
        envelopeCategories: const {
          'env-food': ['Groceries'],
        },
      );

      expect(inputs.single.sourceTransactionIds, ['groceries']);
    });
  });

  test('normalizes weekly recurring costs to a monthly average', () {
    final transaction = RecurringTransaction(
      id: 'weekly-class',
      date: DateTime(2026, 5, 2),
      category: 'Education',
      amount: 10,
      currency: 'EUR',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'weekly',
        anchorDate: DateTime(2026, 5, 2),
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 5, 1),
    );

    expect(
      normalizedMonthlyRecurringAmountForTesting(transaction),
      closeTo(43.33, 0.01),
    );
  });

  test('partitions one bounded transaction load into report periods', () {
    final periods = partitionMonthlyReportTransactionsForTesting(
      [
        _entry('before-history', DateTime(2025, 10, 31)),
        _entry('historical-start', DateTime(2025, 11, 1)),
        _entry('previous-start', DateTime(2026, 4, 1)),
        _entry('previous-end', DateTime(2026, 4, 30)),
        _entry('current-start', DateTime(2026, 5, 1)),
        _entry('current-end', DateTime(2026, 5, 31, 18, 30)),
        _entry('after-current', DateTime(2026, 6, 1)),
      ],
      MonthlyReportPeriod(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 31),
        previousStart: DateTime(2026, 4, 1),
        previousEnd: DateTime(2026, 4, 30),
        historicalStart: DateTime(2025, 11, 1),
        compareMonthToDate: true,
      ),
    );

    expect(
      periods.current.map((entry) => entry.id),
      ['current-start', 'current-end'],
    );
    expect(
      periods.previous.map((entry) => entry.id),
      ['previous-start', 'previous-end'],
    );
    expect(
      periods.historical.map((entry) => entry.id),
      [
        'historical-start',
        'previous-start',
        'previous-end',
      ],
    );
  });

  test('week history clamps month-end dates instead of rolling forward', () {
    final period = monthlyReportPeriodForTesting(
      MonthlyReportQuery(
        monthStart: DateTime(2026, 8, 31),
        financialMonthStartDay: 31,
        range: MonthlyReportRange.week,
      ),
      now: DateTime(2026, 7, 14),
    );

    expect(period.start, DateTime(2026, 8, 31));
    expect(period.historicalStart, DateTime(2026, 2, 28));
  });

  test('cached reports preserve recurring and drilldown source metadata', () {
    final report = buildMonthlyFinancialReport(
      MonthlyReportInput(
        monthStart: DateTime(2026, 5),
        now: DateTime(2026, 5, 1),
        currencyCode: 'EUR',
        currentBalance: 1000,
        currentMonthTransactions: const [],
        previousMonthTransactions: const [],
        budgetItems: const [
          MonthlyReportBudgetInput(
            name: 'Food',
            budgetAmount: 500,
            spent: 100,
            sourceTransactionIds: ['food-row'],
          ),
        ],
        futureTransactions: [
          MonthlyReportTransactionInput(
            id: 'recurring-rent-20260510',
            date: DateTime(2026, 5, 10),
            amount: 500,
            type: 'expense',
            category: 'Rent',
            currencyCode: 'EUR',
            recurringId: 'rent',
          ),
        ],
        recurringItems: [
          MonthlyReportRecurringInput(
            id: 'weekly-class',
            name: 'Weekly class',
            amount: 10,
            monthlyAmount: 43.33,
            type: 'expense',
            currencyCode: 'EUR',
            nextDate: DateTime(2026, 5, 2),
          ),
        ],
      ),
    );

    final restored = roundTripMonthlyReportForTesting(report);

    expect(restored.budgetHealth.single.sourceTransactionIds, ['food-row']);
    expect(restored.subscriptions.items.single.monthlyAmount, 43.33);
    expect(restored.subscriptions.totalMonthlyAmount, 43.33);
    expect(restored.upcomingObligations.single.recurringId, 'rent');
    expect(
      restored.cashFlowForecast
          .firstWhere((point) => point.sourceTransactionId != null)
          .recurringId,
      'rent',
    );
  });
}
