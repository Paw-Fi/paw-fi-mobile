import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

void main() {
  final recurringTransaction = RecurringTransaction(
    id: 'recurring-id',
    date: DateTime(2026, 7, 1),
    category: 'housing',
    amount: 100,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    type: 'expense',
    attachments: const [],
    createdAt: DateTime(2026, 7, 1),
  );

  test('includes editable financial fields for an unlocked occurrence', () {
    final command = RecurringOccurrenceUpdateCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
      ),
      paidDate: DateTime(2026, 7, 2),
      amountCents: 12550,
      accountId: 'account-id',
      merchant: 'Landlord',
      description: 'July rent',
      updateFutureAmount: true,
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
      'paidDate': '2026-07-02',
      'amount': 125.5,
      'accountId': 'account-id',
      'merchant': 'Landlord',
      'updateFutureAmount': true,
      'description': 'July rent',
    });
  });

  test('sends only notes for a settlement-locked occurrence', () {
    final command = RecurringOccurrenceUpdateCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
        isSettlementLocked: true,
      ),
      paidDate: DateTime(2026, 7, 2),
      amountCents: null,
      accountId: null,
      merchant: 'Landlord',
      description: 'Corrected note',
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
      'description': 'Corrected note',
    });
  });

  test('builds an unconfirm request for a confirmed occurrence', () {
    final command = RecurringOccurrenceUnconfirmCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
      ),
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
    });
  });
}
