import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/utils/currency.dart';

/// Lightweight view model for newly synced transactions coming from Plaid sync.
class SyncedTransaction {
  final ExpenseEntry expense;
  final bool isRecurring;
  final Map<String, dynamic>? recurrenceRule;

  SyncedTransaction({
    required this.expense,
    required this.isRecurring,
    required this.recurrenceRule,
  });
}

List<SyncedTransaction> parseSyncedTransactions(dynamic payload) {
  List<dynamic>? rawList;
  if (payload is Map<String, dynamic>) {
    rawList = payload['addedTransactions'] as List<dynamic>?;
    rawList ??= (payload['data'] as Map<String, dynamic>?)?['addedTransactions']
        as List<dynamic>?;
  }
  if (rawList == null) return [];

  return rawList.map((item) {
    final map = item as Map<String, dynamic>;
    final expense = ExpenseEntry(
      id: map['id'] as String,
      contactId: map['contact_id'] as String?,
      userId: map['user_id'] as String?,
      userName: null,
      userAvatarUrl: null,
      householdId: map['household_id'] as String?,
      date: DateTime.parse(map['date'] as String),
      amountCents: (map['amount_cents'] as num).toInt(),
      currency: canonicalizeCurrencyCode(map['currency'] as String?),
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      rawText: map['raw_text'] as String?,
      receiptImageUrl: null,
      sharedMemberIds: null,
      splitGroupId: null,
      type: map['type'] as String?,
    );

    return SyncedTransaction(
      expense: expense,
      isRecurring: map['is_recurring'] == true,
      recurrenceRule: map['recurrence_rule'] as Map<String, dynamic>?,
    );
  }).toList();
}
