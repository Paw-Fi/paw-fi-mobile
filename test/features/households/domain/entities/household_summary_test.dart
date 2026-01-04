import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

void main() {
  group('DatePeriod - Model', () {
    test('creates date period', () {
      const period = DatePeriod(
        startDate: '2024-01-01',
        endDate: '2024-01-31',
      );

      expect(period.startDate, '2024-01-01');
      expect(period.endDate, '2024-01-31');
    });

    test('fromJson parses date period', () {
      final json = {
        'start_date': '2024-01-01',
        'end_date': '2024-01-31',
      };

      final period = DatePeriod.fromJson(json);

      expect(period.startDate, '2024-01-01');
      expect(period.endDate, '2024-01-31');
    });

    test('toJson serializes date period', () {
      const period = DatePeriod(
        startDate: '2024-01-01',
        endDate: '2024-01-31',
      );

      final json = period.toJson();

      expect(json['start_date'], '2024-01-01');
      expect(json['end_date'], '2024-01-31');
    });
  });

  group('Totals - Model', () {
    test('creates totals with all fields', () {
      const totals = Totals(
        totalExpensesCents: 100000,
        totalIncomeCents: 150000,
        netCents: 50000,
        transactionCount: 25,
        splitCount: 10,
      );

      expect(totals.totalExpensesCents, 100000);
      expect(totals.totalIncomeCents, 150000);
      expect(totals.netCents, 50000);
      expect(totals.transactionCount, 25);
      expect(totals.splitCount, 10);
    });

    test('fromJson parses totals', () {
      final json = {
        'total_expenses_cents': 100000,
        'total_income_cents': 150000,
        'net_cents': 50000,
        'transaction_count': 25,
        'split_count': 10,
      };

      final totals = Totals.fromJson(json);

      expect(totals.totalExpensesCents, 100000);
      expect(totals.totalIncomeCents, 150000);
      expect(totals.netCents, 50000);
    });

    test('toJson serializes totals', () {
      const totals = Totals(
        totalExpensesCents: 100000,
        totalIncomeCents: 150000,
        netCents: 50000,
        transactionCount: 25,
        splitCount: 10,
      );

      final json = totals.toJson();

      expect(json['total_expenses_cents'], 100000);
      expect(json['net_cents'], 50000);
    });
  });

  group('MemberContribution - Model', () {
    test('creates member contribution with all fields', () {
      const contribution = MemberContribution(
        userId: 'user_123',
        totalSpentCents: 50000,
        transactionCount: 15,
        splitCount: 5,
        balanceCents: 10000,
        userEmail: 'user@example.com',
        userName: 'John Doe',
      );

      expect(contribution.userId, 'user_123');
      expect(contribution.totalSpentCents, 50000);
      expect(contribution.balanceCents, 10000);
      expect(contribution.userEmail, 'user@example.com');
    });

    test('fromJson parses member contribution', () {
      final json = {
        'user_id': 'user_123',
        'total_spent_cents': 50000,
        'transaction_count': 15,
        'split_count': 5,
        'balance_cents': 10000,
        'user_email': 'user@example.com',
        'user_name': 'John Doe',
      };

      final contribution = MemberContribution.fromJson(json);

      expect(contribution.userId, 'user_123');
      expect(contribution.userName, 'John Doe');
    });

    test('toJson serializes member contribution', () {
      const contribution = MemberContribution(
        userId: 'user_123',
        totalSpentCents: 50000,
        transactionCount: 15,
        splitCount: 5,
        balanceCents: 10000,
        userEmail: 'user@example.com',
        userName: 'John Doe',
      );

      final json = contribution.toJson();

      expect(json['user_id'], 'user_123');
      expect(json['balance_cents'], 10000);
    });

    test('handles null optional fields', () {
      const contribution = MemberContribution(
        userId: 'user_123',
        totalSpentCents: 50000,
        transactionCount: 15,
        splitCount: 5,
        balanceCents: 10000,
      );

      expect(contribution.userEmail, null);
      expect(contribution.userName, null);
    });
  });

  group('CategoryBreakdown - Model', () {
    test('creates category breakdown', () {
      const breakdown = CategoryBreakdown(
        category: 'Food & Drinks',
        amountCents: 25000,
        percentage: 25.5,
        transactionCount: 10,
      );

      expect(breakdown.category, 'Food & Drinks');
      expect(breakdown.amountCents, 25000);
      expect(breakdown.percentage, 25.5);
    });

    test('fromJson parses category breakdown', () {
      final json = {
        'category': 'Food & Drinks',
        'amount_cents': 25000,
        'percentage': 25.5,
        'transaction_count': 10,
      };

      final breakdown = CategoryBreakdown.fromJson(json);

      expect(breakdown.category, 'Food & Drinks');
      expect(breakdown.percentage, 25.5);
    });

    test('toJson serializes category breakdown', () {
      const breakdown = CategoryBreakdown(
        category: 'Food & Drinks',
        amountCents: 25000,
        percentage: 25.5,
        transactionCount: 10,
      );

      final json = breakdown.toJson();

      expect(json['category'], 'Food & Drinks');
      expect(json['amount_cents'], 25000);
    });
  });

  group('BudgetStatus - Model', () {
    test('creates budget status with all fields', () {
      const status = BudgetStatus(
        budgetId: 'budget_123',
        name: 'Monthly Budget',
        currency: 'USD',
        period: 'monthly',
        amountCents: 200000,
        spentCents: 150000,
        remainingCents: 50000,
        percentageUsed: 75.0,
        isOverBudget: false,
        isAtWarnThreshold: true,
        isAtAlertThreshold: false,
      );

      expect(status.budgetId, 'budget_123');
      expect(status.name, 'Monthly Budget');
      expect(status.percentageUsed, 75.0);
      expect(status.isOverBudget, false);
    });

    test('fromJson parses budget status', () {
      final json = {
        'budget_id': 'budget_123',
        'name': 'Monthly Budget',
        'currency': 'USD',
        'period': 'monthly',
        'amount_cents': 200000,
        'spent_cents': 150000,
        'remaining_cents': 50000,
        'percentage_used': 75.0,
        'is_over_budget': false,
        'is_at_warn_threshold': true,
        'is_at_alert_threshold': false,
      };

      final status = BudgetStatus.fromJson(json);

      expect(status.budgetId, 'budget_123');
      expect(status.isAtWarnThreshold, true);
    });

    test('toJson serializes budget status', () {
      const status = BudgetStatus(
        budgetId: 'budget_123',
        name: 'Monthly Budget',
        currency: 'USD',
        period: 'monthly',
        amountCents: 200000,
        spentCents: 150000,
        remainingCents: 50000,
        percentageUsed: 75.0,
        isOverBudget: false,
        isAtWarnThreshold: true,
        isAtAlertThreshold: false,
      );

      final json = status.toJson();

      expect(json['budget_id'], 'budget_123');
      expect(json['is_over_budget'], false);
    });

    test('handles over budget scenario', () {
      const status = BudgetStatus(
        budgetId: 'budget_123',
        name: 'Monthly Budget',
        currency: 'USD',
        period: 'monthly',
        amountCents: 200000,
        spentCents: 250000,
        remainingCents: -50000,
        percentageUsed: 125.0,
        isOverBudget: true,
        isAtWarnThreshold: true,
        isAtAlertThreshold: true,
      );

      expect(status.isOverBudget, true);
      expect(status.remainingCents, -50000);
      expect(status.percentageUsed, 125.0);
    });
  });

  group('HouseholdSummary - Model Creation', () {
    test('creates household summary with all fields', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 100000,
          totalIncomeCents: 150000,
          netCents: 50000,
          transactionCount: 25,
          splitCount: 10,
        ),
        memberContributions: const [
          MemberContribution(
            userId: 'user_1',
            totalSpentCents: 60000,
            transactionCount: 15,
            splitCount: 5,
            balanceCents: 10000,
          ),
        ],
        categoryBreakdown: const [
          CategoryBreakdown(
            category: 'Food',
            amountCents: 50000,
            percentage: 50.0,
            transactionCount: 10,
          ),
        ],
        budgets: const [
          BudgetStatus(
            budgetId: 'budget_1',
            name: 'Monthly',
            currency: 'USD',
            period: 'monthly',
            amountCents: 200000,
            spentCents: 100000,
            remainingCents: 100000,
            percentageUsed: 50.0,
            isOverBudget: false,
            isAtWarnThreshold: false,
            isAtAlertThreshold: false,
          ),
        ],
        balances: {'user_1': 10000, 'user_2': -5000},
      );

      expect(summary.householdId, 'household_123');
      expect(summary.currency, 'USD');
      expect(summary.totals.netCents, 50000);
      expect(summary.memberContributions.length, 1);
      expect(summary.balances['user_1'], 10000);
    });
  });

  group('HouseholdSummary - JSON Serialization', () {
    test('fromJson parses complete household summary', () {
      final json = {
        'household_id': 'household_123',
        'currency': 'USD',
        'period': {
          'start_date': '2024-01-01',
          'end_date': '2024-01-31',
        },
        'totals': {
          'total_expenses_cents': 100000,
          'total_income_cents': 150000,
          'net_cents': 50000,
          'transaction_count': 25,
          'split_count': 10,
        },
        'member_contributions': [
          {
            'user_id': 'user_1',
            'total_spent_cents': 60000,
            'transaction_count': 15,
            'split_count': 5,
            'balance_cents': 10000,
          },
        ],
        'category_breakdown': [
          {
            'category': 'Food',
            'amount_cents': 50000,
            'percentage': 50.0,
            'transaction_count': 10,
          },
        ],
        'budgets': [
          {
            'budget_id': 'budget_1',
            'name': 'Monthly',
            'currency': 'USD',
            'period': 'monthly',
            'amount_cents': 200000,
            'spent_cents': 100000,
            'remaining_cents': 100000,
            'percentage_used': 50.0,
            'is_over_budget': false,
            'is_at_warn_threshold': false,
            'is_at_alert_threshold': false,
          },
        ],
        'balances': {'user_1': 10000, 'user_2': -5000},
      };

      final summary = HouseholdSummary.fromJson(json);

      expect(summary.householdId, 'household_123');
      expect(summary.totals.netCents, 50000);
      expect(summary.memberContributions.length, 1);
      expect(summary.categoryBreakdown.length, 1);
      expect(summary.budgets.length, 1);
      expect(summary.balances['user_2'], -5000);
    });

    test('toJson serializes complete household summary', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 100000,
          totalIncomeCents: 150000,
          netCents: 50000,
          transactionCount: 25,
          splitCount: 10,
        ),
        memberContributions: const [
          MemberContribution(
            userId: 'user_1',
            totalSpentCents: 60000,
            transactionCount: 15,
            splitCount: 5,
            balanceCents: 10000,
          ),
        ],
        categoryBreakdown: const [
          CategoryBreakdown(
            category: 'Food',
            amountCents: 50000,
            percentage: 50.0,
            transactionCount: 10,
          ),
        ],
        budgets: const [],
        balances: {'user_1': 10000},
      );

      final json = summary.toJson();

      expect(json['household_id'], 'household_123');
      expect(json['currency'], 'USD');
      expect(json['totals']['net_cents'], 50000);
    });
  });

  group('HouseholdSummary - Edge Cases', () {
    test('handles empty lists', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 0,
          totalIncomeCents: 0,
          netCents: 0,
          transactionCount: 0,
          splitCount: 0,
        ),
        memberContributions: const [],
        categoryBreakdown: const [],
        budgets: const [],
        balances: {},
      );

      expect(summary.memberContributions.isEmpty, true);
      expect(summary.categoryBreakdown.isEmpty, true);
      expect(summary.budgets.isEmpty, true);
      expect(summary.balances.isEmpty, true);
    });

    test('handles multiple members', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 300000,
          totalIncomeCents: 300000,
          netCents: 0,
          transactionCount: 30,
          splitCount: 15,
        ),
        memberContributions: const [
          MemberContribution(
            userId: 'user_1',
            totalSpentCents: 100000,
            transactionCount: 10,
            splitCount: 5,
            balanceCents: 0,
          ),
          MemberContribution(
            userId: 'user_2',
            totalSpentCents: 100000,
            transactionCount: 10,
            splitCount: 5,
            balanceCents: 0,
          ),
          MemberContribution(
            userId: 'user_3',
            totalSpentCents: 100000,
            transactionCount: 10,
            splitCount: 5,
            balanceCents: 0,
          ),
        ],
        categoryBreakdown: const [],
        budgets: const [],
        balances: {'user_1': 0, 'user_2': 0, 'user_3': 0},
      );

      expect(summary.memberContributions.length, 3);
      expect(summary.balances.length, 3);
    });

    test('handles negative balances', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 100000,
          totalIncomeCents: 100000,
          netCents: 0,
          transactionCount: 10,
          splitCount: 5,
        ),
        memberContributions: const [
          MemberContribution(
            userId: 'user_1',
            totalSpentCents: 80000,
            transactionCount: 8,
            splitCount: 4,
            balanceCents: 30000,
          ),
          MemberContribution(
            userId: 'user_2',
            totalSpentCents: 20000,
            transactionCount: 2,
            splitCount: 1,
            balanceCents: -30000,
          ),
        ],
        categoryBreakdown: const [],
        budgets: const [],
        balances: {'user_1': 30000, 'user_2': -30000},
      );

      expect(summary.balances['user_1'], 30000);
      expect(summary.balances['user_2'], -30000);
    });

    test('handles multiple categories', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 100000,
          totalIncomeCents: 150000,
          netCents: 50000,
          transactionCount: 20,
          splitCount: 0,
        ),
        memberContributions: const [],
        categoryBreakdown: const [
          CategoryBreakdown(
            category: 'Food',
            amountCents: 40000,
            percentage: 40.0,
            transactionCount: 8,
          ),
          CategoryBreakdown(
            category: 'Transport',
            amountCents: 30000,
            percentage: 30.0,
            transactionCount: 6,
          ),
          CategoryBreakdown(
            category: 'Entertainment',
            amountCents: 30000,
            percentage: 30.0,
            transactionCount: 6,
          ),
        ],
        budgets: const [],
        balances: {},
      );

      expect(summary.categoryBreakdown.length, 3);
      expect(summary.categoryBreakdown[1].category, 'Transport');
    });

    test('handles multiple budgets', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-01-31',
        ),
        totals: const Totals(
          totalExpensesCents: 100000,
          totalIncomeCents: 150000,
          netCents: 50000,
          transactionCount: 20,
          splitCount: 0,
        ),
        memberContributions: const [],
        categoryBreakdown: const [],
        budgets: const [
          BudgetStatus(
            budgetId: 'budget_1',
            name: 'Food Budget',
            currency: 'USD',
            period: 'monthly',
            amountCents: 50000,
            spentCents: 40000,
            remainingCents: 10000,
            percentageUsed: 80.0,
            isOverBudget: false,
            isAtWarnThreshold: true,
            isAtAlertThreshold: false,
          ),
          BudgetStatus(
            budgetId: 'budget_2',
            name: 'Transport Budget',
            currency: 'USD',
            period: 'monthly',
            amountCents: 30000,
            spentCents: 35000,
            remainingCents: -5000,
            percentageUsed: 116.7,
            isOverBudget: true,
            isAtWarnThreshold: true,
            isAtAlertThreshold: true,
          ),
        ],
        balances: {},
      );

      expect(summary.budgets.length, 2);
      expect(summary.budgets[1].isOverBudget, true);
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY'];

      for (final code in currencies) {
        final summary = HouseholdSummary(
          householdId: 'household_123',
          currency: code,
          period: const DatePeriod(
            startDate: '2024-01-01',
            endDate: '2024-01-31',
          ),
          totals: const Totals(
            totalExpensesCents: 100000,
            totalIncomeCents: 150000,
            netCents: 50000,
            transactionCount: 20,
            splitCount: 0,
          ),
          memberContributions: const [],
          categoryBreakdown: const [],
          budgets: const [],
          balances: {},
        );

        expect(summary.currency, code);
      }
    });

    test('handles large transaction counts', () {
      final summary = HouseholdSummary(
        householdId: 'household_123',
        currency: 'USD',
        period: const DatePeriod(
          startDate: '2024-01-01',
          endDate: '2024-12-31',
        ),
        totals: const Totals(
          totalExpensesCents: 10000000,
          totalIncomeCents: 15000000,
          netCents: 5000000,
          transactionCount: 10000,
          splitCount: 5000,
        ),
        memberContributions: const [],
        categoryBreakdown: const [],
        budgets: const [],
        balances: {},
      );

      expect(summary.totals.transactionCount, 10000);
      expect(summary.totals.splitCount, 5000);
    });
  });
}
