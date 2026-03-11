import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

void main() {
  test('projects every 6 month recurring transactions and preserves source id',
      () {
    final transaction = RecurringTransaction(
      id: 'rec_source',
      date: DateTime(2026, 1, 10),
      category: 'insurance',
      description: 'Insurance renewal',
      amount: 120.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: DateTime(2026, 1, 10),
        interval: 6,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final projected = projectRecurringTransactionsAsExpenseEntries(
      recurringTransactions: [transaction],
      rangeStart: DateTime(2026, 7, 1),
      rangeEnd: DateTime(2026, 7, 31),
      selectedCurrency: 'USD',
    );

    expect(projected, hasLength(1));
    expect(projected.single.date, DateTime(2026, 7, 10));
    expect(
      extractRecurringTransactionIdFromProjectedExpenseId(projected.single.id),
      'rec_source',
    );
  });
}
