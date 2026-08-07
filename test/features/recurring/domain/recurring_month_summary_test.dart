import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/recurring_month_summary.dart';

void main() {
  group('calculateRecurringMonthlyCommittedAmount', () {
    test('uses the confirmed current-month amount delta', () {
      final summary = RecurringSeriesSummary(
        transaction: _monthlyTransaction(amount: 500),
        nextOccurrenceDate: DateTime(2026, 8, 7),
        latestActionableOccurrenceDate: null,
        currentMonthConfirmedAmountDeltaCents: -500,
      );

      expect(calculateRecurringMonthlyCommittedAmount(summary), 495);
    });

    test('uses the template monthly amount when no occurrence is confirmed',
        () {
      final summary = RecurringSeriesSummary(
        transaction: _monthlyTransaction(amount: 500),
        nextOccurrenceDate: DateTime(2026, 8, 7),
        latestActionableOccurrenceDate: null,
      );

      expect(calculateRecurringMonthlyCommittedAmount(summary), 500);
    });
  });
}

RecurringTransaction _monthlyTransaction({required double amount}) {
  return RecurringTransaction(
    id: 'recurring-1',
    date: DateTime(2026, 1, 7),
    category: 'Bills',
    amount: amount,
    currency: 'SGD',
    ownerType: 'me',
    privacyScope: 'full',
    recurrenceRule: RecurrenceRule(
      frequency: 'monthly',
      anchorDate: DateTime(2026, 1, 7),
    ),
    type: 'expense',
    attachments: const [],
    createdAt: DateTime.utc(2026, 1, 1),
  );
}
