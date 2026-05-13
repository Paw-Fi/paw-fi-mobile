import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';

void main() {
  group('buildMonthlyFinancialReport', () {
    test('calculates overview, safe-to-spend, and cashflow from real inputs',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 1500,
          currentMonthTransactions: [
            _tx('salary', DateTime(2026, 5, 1), 3000, type: 'income'),
            _tx('food', DateTime(2026, 5, 3), 350, category: 'Food'),
            _tx('rent', DateTime(2026, 5, 5), 900, category: 'Rent'),
          ],
          previousMonthTransactions: const [],
          budgetItems: const [
            MonthlyReportBudgetInput(
                name: 'Food', budgetAmount: 700, spent: 350),
            MonthlyReportBudgetInput(
                name: 'Transport', budgetAmount: 200, spent: 50),
          ],
          futureTransactions: [
            _tx('electricity', DateTime(2026, 5, 15), 100,
                category: 'Utilities'),
            _tx('payday', DateTime(2026, 5, 25), 500,
                type: 'income', category: 'Payday'),
          ],
          recurringItems: const [],
          goals: const [
            MonthlyReportGoalInput(
              title: 'Emergency Fund',
              targetAmount: 5000,
              currentAmount: 2000,
              currencyCode: 'EUR',
              targetDate: '2026-11-01',
              isOnTrack: true,
            ),
          ],
        ),
      );

      expect(report.overview.income, 3000);
      expect(report.overview.spending, 1250);
      expect(report.overview.savings, 1750);
      expect(report.overview.forecastedBalance, 1900);
      expect(report.safeToSpend.dailyAmount, closeTo(23.80, 0.01));
      expect(report.cashFlowForecast.map((point) => point.label), [
        'Today',
        'Utilities',
        'Payday',
        'End of month',
      ]);
    });

    test('marks budget health and spending pace from elapsed month progress',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [
            MonthlyReportBudgetInput(
                name: 'Food', budgetAmount: 600, spent: 520),
            MonthlyReportBudgetInput(
                name: 'Shopping', budgetAmount: 250, spent: 275),
            MonthlyReportBudgetInput(
                name: 'Transport', budgetAmount: 300, spent: 80),
          ],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.budgetHealth.map((item) => item.status), [
        MonthlyReportStatus.overBudget,
        MonthlyReportStatus.spendingFast,
        MonthlyReportStatus.onTrack,
      ]);
      final foodPace = report.spendingPace.firstWhere(
        (item) => item.label == 'Food',
      );
      expect(foodPace.spentProgress, closeTo(0.866, 0.001));
      expect(foodPace.timeProgress, closeTo(0.322, 0.001));
    });

    test('detects category anomalies against the previous month', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 20),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: [
            _tx('transport-current', DateTime(2026, 5, 10), 280,
                category: 'Transport'),
          ],
          previousMonthTransactions: [
            _tx('transport-prev', DateTime(2026, 4, 10), 120,
                category: 'Transport'),
          ],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.anomalies, hasLength(1));
      expect(report.anomalies.single.title, 'Transport spending is higher');
      expect(report.anomalies.single.description, contains('133% higher'));
    });

    test('builds subscription warnings from recurring items without fake rows',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: [
            _recurring('netflix-1', 'Netflix', 13.99, DateTime(2026, 5, 15)),
            _recurring('netflix-2', 'Netflix', 13.99, DateTime(2026, 5, 20)),
            _recurring('spotify', 'Spotify', 10.99, DateTime(2026, 5, 18)),
          ],
          goals: const [],
        ),
      );

      expect(report.subscriptions.totalMonthlyAmount, 38.97);
      expect(report.subscriptions.items.map((item) => item.status), [
        MonthlySubscriptionStatus.duplicatePossible,
        MonthlySubscriptionStatus.duplicatePossible,
        MonthlySubscriptionStatus.upcoming,
      ]);
    });
  });
}

MonthlyReportTransactionInput _tx(
  String id,
  DateTime date,
  double amount, {
  String type = 'expense',
  String category = 'General',
  String? merchant,
}) {
  return MonthlyReportTransactionInput(
    id: id,
    date: date,
    amount: amount,
    type: type,
    category: category,
    merchant: merchant,
    currencyCode: 'EUR',
  );
}

MonthlyReportRecurringInput _recurring(
  String id,
  String name,
  double amount,
  DateTime nextDate,
) {
  return MonthlyReportRecurringInput(
    id: id,
    name: name,
    amount: amount,
    type: 'expense',
    currencyCode: 'EUR',
    nextDate: nextDate,
  );
}
