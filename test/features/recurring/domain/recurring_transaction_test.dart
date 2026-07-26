import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

void main() {
  test('next occurrence advances past skipped monthly occurrence', () {
    final transaction = RecurringTransaction(
      id: 'recurring-id',
      date: DateTime(2026, 7, 15),
      category: 'Housing',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 7, 15),
        excludedDates: [DateTime(2026, 8, 15)],
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 7, 1),
    );

    expect(
      transaction.getNextOccurrence(DateTime(2026, 8, 1)),
      DateTime(2026, 9, 15),
    );
  });

  test('next occurrence advances past consecutive skipped occurrences', () {
    final transaction = RecurringTransaction(
      id: 'recurring-id',
      date: DateTime(2026, 7, 15),
      category: 'Housing',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 7, 15),
        excludedDates: [DateTime(2026, 8, 15), DateTime(2026, 9, 15)],
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 7, 1),
    );

    expect(
      transaction.getNextOccurrence(DateTime(2026, 8, 1)),
      DateTime(2026, 10, 15),
    );
  });

  test('zero recurrence interval falls back to one interval', () {
    final transaction = RecurringTransaction(
      id: 'recurring-id',
      date: DateTime(2026, 7, 15),
      category: 'Housing',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 7, 15),
        interval: 0,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 7, 1),
    );

    expect(
      transaction.getNextOccurrence(DateTime(2026, 8, 1)),
      DateTime(2026, 8, 15),
    );
  });
}
