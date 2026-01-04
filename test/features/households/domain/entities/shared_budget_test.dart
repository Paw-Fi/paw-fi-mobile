import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';

void main() {
  group('BudgetPeriod - Enum', () {
    test('toJson converts enum to string correctly', () {
      expect(BudgetPeriod.daily.toJson(), 'daily');
      expect(BudgetPeriod.weekly.toJson(), 'weekly');
      expect(BudgetPeriod.monthly.toJson(), 'monthly');
      expect(BudgetPeriod.yearly.toJson(), 'yearly');
    });

    test('fromJson parses string to enum correctly', () {
      expect(BudgetPeriod.fromJson('daily'), BudgetPeriod.daily);
      expect(BudgetPeriod.fromJson('weekly'), BudgetPeriod.weekly);
      expect(BudgetPeriod.fromJson('monthly'), BudgetPeriod.monthly);
      expect(BudgetPeriod.fromJson('yearly'), BudgetPeriod.yearly);
    });

    test('fromJson throws on invalid value', () {
      expect(() => BudgetPeriod.fromJson('invalid'), throwsArgumentError);
      expect(() => BudgetPeriod.fromJson(''), throwsArgumentError);
      expect(() => BudgetPeriod.fromJson('DAILY'), throwsArgumentError);
    });
  });

  group('BudgetType - Enum', () {
    test('toJson converts enum to string correctly', () {
      expect(BudgetType.household.toJson(), 'household');
      expect(BudgetType.personal.toJson(), 'personal');
    });

    test('fromJson parses string to enum correctly', () {
      expect(BudgetType.fromJson('household'), BudgetType.household);
      expect(BudgetType.fromJson('personal'), BudgetType.personal);
    });

    test('fromJson throws on invalid value', () {
      expect(() => BudgetType.fromJson('invalid'), throwsArgumentError);
      expect(() => BudgetType.fromJson(''), throwsArgumentError);
      expect(() => BudgetType.fromJson('HOUSEHOLD'), throwsArgumentError);
    });
  });

  group('ShareScope - Enum', () {
    test('toJson converts enum to string correctly', () {
      expect(ShareScope.private.toJson(), 'private');
      expect(ShareScope.household.toJson(), 'household');
      expect(ShareScope.custom.toJson(), 'custom');
    });

    test('fromJson parses string to enum correctly', () {
      expect(ShareScope.fromJson('private'), ShareScope.private);
      expect(ShareScope.fromJson('household'), ShareScope.household);
      expect(ShareScope.fromJson('custom'), ShareScope.custom);
    });

    test('fromJson throws on invalid value', () {
      expect(() => ShareScope.fromJson('invalid'), throwsArgumentError);
      expect(() => ShareScope.fromJson(''), throwsArgumentError);
    });
  });

  group('SharedBudget - Model Creation', () {
    test('creates budget with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Monthly Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.id, 'budget_1');
      expect(budget.householdId, 'hh_1');
      expect(budget.name, 'Monthly Budget');
      expect(budget.period, BudgetPeriod.monthly);
      expect(budget.currency, 'USD');
      expect(budget.amountCents, 100000);
      expect(budget.warnThreshold, 0.8);
      expect(budget.alertThreshold, 0.9);
      expect(budget.isActive, true);
      expect(budget.budgetType, BudgetType.household);
      expect(budget.countSplitPortionOnly, false);
    });

    test('creates budget with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Personal Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 50000,
        warnThreshold: 0.75,
        alertThreshold: 0.95,
        periodStart: periodStart,
        periodEnd: periodEnd,
        isActive: true,
        budgetType: BudgetType.personal,
        userId: 'user_1',
        countSplitPortionOnly: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.periodStart, periodStart);
      expect(budget.periodEnd, periodEnd);
      expect(budget.budgetType, BudgetType.personal);
      expect(budget.userId, 'user_1');
      expect(budget.countSplitPortionOnly, true);
    });
  });

  group('SharedBudget - JSON Serialization', () {
    test('fromJson parses budget correctly', () {
      final json = {
        'id': 'budget_1',
        'household_id': 'hh_1',
        'name': 'Monthly Budget',
        'period': 'monthly',
        'currency': 'USD',
        'amount_cents': 100000,
        'warn_threshold': 0.8,
        'alert_threshold': 0.9,
        'period_start': '2024-01-01T00:00:00.000Z',
        'period_end': '2024-01-31T23:59:59.000Z',
        'is_active': true,
        'budget_type': 'household',
        'user_id': 'user_1',
        'count_split_portion_only': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final budget = SharedBudget.fromJson(json);

      expect(budget.id, 'budget_1');
      expect(budget.householdId, 'hh_1');
      expect(budget.name, 'Monthly Budget');
      expect(budget.period, BudgetPeriod.monthly);
      expect(budget.currency, 'USD');
      expect(budget.amountCents, 100000);
      expect(budget.warnThreshold, 0.8);
      expect(budget.alertThreshold, 0.9);
      expect(budget.periodStart, DateTime.utc(2024, 1, 1));
      expect(budget.periodEnd, DateTime.utc(2024, 1, 31, 23, 59, 59));
      expect(budget.isActive, true);
      expect(budget.budgetType, BudgetType.household);
      expect(budget.userId, 'user_1');
      expect(budget.countSplitPortionOnly, true);
      expect(budget.createdAt, DateTime.utc(2024, 1, 1));
      expect(budget.updatedAt, DateTime.utc(2024, 1, 1));
    });

    test('fromJson handles default values', () {
      final json = {
        'id': 'budget_1',
        'household_id': 'hh_1',
        'name': 'Budget',
        'period': 'monthly',
        'currency': 'USD',
        'amount_cents': 100000,
        'warn_threshold': 0.8,
        'alert_threshold': 0.9,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final budget = SharedBudget.fromJson(json);

      expect(budget.budgetType, BudgetType.household);
      expect(budget.countSplitPortionOnly, false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'budget_1',
        'household_id': 'hh_1',
        'name': 'Budget',
        'period': 'weekly',
        'currency': 'USD',
        'amount_cents': 50000,
        'warn_threshold': 0.7,
        'alert_threshold': 0.85,
        'period_start': null,
        'period_end': null,
        'is_active': true,
        'budget_type': 'personal',
        'user_id': null,
        'count_split_portion_only': false,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final budget = SharedBudget.fromJson(json);

      expect(budget.periodStart, null);
      expect(budget.periodEnd, null);
      expect(budget.userId, null);
    });

    test('toJson serializes budget correctly', () {
      final now = DateTime(2024, 1, 1);
      final periodStart = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 1, 31);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Monthly Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        periodStart: periodStart,
        periodEnd: periodEnd,
        isActive: true,
        budgetType: BudgetType.household,
        userId: 'user_1',
        countSplitPortionOnly: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = budget.toJson();

      expect(json['id'], 'budget_1');
      expect(json['household_id'], 'hh_1');
      expect(json['name'], 'Monthly Budget');
      expect(json['period'], 'monthly');
      expect(json['currency'], 'USD');
      expect(json['amount_cents'], 100000);
      expect(json['warn_threshold'], 0.8);
      expect(json['alert_threshold'], 0.9);
      expect(json['period_start'], '2024-01-01T00:00:00.000');
      expect(json['period_end'], '2024-01-31T00:00:00.000');
      expect(json['is_active'], true);
      expect(json['budget_type'], 'household');
      expect(json['user_id'], 'user_1');
      expect(json['count_split_portion_only'], true);
      expect(json['created_at'], '2024-01-01T00:00:00.000');
      expect(json['updated_at'], '2024-01-01T00:00:00.000');
    });
  });

  group('SharedBudget - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final now = DateTime(2024, 1, 1);
      final original = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Monthly Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        amountCents: 150000,
        warnThreshold: 0.75,
        isActive: false,
      );

      expect(updated.id, 'budget_1');
      expect(updated.amountCents, 150000);
      expect(updated.warnThreshold, 0.75);
      expect(updated.isActive, false);
      expect(updated.name, 'Monthly Budget');
      expect(updated.currency, 'USD');
    });
  });

  group('SharedBudget - Equality', () {
    test('two budgets with same values are equal', () {
      final now = DateTime(2024, 1, 1);
      final budget1 = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      final budget2 = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget1, equals(budget2));
      expect(budget1.hashCode, equals(budget2.hashCode));
    });

    test('two budgets with different values are not equal', () {
      final now = DateTime(2024, 1, 1);
      final budget1 = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      final budget2 = SharedBudget(
        id: 'budget_2',
        householdId: 'hh_1',
        name: 'Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget1, isNot(equals(budget2)));
    });
  });

  group('SharedBudget - Edge Cases', () {
    test('handles all budget periods', () {
      final now = DateTime(2024, 1, 1);
      
      final daily = SharedBudget(
        id: 'b1',
        householdId: 'hh_1',
        name: 'Daily',
        period: BudgetPeriod.daily,
        currency: 'USD',
        amountCents: 10000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      final weekly = daily.copyWith(period: BudgetPeriod.weekly);
      final monthly = daily.copyWith(period: BudgetPeriod.monthly);
      final yearly = daily.copyWith(period: BudgetPeriod.yearly);

      expect(daily.period, BudgetPeriod.daily);
      expect(weekly.period, BudgetPeriod.weekly);
      expect(monthly.period, BudgetPeriod.monthly);
      expect(yearly.period, BudgetPeriod.yearly);
    });

    test('handles threshold edge values', () {
      final now = DateTime(2024, 1, 1);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.0,
        alertThreshold: 1.0,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.warnThreshold, 0.0);
      expect(budget.alertThreshold, 1.0);
    });

    test('handles inactive budget', () {
      final now = DateTime(2024, 1, 1);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Inactive Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: false,
        budgetType: BudgetType.household,
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.isActive, false);
    });

    test('handles personal budget with userId', () {
      final now = DateTime(2024, 1, 1);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Personal Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 50000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.personal,
        userId: 'user_1',
        countSplitPortionOnly: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.budgetType, BudgetType.personal);
      expect(budget.userId, 'user_1');
    });

    test('handles split portion only flag', () {
      final now = DateTime(2024, 1, 1);
      
      final budget = SharedBudget(
        id: 'budget_1',
        householdId: 'hh_1',
        name: 'Split Budget',
        period: BudgetPeriod.monthly,
        currency: 'USD',
        amountCents: 100000,
        warnThreshold: 0.8,
        alertThreshold: 0.9,
        isActive: true,
        budgetType: BudgetType.household,
        countSplitPortionOnly: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.countSplitPortionOnly, true);
    });
  });

  group('SharingPreferences - Model', () {
    test('fromJson parses sharing preferences correctly', () {
      final json = {
        'id': 'pref_1',
        'user_id': 'user_1',
        'household_id': 'hh_1',
        'default_transaction_share_scope': 'household',
        'default_account_share_scope': 'private',
        'per_category_overrides': {
          'Food': 'household',
          'Entertainment': 'custom',
        },
        'enable_nudges': true,
        'nudge_quiet_hours_start': '22:00',
        'nudge_quiet_hours_end': '08:00',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final prefs = SharingPreferences.fromJson(json);

      expect(prefs.id, 'pref_1');
      expect(prefs.userId, 'user_1');
      expect(prefs.householdId, 'hh_1');
      expect(prefs.defaultTransactionShareScope, ShareScope.household);
      expect(prefs.defaultAccountShareScope, ShareScope.private);
      expect(prefs.perCategoryOverrides['Food'], 'household');
      expect(prefs.perCategoryOverrides['Entertainment'], 'custom');
      expect(prefs.enableNudges, true);
      expect(prefs.nudgeQuietHoursStart, '22:00');
      expect(prefs.nudgeQuietHoursEnd, '08:00');
      expect(prefs.createdAt, DateTime.utc(2024, 1, 1));
      expect(prefs.updatedAt, DateTime.utc(2024, 1, 1));
    });

    test('fromJson handles default values', () {
      final json = {
        'id': 'pref_1',
        'user_id': 'user_1',
        'household_id': 'hh_1',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final prefs = SharingPreferences.fromJson(json);

      expect(prefs.defaultTransactionShareScope, ShareScope.private);
      expect(prefs.defaultAccountShareScope, ShareScope.private);
      expect(prefs.perCategoryOverrides, {});
      expect(prefs.enableNudges, true);
    });

    test('fromJson handles null dates gracefully', () {
      final json = {
        'id': 'pref_1',
        'user_id': 'user_1',
        'household_id': 'hh_1',
        'created_at': null,
        'updated_at': null,
      };

      final prefs = SharingPreferences.fromJson(json);

      expect(prefs.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(prefs.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('toJson serializes sharing preferences correctly', () {
      final now = DateTime(2024, 1, 1);
      final prefs = SharingPreferences(
        id: 'pref_1',
        userId: 'user_1',
        householdId: 'hh_1',
        defaultTransactionShareScope: ShareScope.household,
        defaultAccountShareScope: ShareScope.private,
        perCategoryOverrides: {'Food': 'household'},
        enableNudges: false,
        nudgeQuietHoursStart: '23:00',
        nudgeQuietHoursEnd: '07:00',
        createdAt: now,
        updatedAt: now,
      );

      final json = prefs.toJson();

      expect(json['id'], 'pref_1');
      expect(json['user_id'], 'user_1');
      expect(json['household_id'], 'hh_1');
      expect(json['default_transaction_share_scope'], 'household');
      expect(json['default_account_share_scope'], 'private');
      expect(json['per_category_overrides'], {'Food': 'household'});
      expect(json['enable_nudges'], false);
      expect(json['nudge_quiet_hours_start'], '23:00');
      expect(json['nudge_quiet_hours_end'], '07:00');
      expect(json['created_at'], '2024-01-01T00:00:00.000');
      expect(json['updated_at'], '2024-01-01T00:00:00.000');
    });
  });
}
