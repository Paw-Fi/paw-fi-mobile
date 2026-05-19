import 'package:moneko/core/recurring/recurring_transaction_inference.dart';
import 'package:moneko/core/utils/user_timezone.dart';
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

class PlaidSyncStatus {
  const PlaidSyncStatus({
    required this.initialUpdateComplete,
    required this.historicalUpdateComplete,
    this.webhookCode,
    this.updatedAt,
  });

  final bool? initialUpdateComplete;
  final bool? historicalUpdateComplete;
  final String? webhookCode;
  final DateTime? updatedAt;

  bool get isHistoricalBackfillComplete => historicalUpdateComplete == true;
}

class ParsedSyncedTransactions {
  const ParsedSyncedTransactions({
    required this.transactions,
    this.syncStatus,
  });

  final List<SyncedTransaction> transactions;
  final PlaidSyncStatus? syncStatus;
}

List<SyncedTransaction> parseSyncedTransactions(dynamic payload) {
  return parseSyncedTransactionPayload(payload).transactions;
}

ParsedSyncedTransactions parseSyncedTransactionPayload(dynamic payload) {
  List<dynamic>? rawList;
  PlaidSyncStatus? syncStatus;
  if (payload is Map<String, dynamic>) {
    rawList = payload['addedTransactions'] as List<dynamic>?;
    rawList ??= (payload['data'] as Map<String, dynamic>?)?['addedTransactions']
        as List<dynamic>?;
    syncStatus = _parsePlaidSyncStatus(
      payload['syncStatus'] as Map<String, dynamic>?,
    );
  }
  if (rawList == null) {
    return ParsedSyncedTransactions(
      transactions: const [],
      syncStatus: syncStatus,
    );
  }

  final transactions = rawList.map((item) {
    final map = item as Map<String, dynamic>;
    final rawDate = map['date']?.toString();
    final dateOnly = tryParseDateOnlyYmd(rawDate);
    final parsedDate = DateTime.tryParse(rawDate ?? '');
    final expense = ExpenseEntry(
      id: map['id'] as String,
      contactId: map['contact_id'] as String?,
      userId: map['user_id'] as String?,
      userName: null,
      userAvatarUrl: null,
      householdId: map['household_id'] as String?,
      date: dateOnly != null
          ? DateTime(dateOnly.year, dateOnly.month, dateOnly.day)
          : (parsedDate != null
              ? DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
              : DateTime.fromMillisecondsSinceEpoch(0)),
      amountCents: (map['amount_cents'] as num).toInt(),
      currency: canonicalizeCurrencyCode(map['currency'] as String?),
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      rawText: map['raw_text'] as String?,
      merchant: map['merchant'] as String?,
      receiptImageUrl: null,
      sharedMemberIds: null,
      splitGroupId: null,
      bankAccountId: map['bank_account_id'] as String?,
      walletId: map['account_id'] as String?,
      type: map['type'] as String?,
    );

    return SyncedTransaction(
      expense: expense.copyWith(isRecurring: map['is_recurring'] == true),
      isRecurring: map['is_recurring'] == true,
      recurrenceRule: map['recurrence_rule'] as Map<String, dynamic>?,
    );
  }).toList();

  return ParsedSyncedTransactions(
    transactions: inferSyncedRecurringTransactions(transactions),
    syncStatus: syncStatus,
  );
}

PlaidSyncStatus? _parsePlaidSyncStatus(Map<String, dynamic>? map) {
  if (map == null) {
    return null;
  }

  return PlaidSyncStatus(
    initialUpdateComplete: map['initialUpdateComplete'] as bool?,
    historicalUpdateComplete: map['historicalUpdateComplete'] as bool?,
    webhookCode: map['webhookCode'] as String?,
    updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
  );
}

List<SyncedTransaction> inferSyncedRecurringTransactions(
  List<SyncedTransaction> transactions,
) {
  final inferred = inferRecurringTransactions(
    transactions.map(
      (transaction) => RecurringInferenceInput(
        id: transaction.expense.id,
        date: transaction.expense.date,
        amountCents: transaction.expense.amountCents,
        currency: transaction.expense.currency,
        type: transaction.expense.type,
        accountId: transaction.expense.bankAccountId,
        merchant: transaction.expense.merchant,
        description: transaction.expense.rawText,
        isRecurring: transaction.isRecurring,
        recurrenceRule: transaction.recurrenceRule,
      ),
    ),
  );

  return transactions.map((transaction) {
    final result = inferred[transaction.expense.id];
    if (result == null || !result.isRecurring) return transaction;
    return SyncedTransaction(
      expense: transaction.expense.copyWith(isRecurring: true),
      isRecurring: true,
      recurrenceRule: result.recurrenceRule,
    );
  }).toList(growable: false);
}
