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

    test('calculates month-to-date trend summary from comparable real data',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: [
            _tx('salary-current', DateTime(2026, 5, 1), 3000, type: 'income'),
            _tx('food-current', DateTime(2026, 5, 3), 600, category: 'Food'),
          ],
          previousMonthTransactions: [
            _tx('salary-prev', DateTime(2026, 4, 1), 2800, type: 'income'),
            _tx('food-prev', DateTime(2026, 4, 3), 500, category: 'Food'),
            _tx('late-prev', DateTime(2026, 4, 25), 900, category: 'Travel'),
          ],
          historicalTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.trendSummary.currentIncome, 3000);
      expect(report.trendSummary.previousIncome, 2800);
      expect(report.trendSummary.currentSpending, 600);
      expect(report.trendSummary.previousSpending, 500);
      expect(report.trendSummary.savingsRate, closeTo(0.8, 0.001));
      expect(report.trendSummary.previousSavingsRate, closeTo(0.821, 0.001));
      expect(report.trendSummary.netCashFlow, 2400);
    });

    test('summarizes budget plan and unbudgeted spending without placeholders',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: [
            _tx('salary', DateTime(2026, 5, 1), 2500, type: 'income'),
            _tx('food', DateTime(2026, 5, 3), 550, category: 'Food'),
            _tx('travel', DateTime(2026, 5, 4), 120, category: 'Travel'),
          ],
          previousMonthTransactions: const [],
          historicalTransactions: const [],
          budgetItems: const [
            MonthlyReportBudgetInput(
                name: 'Food', budgetAmount: 500, spent: 550),
            MonthlyReportBudgetInput(
                name: 'Transport', budgetAmount: 100, spent: 90),
          ],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.budgetPlan.totalBudgeted, 600);
      expect(report.budgetPlan.totalSpent, 670);
      expect(report.budgetPlan.totalRemaining, -70);
      expect(report.budgetPlan.overBudgetCount, 1);
      expect(report.budgetPlan.atRiskCount, 1);
      expect(report.budgetPlan.unbudgetedSpent, 120);
      expect(report.budgetPlan.budgetToIncomeRatio, closeTo(0.24, 0.001));
    });

    test('builds category movers from previous and historical transactions',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: [
            _tx('food-current', DateTime(2026, 5, 6), 420, category: 'Food'),
          ],
          previousMonthTransactions: [
            _tx('food-prev', DateTime(2026, 4, 6), 200, category: 'Food'),
          ],
          historicalTransactions: [
            _tx('food-h1', DateTime(2026, 3, 6), 150, category: 'Food'),
            _tx('food-h2', DateTime(2026, 2, 6), 250, category: 'Food'),
            _tx('food-h3', DateTime(2026, 1, 22), 900, category: 'Food'),
          ],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.categoryTrends, hasLength(1));
      expect(report.categoryTrends.single.name, 'Food');
      expect(report.categoryTrends.single.currentSpent, 420);
      expect(report.categoryTrends.single.previousSpent, 200);
      expect(report.categoryTrends.single.baselineAverageSpent, 200);
      expect(report.categoryTrends.single.previousChangePercent,
          closeTo(1.1, 0.001));
    });

    test('calculates merchant concentration and cashflow low-water dates', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 300,
          currentMonthTransactions: [
            _tx('shop-1', DateTime(2026, 5, 3), 100,
                category: 'Shopping', merchant: 'MegaMart'),
            _tx('shop-2', DateTime(2026, 5, 4), 50,
                category: 'Shopping', merchant: 'MegaMart'),
            _tx('cafe', DateTime(2026, 5, 5), 50,
                category: 'Dining', merchant: 'Cafe One'),
          ],
          previousMonthTransactions: const [],
          historicalTransactions: const [],
          budgetItems: const [],
          futureTransactions: [
            _tx('rent', DateTime(2026, 5, 12), 400, category: 'Rent'),
            _tx('pay', DateTime(2026, 5, 20), 500,
                type: 'income', category: 'Payday'),
          ],
          recurringItems: const [],
          goals: const [],
        ),
      );

      expect(report.merchantConcentration.first.name, 'MegaMart');
      expect(report.merchantConcentration.first.amount, 150);
      expect(report.merchantConcentration.first.transactionCount, 2);
      expect(report.merchantConcentration.first.spendingShare,
          closeTo(0.75, 0.001));
      expect(report.cashFlowHealth.lowWaterBalance, -100);
      expect(report.cashFlowHealth.lowWaterDate, DateTime(2026, 5, 12));
      expect(report.cashFlowHealth.firstNegativeDate, DateTime(2026, 5, 12));
    });

    test('reports recurring commitment, net worth change, and goals', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 1400,
          previousNetWorth: 1200,
          currentMonthTransactions: [
            _tx('salary', DateTime(2026, 5, 1), 3000, type: 'income'),
          ],
          previousMonthTransactions: const [],
          historicalTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: [
            _recurring('rent', 'Rent', 900, DateTime(2026, 5, 15)),
            _recurring('gym', 'Gym', 60, DateTime(2026, 5, 28)),
          ],
          goals: const [
            MonthlyReportGoalInput(
              title: 'Emergency Fund',
              targetAmount: 5000,
              currentAmount: 2500,
              currencyCode: 'EUR',
              targetDate: '2026-11-01',
              isOnTrack: false,
            ),
          ],
        ),
      );

      expect(report.recurringCommitment.monthlyAmount, 960);
      expect(report.recurringCommitment.incomeShare, closeTo(0.32, 0.001));
      expect(report.recurringCommitment.dueSoonAmount, 900);
      expect(report.recurringCommitment.dueSoonCount, 1);
      expect(report.netWorthTrend?.currentNetWorth, 1400);
      expect(report.netWorthTrend?.previousNetWorth, 1200);
      expect(report.netWorthTrend?.change, 200);
      expect(report.goals.single.progress, closeTo(0.5, 0.001));
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
