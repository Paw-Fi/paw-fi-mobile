import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_review_page.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  group('plaidClassificationOverrideRpcName', () {
    test('uses the grouped override for classification-review rows', () {
      final transaction = _transaction(
        classificationReviewState: 'needs_review',
      );

      expect(
        plaidClassificationOverrideRpcName(transaction),
        'set_transaction_analytics_override_group_v1',
      );
    });

    test('uses the single override for transfer-suggestion-only rows', () {
      final transaction = _transaction();

      expect(
        plaidClassificationOverrideRpcName(transaction),
        'set_transaction_analytics_override_v1',
      );
    });
  });
}

SyncedTransaction _transaction({
  String classificationReviewState = 'not_required',
}) {
  return SyncedTransaction(
    expense: ExpenseEntry(
      id: 'expense-1',
      date: DateTime(2026, 9, 17),
      amountCents: 85400,
      createdAt: DateTime(2026, 9, 17),
    ),
    isRecurring: false,
    recurrenceRule: null,
    classificationReviewState: classificationReviewState,
  );
}
