import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  group('ExpenseEntry - Model Creation', () {
    test('creates expense entry with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final entry = ExpenseEntry(
        id: 'exp_1',
        date: now,
        amountCents: 10000,
        createdAt: now,
      );

      expect(entry.id, 'exp_1');
      expect(entry.date, now);
      expect(entry.amountCents, 10000);
      expect(entry.amount, 100.0);
      expect(entry.createdAt, now);
      expect(entry.contactId, null);
      expect(entry.userId, null);
      expect(entry.currency, null);
    });

    test('creates expense entry with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final entry = ExpenseEntry(
        id: 'exp_1',
        contactId: 'contact_1',
        userId: 'user_1',
        userName: 'John Doe',
        userAvatarUrl: 'https://example.com/avatar.jpg',
        householdId: 'hh_1',
        date: now,
        amountCents: 10000,
        currency: 'USD',
        category: 'Food',
        createdAt: now,
        updatedAt: now,
        rawText: 'Lunch at restaurant',
        receiptImageUrl: 'https://example.com/receipt.jpg',
        sharedMemberIds: ['user_1', 'user_2'],
        splitGroupId: 'split_1',
        type: 'expense',
      );

      expect(entry.contactId, 'contact_1');
      expect(entry.userId, 'user_1');
      expect(entry.userName, 'John Doe');
      expect(entry.userAvatarUrl, 'https://example.com/avatar.jpg');
      expect(entry.householdId, 'hh_1');
      expect(entry.currency, 'USD');
      expect(entry.category, 'Food');
      expect(entry.rawText, 'Lunch at restaurant');
      expect(entry.receiptImageUrl, 'https://example.com/receipt.jpg');
      expect(entry.sharedMemberIds, ['user_1', 'user_2']);
      expect(entry.splitGroupId, 'split_1');
      expect(entry.type, 'expense');
    });

    test('amount getter converts cents to major units', () {
      final entry = ExpenseEntry(
        id: 'exp_1',
        date: DateTime(2024, 1, 1),
        amountCents: 12345,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(entry.amount, 123.45);
    });
  });

  group('ExpenseEntry - JSON Serialization', () {
    test('fromJson parses expense entry correctly', () {
      final json = {
        'id': 'exp_1',
        'contact_id': 'contact_1',
        'user_id': 'user_1',
        'household_id': 'hh_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'currency': 'USD',
        'category': 'Food',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T12:00:00.000Z',
        'raw_text': 'Lunch',
        'receipt_image_url': 'https://example.com/receipt.jpg',
        'shared_member_ids': ['user_1', 'user_2'],
        'split_group_id': 'split_1',
        'type': 'expense',
        'is_recurring': true,
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.id, 'exp_1');
      expect(entry.contactId, 'contact_1');
      expect(entry.userId, 'user_1');
      expect(entry.householdId, 'hh_1');
      expect(entry.date, DateTime(2024, 1, 1));
      expect(entry.amountCents, 10000);
      expect(entry.currency, 'USD');
      expect(entry.category, 'Food');
      expect(entry.createdAt, DateTime.utc(2024, 1, 1));
      expect(entry.updatedAt, DateTime.utc(2024, 1, 1, 12));
      expect(entry.rawText, 'Lunch');
      expect(entry.sharedMemberIds, ['user_1', 'user_2']);
      expect(entry.type, 'expense');
      expect(entry.isRecurring, true);
    });

    test('fromJson parses nested users object', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
        'users': {
          'full_name': 'Jane Smith',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.userName, 'Jane Smith');
      expect(entry.userAvatarUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson handles null date gracefully', () {
      final json = {
        'id': 'exp_1',
        'date': null,
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.date, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('fromJson handles empty date string', () {
      final json = {
        'id': 'exp_1',
        'date': '',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.date, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('fromJson parses amount_cents as int', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.amountCents, 10000);
    });

    test('fromJson parses amount_cents as double', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000.5,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.amountCents, 10001);
    });

    test('fromJson parses amount_cents as string', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': '10000',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.amountCents, 10000);
    });

    test('fromJson handles invalid amount_cents', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 'invalid',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.amountCents, 0);
    });

    test('fromJson handles null amount_cents', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': null,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.amountCents, 0);
    });

    test('fromJson handles null id as empty string', () {
      final json = {
        'id': null,
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.id, '');
    });

    test('fromJson canonicalizes currency code', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'currency': 'usd',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.currency, 'USD');
    });

    test('toJson serializes expense entry correctly', () {
      final now = DateTime(2024, 1, 1);
      final entry = ExpenseEntry(
        id: 'exp_1',
        contactId: 'contact_1',
        userId: 'user_1',
        userName: 'John Doe',
        userAvatarUrl: 'https://example.com/avatar.jpg',
        householdId: 'hh_1',
        date: now,
        amountCents: 10000,
        currency: 'USD',
        category: 'Food',
        createdAt: now,
        updatedAt: now,
        rawText: 'Lunch',
        receiptImageUrl: 'https://example.com/receipt.jpg',
        sharedMemberIds: ['user_1', 'user_2'],
        splitGroupId: 'split_1',
        type: 'expense',
      );

      final json = entry.toJson();

      expect(json['id'], 'exp_1');
      expect(json['contact_id'], 'contact_1');
      expect(json['user_id'], 'user_1');
      expect(json['user_name'], 'John Doe');
      expect(json['user_avatar_url'], 'https://example.com/avatar.jpg');
      expect(json['household_id'], 'hh_1');
      expect(json['date'], '2024-01-01T00:00:00.000');
      expect(json['amount_cents'], 10000);
      expect(json['currency'], 'USD');
      expect(json['category'], 'Food');
      expect(json['created_at'], '2024-01-01T00:00:00.000');
      expect(json['updated_at'], '2024-01-01T00:00:00.000');
      expect(json['raw_text'], 'Lunch');
      expect(json['receipt_image_url'], 'https://example.com/receipt.jpg');
      expect(json['shared_member_ids'], ['user_1', 'user_2']);
      expect(json['split_group_id'], 'split_1');
      expect(json['type'], 'expense');
    });
  });

  group('ExpenseEntry - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final now = DateTime(2024, 1, 1);
      final original = ExpenseEntry(
        id: 'exp_1',
        date: now,
        amountCents: 10000,
        currency: 'USD',
        category: 'Food',
        createdAt: now,
      );

      final updated = original.copyWith(
        amountCents: 20000,
        category: 'Transport',
      );

      expect(updated.id, 'exp_1');
      expect(updated.amountCents, 20000);
      expect(updated.category, 'Transport');
      expect(updated.currency, 'USD');
      expect(updated.date, now);
    });

    test('copyWith without parameters returns identical values', () {
      final now = DateTime(2024, 1, 1);
      final original = ExpenseEntry(
        id: 'exp_1',
        date: now,
        amountCents: 10000,
        createdAt: now,
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.amountCents, original.amountCents);
      expect(copy.date, original.date);
    });
  });

  group('ExpenseEntry - Edge Cases', () {
    test('handles very large amount', () {
      final entry = ExpenseEntry(
        id: 'exp_1',
        date: DateTime(2024, 1, 1),
        amountCents: 999999999,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(entry.amount, 9999999.99);
    });

    test('handles zero amount', () {
      final entry = ExpenseEntry(
        id: 'exp_1',
        date: DateTime(2024, 1, 1),
        amountCents: 0,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(entry.amount, 0.0);
    });

    test('handles negative amount', () {
      final entry = ExpenseEntry(
        id: 'exp_1',
        date: DateTime(2024, 1, 1),
        amountCents: -5000,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(entry.amount, -50.0);
    });

    test('handles income type', () {
      final entry = ExpenseEntry(
        id: 'inc_1',
        date: DateTime(2024, 1, 1),
        amountCents: 10000,
        createdAt: DateTime(2024, 1, 1),
        type: 'income',
      );

      expect(entry.type, 'income');
    });

    test('handles empty shared member ids list', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
        'shared_member_ids': [],
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.sharedMemberIds, []);
    });

    test('handles multiple shared members', () {
      final json = {
        'id': 'exp_1',
        'date': '2024-01-01T00:00:00.000Z',
        'amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
        'shared_member_ids': ['user_1', 'user_2', 'user_3', 'user_4'],
      };

      final entry = ExpenseEntry.fromJson(json);

      expect(entry.sharedMemberIds!.length, 4);
    });
  });
}
