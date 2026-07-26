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
}
