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
        ),
      );

      expect(report.overview.income, 3000);
      expect(report.overview.spending, 1250);
      expect(report.overview.savings, 1750);
      expect(report.overview.forecastedBalance, 1900);
      expect(report.safeToSpend.daysRemaining, 22);
      expect(report.safeToSpend.dailyAmount, closeTo(22.73, 0.01));
      expect(report.cashFlowForecast.map((point) => point.label), [
        'Today',
        'Utilities',
        'Payday',
        'Month-end buffer',
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
        ),
      );

      expect(report.anomalies, hasLength(1));
      expect(report.anomalies.single.title, 'Transport');
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

    test('closed periods do not claim that money is safe to spend', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 4),
          periodStart: DateTime(2026, 4),
          periodEnd: DateTime(2026, 4, 30),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 5000,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.safeToSpend.daysRemaining, 0);
      expect(report.safeToSpend.dailyAmount, 0);
    });

    test('healthy closed periods are classified from completed outcomes', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 4),
          periodStart: DateTime(2026, 4),
          periodEnd: DateTime(2026, 4, 30),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 5000,
          currentMonthTransactions: [
            _tx('salary', DateTime(2026, 4, 1), 3000, type: 'income'),
            _tx('food', DateTime(2026, 4, 3), 1000, category: 'Food'),
          ],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.overview.status, MonthlyReportStatus.onTrack);
      expect(report.summary, isNot(contains('safe to spend')));
      expect(report.summary, isNot(contains('forecast')));
    });

    test('closed periods with negative cash flow need attention', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 4),
          periodStart: DateTime(2026, 4),
          periodEnd: DateTime(2026, 4, 30),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 500,
          currentMonthTransactions: [
            _tx('salary', DateTime(2026, 4, 1), 1000, type: 'income'),
            _tx('rent', DateTime(2026, 4, 2), 1500, category: 'Rent'),
          ],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.overview.status, MonthlyReportStatus.needsAttention);
      expect(report.summary, isNot(contains('safe to spend')));
      expect(report.summary, isNot(contains('forecast')));
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

    test('compares multi-month category totals with the equal previous range',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 6),
          periodStart: DateTime(2026, 1),
          periodEnd: DateTime(2026, 6, 30),
          compareMonthToDate: false,
          now: DateTime(2026, 6, 30),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: [
            _tx('current', DateTime(2026, 6, 10), 600, category: 'Food'),
          ],
          previousMonthTransactions: [
            for (var month = 7; month <= 12; month++)
              _tx(
                'previous-$month',
                DateTime(2025, month, 10),
                50,
                category: 'Food',
              ),
          ],
          historicalTransactions: [
            for (var month = 7; month <= 12; month++)
              _tx(
                'historical-$month',
                DateTime(2025, month, 10),
                50,
                category: 'Food',
              ),
          ],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.categoryTrends.single.currentSpent, 600);
      expect(report.categoryTrends.single.previousSpent, 300);
      expect(report.categoryTrends.single.baselineAverageSpent, 300);
    });

    test('does not apply one-month pocket pace to multi-month ranges', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 6),
          periodStart: DateTime(2026, 1),
          periodEnd: DateTime(2026, 6, 30),
          compareMonthToDate: false,
          now: DateTime(2026, 6, 30),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: [
            _tx('food', DateTime(2026, 6, 10), 600, category: 'Food'),
          ],
          previousMonthTransactions: const [],
          budgetItems: const [
            MonthlyReportBudgetInput(
              name: 'Food',
              budgetAmount: 500,
              spent: 100,
            ),
          ],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.spendingPace, isEmpty);
      expect(report.budgetHealth, isEmpty);
    });

    test('uses explicit pocket source ids for budget drilldowns', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 10),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: [
            _tx('market', DateTime(2026, 5, 4), 100, category: 'Groceries'),
          ],
          previousMonthTransactions: const [],
          budgetItems: const [
            MonthlyReportBudgetInput(
              name: 'Food pocket',
              budgetAmount: 500,
              spent: 100,
              sourceTransactionIds: ['market'],
            ),
          ],
          futureTransactions: const [],
          recurringItems: const [],
        ),
      );

      expect(report.budgetHealth.single.sourceTransactionIds, ['market']);
      expect(report.spendingPace.single.sourceTransactionIds, ['market']);
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

    test('reports recurring commitment and net worth change', () {
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
        ),
      );

      expect(report.recurringCommitment.monthlyAmount, 960);
      expect(report.recurringCommitment.incomeShare, closeTo(0.32, 0.001));
      expect(report.recurringCommitment.dueSoonAmount, 900);
      expect(report.recurringCommitment.dueSoonCount, 1);
      expect(report.netWorthTrend?.currentNetWorth, 1400);
      expect(report.netWorthTrend?.previousNetWorth, 1200);
      expect(report.netWorthTrend?.change, 200);
    });

    test('monthly recurring commitment uses all scheduled occurrences', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 1),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: [
            _recurring(
              'weekly',
              'Weekly class',
              10,
              DateTime(2026, 5, 2),
              monthlyAmount: 50,
            ),
          ],
        ),
      );

      expect(report.subscriptions.items.single.amount, 10);
      expect(report.subscriptions.totalMonthlyAmount, 50);
      expect(report.recurringCommitment.monthlyAmount, 50);
    });

    test('preserves recurring ids on projected cash-flow items', () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 1),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: [
            _tx(
              'recurring-rent-20260510',
              DateTime(2026, 5, 10),
              500,
              category: 'Rent',
              recurringId: 'rent',
            ),
          ],
          recurringItems: const [],
        ),
      );

      expect(report.upcomingObligations.single.recurringId, 'rent');
      expect(
        report.cashFlowForecast
            .firstWhere((point) => point.sourceTransactionId != null)
            .recurringId,
        'rent',
      );
    });

    test('keeps future rows native while forecast totals use display currency',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 1),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: [
            _tx(
              'usd-bill',
              DateTime(2026, 5, 10),
              85,
              category: 'Utilities',
              nativeAmount: 100,
              nativeCurrencyCode: 'USD',
            ),
          ],
          recurringItems: const [],
        ),
      );

      expect(report.safeToSpend.futureObligations, 85);
      expect(report.overview.forecastedBalance, 915);
      expect(report.upcomingObligations.single.amount, 100);
      expect(report.upcomingObligations.single.currencyCode, 'USD');
    });

    test('keeps recurring rows native while commitment totals are converted',
        () {
      final report = buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: DateTime(2026, 5),
          now: DateTime(2026, 5, 1),
          currencyCode: 'EUR',
          currentBalance: 1000,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: [
            MonthlyReportRecurringInput(
              id: 'usd-weekly',
              name: 'USD weekly',
              amount: 10,
              currencyCode: 'USD',
              aggregateAmount: 8.5,
              monthlyAmount: 43.33,
              aggregateMonthlyAmount: 36.83,
              type: 'expense',
              nextDate: DateTime(2026, 5, 2),
            ),
          ],
        ),
      );

      expect(report.subscriptions.items.single.amount, 10);
      expect(report.subscriptions.items.single.currencyCode, 'USD');
      expect(report.subscriptions.totalMonthlyAmount, 36.83);
      expect(report.recurringCommitment.dueSoonAmount, 8.5);
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
  String? recurringId,
  double? nativeAmount,
  String? nativeCurrencyCode,
}) {
  return MonthlyReportTransactionInput(
    id: id,
    date: date,
    amount: amount,
    type: type,
    category: category,
    merchant: merchant,
    recurringId: recurringId,
    nativeAmount: nativeAmount,
    nativeCurrencyCode: nativeCurrencyCode,
    currencyCode: 'EUR',
  );
}

MonthlyReportRecurringInput _recurring(
    String id, String name, double amount, DateTime nextDate,
    {double? monthlyAmount}) {
  return MonthlyReportRecurringInput(
    id: id,
    name: name,
    amount: amount,
    monthlyAmount: monthlyAmount ?? amount,
    type: 'expense',
    currencyCode: 'EUR',
    nextDate: nextDate,
  );
}
