import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/core/theme/app_theme.dart';

void main() {
  group('PocketEnvelope - Model Creation', () {
    test('creates pocket envelope correctly', () {
      final now = DateTime.now();
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        icon: 'shopping_bag',
        color: '#FF5733',
        budgetId: 'budget_1',
        householdId: null,
        lastUpdated: now,
      );

      expect(pocket.id, 'pocket_1');
      expect(pocket.name, 'Groceries');
      expect(pocket.percentage, 25.0);
      expect(pocket.spent, 350.0);
      expect(pocket.currency, 'USD');
      expect(pocket.icon, 'shopping_bag');
      expect(pocket.color, '#FF5733');
      expect(pocket.budgetId, 'budget_1');
      expect(pocket.householdId, null);
    });

    test('creates pocket without optional fields', () {
      final pocket = PocketEnvelope(
        id: 'pocket_2',
        name: 'Bills',
        percentage: 30.0,
        spent: 420.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      expect(pocket.icon, null);
      expect(pocket.color, null);
      expect(pocket.budgetId, null);
      expect(pocket.householdId, null);
    });
  });

  group('PocketEnvelope - JSON Serialization', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'pocket_1',
        'name': 'Groceries',
        'budget_percentage': 25.0,
        'spent_cents': 35000,
        'currency': 'USD',
        'icon': 'shopping_bag',
        'color': '#FF5733',
        'budget_id': 'budget_1',
        'household_id': 'hh_123',
        'last_updated': '2024-01-01T00:00:00.000Z',
      };

      final pocket = PocketEnvelope.fromJson(json);

      expect(pocket.id, 'pocket_1');
      expect(pocket.name, 'Groceries');
      expect(pocket.percentage, 25.0);
      expect(pocket.spent, 350.0);
      expect(pocket.currency, 'USD');
      expect(pocket.icon, 'shopping_bag');
      expect(pocket.color, '#FF5733');
      expect(pocket.budgetId, 'budget_1');
      expect(pocket.householdId, 'hh_123');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'pocket_2',
        'name': 'Bills',
        'budget_percentage': 30.0,
        'spent_cents': 42000,
      };

      final pocket = PocketEnvelope.fromJson(json);

      expect(pocket.currency, 'USD'); // Default
      expect(pocket.icon, null);
      expect(pocket.color, null);
      expect(pocket.budgetId, null);
      expect(pocket.householdId, null);
    });

    test('fromJson handles zero spent', () {
      final json = {
        'id': 'pocket_3',
        'name': 'Savings',
        'budget_percentage': 20.0,
        'spent_cents': 0,
        'currency': 'EUR',
      };

      final pocket = PocketEnvelope.fromJson(json);

      expect(pocket.spent, 0.0);
    });

    test('toJson serializes correctly', () {
      final now = DateTime.parse('2024-01-01T00:00:00.000Z');
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        icon: 'shopping_bag',
        color: '#FF5733',
        budgetId: 'budget_1',
        householdId: 'hh_123',
        lastUpdated: now,
      );

      final json = pocket.toJson();

      expect(json['id'], 'pocket_1');
      expect(json['name'], 'Groceries');
      expect(json['budget_percentage'], 25.0);
      expect(json['spent_cents'], 35000);
      expect(json['currency'], 'USD');
      expect(json['icon'], 'shopping_bag');
      expect(json['color'], '#FF5733');
      expect(json['budget_id'], 'budget_1');
      expect(json['household_id'], 'hh_123');
    });
  });

  group('PocketEnvelope - Budget Calculations', () {
    test('getLimit calculates correctly', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      final limit = pocket.getLimit(totalBudget);

      expect(limit, 500.0); // 25% of 2000
    });

    test('getLimit rounds to cents', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 33.33,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 1000.0;
      final limit = pocket.getLimit(totalBudget);

      // 33.33% of 1000 = 333.3, rounded to cents = 333.30
      expect(limit, 333.3);
    });

    test('getLimit handles zero budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 25.0,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final limit = pocket.getLimit(0.0);

      expect(limit, 0.0);
    });

    test('getProgress calculates correctly', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 250.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      final progress = pocket.getProgress(totalBudget);

      expect(progress, 0.5); // 250 / 500 = 0.5
    });

    test('getProgress clamps to 1.0 when over budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 600.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      final progress = pocket.getProgress(totalBudget);

      expect(progress, 1.0); // Clamped to 1.0
    });

    test('getProgress handles zero limit', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 0.0,
        spent: 100.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final progress = pocket.getProgress(1000.0);

      expect(progress, 1.0); // Returns 1.0 when limit is 0
    });

    test('getProgress clamps to 0.0 minimum', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 25.0,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final progress = pocket.getProgress(1000.0);

      expect(progress, 0.0);
    });
  });

  group('PocketEnvelope - Budget Status', () {
    test('isOverBudget returns true when spent exceeds limit', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 600.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      expect(pocket.isOverBudget(totalBudget), true);
    });

    test('isOverBudget returns false when within budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 400.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      expect(pocket.isOverBudget(totalBudget), false);
    });

    test('isNearLimit returns true when spent >= 85% of limit', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 430.0, // 86% of 500
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      expect(pocket.isNearLimit(totalBudget), true);
    });

    test('isNearLimit returns false when spent < 85% of limit', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 400.0, // 80% of 500
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      expect(pocket.isNearLimit(totalBudget), false);
    });

    test('isNearLimit returns false when over budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 600.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 2000.0;
      expect(pocket.isNearLimit(totalBudget), false);
    });

    test('statusColor returns danger when over budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 600.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const safeColor = Colors.green;
      const totalBudget = 2000.0;
      final color = pocket.statusColor(safeColor, totalBudget);

      expect(color, AppTheme.danger);
    });

    test('statusColor returns warning when near limit', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 430.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const safeColor = Colors.green;
      const totalBudget = 2000.0;
      final color = pocket.statusColor(safeColor, totalBudget);

      expect(color, AppTheme.warning);
    });

    test('statusColor returns safe color when within budget', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 300.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const safeColor = Colors.green;
      const totalBudget = 2000.0;
      final color = pocket.statusColor(safeColor, totalBudget);

      expect(color, safeColor);
    });
  });

  group('PocketEnvelope - CopyWith', () {
    test('copies with new percentage', () {
      final original = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final copied = original.copyWith(percentage: 30.0);

      expect(copied.percentage, 30.0);
      expect(copied.id, original.id);
      expect(copied.name, original.name);
      expect(copied.spent, original.spent);
    });

    test('copies with new spent amount', () {
      final original = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final copied = original.copyWith(spent: 400.0);

      expect(copied.spent, 400.0);
      expect(copied.percentage, original.percentage);
    });

    test('copies with new icon and color', () {
      final original = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final copied = original.copyWith(
        icon: 'restaurant',
        color: '#FF0000',
      );

      expect(copied.icon, 'restaurant');
      expect(copied.color, '#FF0000');
    });

    test('copies with multiple fields', () {
      final original = PocketEnvelope(
        id: 'pocket_1',
        name: 'Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      final copied = original.copyWith(
        percentage: 30.0,
        spent: 400.0,
        currency: 'EUR',
      );

      expect(copied.percentage, 30.0);
      expect(copied.spent, 400.0);
      expect(copied.currency, 'EUR');
    });
  });

  group('PocketEnvelope - Edge Cases', () {
    test('handles very large budget amounts', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 25.0,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 1000000.0;
      final limit = pocket.getLimit(totalBudget);

      expect(limit, 250000.0);
    });

    test('handles very small percentages', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 0.01,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 10000.0;
      final limit = pocket.getLimit(totalBudget);

      expect(limit, 1.0);
    });

    test('handles 100% percentage', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 100.0,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 1000.0;
      final limit = pocket.getLimit(totalBudget);

      expect(limit, 1000.0);
    });

    test('handles fractional cents correctly', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Test',
        percentage: 33.333,
        spent: 0.0,
        currency: 'USD',
        lastUpdated: DateTime.now(),
      );

      const totalBudget = 999.99;
      final limit = pocket.getLimit(totalBudget);

      // Should round to nearest cent
      expect(limit.toStringAsFixed(2), '333.33');
    });
  });

  group('PocketEnvelope - Currency Handling', () {
    test('supports different currencies', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY'];

      for (final currency in currencies) {
        final pocket = PocketEnvelope(
          id: 'pocket_$currency',
          name: 'Test',
          percentage: 25.0,
          spent: 100.0,
          currency: currency,
          lastUpdated: DateTime.now(),
        );

        expect(pocket.currency, currency);
      }
    });

    test('defaults to USD when currency not specified in JSON', () {
      final json = {
        'id': 'pocket_1',
        'name': 'Test',
        'budget_percentage': 25.0,
        'spent_cents': 10000,
      };

      final pocket = PocketEnvelope.fromJson(json);

      expect(pocket.currency, 'USD');
    });
  });

  group('PocketEnvelope - Household Support', () {
    test('supports household pockets', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Shared Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        householdId: 'hh_123',
        lastUpdated: DateTime.now(),
      );

      expect(pocket.householdId, 'hh_123');
    });

    test('supports personal pockets', () {
      final pocket = PocketEnvelope(
        id: 'pocket_1',
        name: 'Personal Groceries',
        percentage: 25.0,
        spent: 350.0,
        currency: 'USD',
        householdId: null,
        lastUpdated: DateTime.now(),
      );

      expect(pocket.householdId, null);
    });
  });
}
