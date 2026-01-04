import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';

void main() {
  group('DailyBudgetEntry - Model Creation', () {
    test('creates daily budget entry with all fields', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      expect(entry.id, 'budget_123');
      expect(entry.contactId, 'contact_1');
      expect(entry.date, DateTime(2024, 1, 15));
      expect(entry.amountCents, 5000);
      expect(entry.currency, 'USD');
    });

    test('creates daily budget entry with null optional fields', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: null,
      );

      expect(entry.contactId, null);
      expect(entry.currency, null);
    });
  });

  group('DailyBudgetEntry - Computed Properties', () {
    test('amount getter converts cents to dollars correctly', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      expect(entry.amount, 50.0);
    });

    test('amount getter handles zero cents', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 0,
        currency: 'USD',
      );

      expect(entry.amount, 0.0);
    });

    test('amount getter handles fractional cents', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 5025,
        currency: 'USD',
      );

      expect(entry.amount, 50.25);
    });

    test('amount getter handles large amounts', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 999999999,
        currency: 'USD',
      );

      expect(entry.amount, 9999999.99);
    });
  });

  group('DailyBudgetEntry - CopyWith', () {
    test('copyWith creates new instance with updated id', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith(id: 'budget_456');

      expect(updated.id, 'budget_456');
      expect(updated.contactId, 'contact_1');
      expect(updated.amountCents, 5000);
    });

    test('copyWith creates new instance with updated contactId', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith(contactId: 'contact_2');

      expect(updated.contactId, 'contact_2');
    });

    test('copyWith creates new instance with updated date', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith(date: DateTime(2024, 1, 16));

      expect(updated.date, DateTime(2024, 1, 16));
    });

    test('copyWith creates new instance with updated amountCents', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith(amountCents: 10000);

      expect(updated.amountCents, 10000);
      expect(updated.amount, 100.0);
    });

    test('copyWith creates new instance with updated currency', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith(currency: 'EUR');

      expect(updated.currency, 'EUR');
    });

    test('copyWith with no parameters returns same values', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: 'contact_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      final updated = entry.copyWith();

      expect(updated.id, entry.id);
      expect(updated.contactId, entry.contactId);
      expect(updated.date, entry.date);
      expect(updated.amountCents, entry.amountCents);
      expect(updated.currency, entry.currency);
    });
  });

  group('DailyBudgetEntry - JSON Serialization', () {
    test('fromJson parses daily budget entry correctly', () {
      final json = {
        'id': 'budget_123',
        'contact_id': 'contact_1',
        'date': '2024-01-15',
        'amount_cents': 5000,
        'currency': 'USD',
      };

      final entry = DailyBudgetEntry.fromJson(json);

      expect(entry.id, 'budget_123');
      expect(entry.contactId, 'contact_1');
      expect(entry.date, DateTime(2024, 1, 15));
      expect(entry.amountCents, 5000);
      expect(entry.currency, 'USD');
    });

    test('fromJson handles null contact_id', () {
      final json = {
        'id': 'budget_123',
        'contact_id': null,
        'date': '2024-01-15',
        'amount_cents': 5000,
        'currency': 'USD',
      };

      final entry = DailyBudgetEntry.fromJson(json);

      expect(entry.contactId, null);
    });

    test('fromJson handles null currency', () {
      final json = {
        'id': 'budget_123',
        'contact_id': 'contact_1',
        'date': '2024-01-15',
        'amount_cents': 5000,
        'currency': null,
      };

      final entry = DailyBudgetEntry.fromJson(json);

      expect(entry.currency, null);
    });

    test('fromJson canonicalizes currency code', () {
      final json = {
        'id': 'budget_123',
        'contact_id': 'contact_1',
        'date': '2024-01-15',
        'amount_cents': 5000,
        'currency': 'usd',
      };

      final entry = DailyBudgetEntry.fromJson(json);

      expect(entry.currency, 'USD');
    });

    test('fromJson parses date with time component', () {
      final json = {
        'id': 'budget_123',
        'contact_id': 'contact_1',
        'date': '2024-01-15T10:30:45Z',
        'amount_cents': 5000,
        'currency': 'USD',
      };

      final entry = DailyBudgetEntry.fromJson(json);

      expect(entry.date.year, 2024);
      expect(entry.date.month, 1);
      expect(entry.date.day, 15);
    });
  });

  group('DailyBudgetEntry - Edge Cases', () {
    test('handles zero amount', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 0,
        currency: 'USD',
      );

      expect(entry.amountCents, 0);
      expect(entry.amount, 0.0);
    });

    test('handles negative amount', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: -5000,
        currency: 'USD',
      );

      expect(entry.amountCents, -5000);
      expect(entry.amount, -50.0);
    });

    test('handles very large amount', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 999999999,
        currency: 'USD',
      );

      expect(entry.amount, 9999999.99);
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY'];

      for (final code in currencies) {
        final entry = DailyBudgetEntry(
          id: 'budget_123',
          contactId: null,
          date: DateTime(2024, 1, 15),
          amountCents: 5000,
          currency: code,
        );

        expect(entry.currency, code);
      }
    });

    test('handles dates at year boundaries', () {
      final entry1 = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2023, 12, 31),
        amountCents: 5000,
        currency: 'USD',
      );

      final entry2 = DailyBudgetEntry(
        id: 'budget_456',
        contactId: null,
        date: DateTime(2024, 1, 1),
        amountCents: 5000,
        currency: 'USD',
      );

      expect(entry1.date, DateTime(2023, 12, 31));
      expect(entry2.date, DateTime(2024, 1, 1));
    });

    test('handles leap year dates', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 2, 29),
        amountCents: 5000,
        currency: 'USD',
      );

      expect(entry.date, DateTime(2024, 2, 29));
    });

    test('handles empty string id', () {
      final entry = DailyBudgetEntry(
        id: '',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
      );

      expect(entry.id, '');
    });

    test('handles single cent amount', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 1,
        currency: 'USD',
      );

      expect(entry.amount, 0.01);
    });

    test('handles amount with precision', () {
      final entry = DailyBudgetEntry(
        id: 'budget_123',
        contactId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 12345,
        currency: 'USD',
      );

      expect(entry.amount, 123.45);
    });
  });
}
