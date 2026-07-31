import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/utils/recurring_occurrence_schedule.dart';

RecurringTransaction _transaction({
  required bool reminderEnabled,
  required int reminderValue,
  required String reminderUnit,
}) {
  return RecurringTransaction(
    id: 'recurring-id',
    date: DateTime(2026, 7, 26),
    category: 'rent',
    description: 'Rent',
    source: null,
    amount: 1000,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: null,
    payerUserId: null,
    recurrenceRule: RecurrenceRule(
      frequency: 'monthly',
      anchorDate: DateTime(2026, 7, 26),
      reminderEnabled: reminderEnabled,
      reminderValue: reminderValue,
      reminderUnit: reminderUnit,
    ),
    type: 'expense',
    attachments: const [],
    createdAt: DateTime(2026, 7, 1),
    updatedAt: null,
  );
}

void main() {
  final scheduledOccurrence = DateTime(2026, 8, 26);

  test('history dates do not duplicate a skipped future reference', () {
    final staleFutureReference = DateTime(2026, 7, 27, 12);
    final skippedDate = DateTime(2026, 7, 27, 8);

    final dates = mergeRecurringHistoryOccurrenceDates(
      futureReference: staleFutureReference,
      occurrences: [
        DateTime(2026, 3, 27),
        DateTime(2026, 4, 27),
        DateTime(2026, 5, 27),
        DateTime(2026, 6, 27),
        skippedDate,
      ],
    );

    expect(dates, [
      staleFutureReference,
      DateTime(2026, 6, 27),
      DateTime(2026, 5, 27),
      DateTime(2026, 4, 27),
      DateTime(2026, 3, 27),
    ]);
  });

  test('history dates prepend a distinct future reference', () {
    expect(
      mergeRecurringHistoryOccurrenceDates(
        futureReference: DateTime(2026, 8, 27),
        occurrences: [
          DateTime(2026, 6, 27),
          DateTime(2026, 7, 27),
        ],
      ),
      [
        DateTime(2026, 8, 27),
        DateTime(2026, 7, 27),
        DateTime(2026, 6, 27),
      ],
    );
  });

  test('opens confirmation on the configured reminder date', () {
    final transaction = _transaction(
      reminderEnabled: true,
      reminderValue: 3,
      reminderUnit: 'days',
    );

    expect(
      confirmationOpensAt(transaction, scheduledOccurrence),
      DateTime(2026, 8, 23),
    );
    expect(
      canConfirmOccurrenceAt(
        transaction,
        scheduledOccurrence,
        DateTime(2026, 8, 22, 23, 59),
      ),
      isFalse,
    );
    expect(
      canConfirmOccurrenceAt(
        transaction,
        scheduledOccurrence,
        DateTime(2026, 8, 23),
      ),
      isTrue,
    );
  });

  test('does not open early when reminders are disabled', () {
    final transaction = _transaction(
      reminderEnabled: false,
      reminderValue: 3,
      reminderUnit: 'days',
    );

    expect(
      canConfirmOccurrenceAt(
        transaction,
        scheduledOccurrence,
        DateTime(2026, 8, 25, 23, 59),
      ),
      isFalse,
    );
  });

  test('allows submission inside reminder window with a non-future paid date',
      () {
    final transaction = _transaction(
      reminderEnabled: true,
      reminderValue: 3,
      reminderUnit: 'days',
    );

    expect(
      canSubmitRecurringOccurrenceConfirmationAt(
        transaction: transaction,
        scheduledOccurrenceDate: scheduledOccurrence,
        paidDate: DateTime(2026, 8, 23),
        userNow: DateTime(2026, 8, 23, 9),
      ),
      isTrue,
    );
    expect(
      canSubmitRecurringOccurrenceConfirmationAt(
        transaction: transaction,
        scheduledOccurrenceDate: scheduledOccurrence,
        paidDate: DateTime(2026, 8, 23),
        userNow: DateTime(2026, 8, 22, 23, 59),
      ),
      isFalse,
    );
    expect(
      canSubmitRecurringOccurrenceConfirmationAt(
        transaction: transaction,
        scheduledOccurrenceDate: scheduledOccurrence,
        paidDate: DateTime(2026, 8, 24),
        userNow: DateTime(2026, 8, 23, 9),
      ),
      isFalse,
    );
  });
}
