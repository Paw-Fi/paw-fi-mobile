import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  group('SyncedTransaction - Model Creation', () {
    test('creates synced transaction with all fields', () {
      final expense = ExpenseEntry(
        id: 'txn_123',
        contactId: 'contact_1',
        userId: 'user_1',
        userName: 'John Doe',
        userAvatarUrl: 'https://example.com/avatar.jpg',
        householdId: 'household_1',
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
        category: 'Food',
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
        rawText: 'Coffee Shop',
        receiptImageUrl: null,
        sharedMemberIds: null,
        splitGroupId: null,
        type: 'expense',
      );

      final synced = SyncedTransaction(
        expense: expense,
        isRecurring: true,
        recurrenceRule: {'frequency': 'monthly', 'interval': 1},
      );

      expect(synced.expense.id, 'txn_123');
      expect(synced.isRecurring, true);
      expect(synced.recurrenceRule!['frequency'], 'monthly');
    });

    test('creates synced transaction with null recurrence rule', () {
      final expense = ExpenseEntry(
        id: 'txn_123',
        contactId: null,
        userId: 'user_1',
        userName: null,
        userAvatarUrl: null,
        householdId: null,
        date: DateTime(2024, 1, 15),
        amountCents: 5000,
        currency: 'USD',
        category: 'Food',
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: null,
        rawText: null,
        receiptImageUrl: null,
        sharedMemberIds: null,
        splitGroupId: null,
        type: null,
      );

      final synced = SyncedTransaction(
        expense: expense,
        isRecurring: false,
        recurrenceRule: null,
      );

      expect(synced.isRecurring, false);
      expect(synced.recurrenceRule, null);
    });
  });

  group('parseSyncedTransactions - Function', () {
    test('parses transactions from addedTransactions at root level', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': 'contact_1',
            'user_id': 'user_1',
            'household_id': 'household_1',
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': '2024-01-15T11:00:00Z',
            'raw_text': 'Coffee Shop',
            'type': 'expense',
            'is_recurring': true,
            'recurrence_rule': {'frequency': 'monthly'},
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions.length, 1);
      expect(transactions[0].expense.id, 'txn_1');
      expect(transactions[0].expense.amountCents, 5000);
      expect(transactions[0].isRecurring, true);
      expect(transactions[0].recurrenceRule!['frequency'], 'monthly');
    });

    test('parses transactions from nested data.addedTransactions', () {
      final payload = {
        'data': {
          'addedTransactions': [
            {
              'id': 'txn_2',
              'contact_id': null,
              'user_id': 'user_2',
              'household_id': null,
              'date': '2024-01-16',
              'amount_cents': 3000,
              'currency': 'EUR',
              'category': 'Transport',
              'created_at': '2024-01-16T12:00:00Z',
              'updated_at': null,
              'raw_text': 'Uber',
              'type': 'expense',
              'is_recurring': false,
              'recurrence_rule': null,
            },
          ],
        },
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions.length, 1);
      expect(transactions[0].expense.id, 'txn_2');
      expect(transactions[0].expense.currency, 'EUR');
      expect(transactions[0].isRecurring, false);
      expect(transactions[0].recurrenceRule, null);
    });

    test('returns empty list when payload is null', () {
      final transactions = parseSyncedTransactions(null);
      expect(transactions.isEmpty, true);
    });

    test('returns empty list when addedTransactions is null', () {
      final payload = {'other_field': 'value'};
      final transactions = parseSyncedTransactions(payload);
      expect(transactions.isEmpty, true);
    });

    test('returns empty list when payload is not a map', () {
      final transactions = parseSyncedTransactions('invalid');
      expect(transactions.isEmpty, true);
    });

    test('parses multiple transactions', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Restaurant',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
          {
            'id': 'txn_2',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-16',
            'amount_cents': 3000,
            'currency': 'USD',
            'category': 'Transport',
            'created_at': '2024-01-16T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Gas',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
          {
            'id': 'txn_3',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-17',
            'amount_cents': 10000,
            'currency': 'USD',
            'category': 'Shopping',
            'created_at': '2024-01-17T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Amazon',
            'type': 'expense',
            'is_recurring': true,
            'recurrence_rule': {'frequency': 'monthly', 'interval': 1},
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions.length, 3);
      expect(transactions[0].expense.id, 'txn_1');
      expect(transactions[1].expense.id, 'txn_2');
      expect(transactions[2].expense.id, 'txn_3');
      expect(transactions[2].isRecurring, true);
    });

    test('handles null optional fields', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': null,
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': null,
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': null,
            'type': null,
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions.length, 1);
      expect(transactions[0].expense.contactId, null);
      expect(transactions[0].expense.userId, null);
      expect(transactions[0].expense.householdId, null);
      expect(transactions[0].expense.category, null);
      expect(transactions[0].expense.rawText, null);
      expect(transactions[0].expense.type, null);
    });

    test('handles is_recurring as false when not true', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Coffee',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].isRecurring, false);
    });

    test('handles is_recurring as null', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Coffee',
            'type': 'expense',
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].isRecurring, false);
    });

    test('canonicalizes currency codes', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'usd',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Coffee',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.currency, 'USD');
    });

    test('handles various currency codes', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'EUR',
            'category': 'Food',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Coffee',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
          {
            'id': 'txn_2',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-16',
            'amount_cents': 3000,
            'currency': 'GBP',
            'category': 'Transport',
            'created_at': '2024-01-16T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Taxi',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.currency, 'EUR');
      expect(transactions[1].expense.currency, 'GBP');
    });

    test('handles negative amounts', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': -5000,
            'currency': 'USD',
            'category': 'Refund',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Refund',
            'type': 'income',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.amountCents, -5000);
    });

    test('handles zero amounts', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 0,
            'currency': 'USD',
            'category': 'Other',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Zero amount',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.amountCents, 0);
    });

    test('handles very large amounts', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 999999999,
            'currency': 'USD',
            'category': 'Investment',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Large purchase',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.amountCents, 999999999);
    });

    test('handles complex recurrence rules', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Subscription',
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': 'Netflix',
            'type': 'expense',
            'is_recurring': true,
            'recurrence_rule': {
              'frequency': 'monthly',
              'interval': 1,
              'byweekday': null,
              'count': null,
              'until': null,
            },
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].recurrenceRule!['frequency'], 'monthly');
      expect(transactions[0].recurrenceRule!['interval'], 1);
    });

    test('handles empty addedTransactions array', () {
      final payload = {
        'addedTransactions': [],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions.isEmpty, true);
    });

    test('parses dates correctly', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': 'user_1',
            'household_id': null,
            'date': '2024-12-31',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': 'Food',
            'created_at': '2024-12-31T23:59:59Z',
            'updated_at': '2025-01-01T00:00:00Z',
            'raw_text': 'New Year Eve',
            'type': 'expense',
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.date, DateTime(2024, 12, 31));
      expect(transactions[0].expense.createdAt.year, 2024);
      expect(transactions[0].expense.updatedAt!.year, 2025);
    });

    test('sets null fields correctly in ExpenseEntry', () {
      final payload = {
        'addedTransactions': [
          {
            'id': 'txn_1',
            'contact_id': null,
            'user_id': null,
            'household_id': null,
            'date': '2024-01-15',
            'amount_cents': 5000,
            'currency': 'USD',
            'category': null,
            'created_at': '2024-01-15T10:00:00Z',
            'updated_at': null,
            'raw_text': null,
            'type': null,
            'is_recurring': false,
            'recurrence_rule': null,
          },
        ],
      };

      final transactions = parseSyncedTransactions(payload);

      expect(transactions[0].expense.userName, null);
      expect(transactions[0].expense.userAvatarUrl, null);
      expect(transactions[0].expense.receiptImageUrl, null);
      expect(transactions[0].expense.sharedMemberIds, null);
      expect(transactions[0].expense.splitGroupId, null);
    });
  });
}
