import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

int _optimisticTransactionSequence = 0;

String makeOptimisticTransactionId() =>
    'optimistic_${DateTime.now().microsecondsSinceEpoch}_${_optimisticTransactionSequence++}';

class TransactionMutationMetadata {
  const TransactionMutationMetadata({
    required this.clientRecordId,
    required this.clientMutationId,
    required this.idempotencyKey,
  });

  final String clientRecordId;
  final String clientMutationId;
  final String idempotencyKey;

  Map<String, dynamic> toRequestJson() {
    return {
      'clientRecordId': clientRecordId,
      'clientMutationId': clientMutationId,
      'idempotencyKey': idempotencyKey,
    };
  }
}

TransactionMutationMetadata buildTransactionMutationMetadata(
  String optimisticId,
) {
  final idempotencyKey = 'mobile:$optimisticId';
  return TransactionMutationMetadata(
    clientRecordId: optimisticId,
    clientMutationId: idempotencyKey,
    idempotencyKey: idempotencyKey,
  );
}

TransactionMutationMetadata buildTransactionMutationMetadataForRecord({
  required String clientRecordId,
  required String operation,
}) {
  final normalizedRecordId = clientRecordId.trim().isEmpty
      ? 'record'
      : clientRecordId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final normalizedOperation = operation.trim().isEmpty
      ? 'mutation'
      : operation.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final idempotencyKey = 'mobile:${normalizedOperation}_${normalizedRecordId}_'
      '${DateTime.now().microsecondsSinceEpoch}_'
      '${_optimisticTransactionSequence++}';

  return TransactionMutationMetadata(
    clientRecordId: clientRecordId,
    clientMutationId: idempotencyKey,
    idempotencyKey: idempotencyKey,
  );
}

ExpenseEntry buildOptimisticEntry({
  required ParsedExpense transaction,
  required String optimisticId,
  required String userId,
  required String type, // 'expense' | 'income'
  String? contactId,
  String? householdId,
  String? receiptImageUrl,
  String? accountId,
  String? splitGroupId,
}) {
  return ExpenseEntry(
    id: optimisticId,
    contactId: contactId,
    userId: userId,
    householdId: householdId,
    date: transaction.date,
    amountCents: transaction.amountCents.abs(),
    currency: transaction.currency,
    category: transaction.category,
    createdAt: DateTime.now(),
    rawText: transaction.description,
    merchant: transaction.merchant,
    breakdown: transaction.breakdown,
    receiptImageUrl: receiptImageUrl,
    splitGroupId: splitGroupId,
    walletId: accountId,
    type: type,
  );
}

void addOptimisticTransaction({
  required WidgetRef ref,
  required ExpenseEntry entry,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(householdId, entry);
    return;
  }

  ref.read(analyticsProvider.notifier).addOptimisticTransaction(entry);
}

void removeOptimisticTransaction({
  required WidgetRef ref,
  required String optimisticId,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .removeExpense(householdId, optimisticId);
    return;
  }

  ref.read(analyticsProvider.notifier).removeOptimisticTransactionById(
        optimisticId,
      );
}

void replaceOptimisticTransaction({
  required WidgetRef ref,
  required String optimisticId,
  required ExpenseEntry savedEntry,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .replaceExpense(householdId, optimisticId, savedEntry);
    return;
  }

  ref
      .read(analyticsProvider.notifier)
      .replaceOptimisticTransaction(optimisticId, savedEntry);
}

void addOptimisticTransactionWithContainer({
  required ProviderContainer container,
  required ExpenseEntry entry,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    container
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(householdId, entry);
    return;
  }

  container.read(analyticsProvider.notifier).addOptimisticTransaction(entry);
}

void removeOptimisticTransactionWithContainer({
  required ProviderContainer container,
  required String optimisticId,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    container
        .read(householdOptimisticExpensesProvider.notifier)
        .removeExpense(householdId, optimisticId);
    return;
  }

  container.read(analyticsProvider.notifier).removeOptimisticTransactionById(
        optimisticId,
      );
}

void replaceOptimisticTransactionWithContainer({
  required ProviderContainer container,
  required String optimisticId,
  required ExpenseEntry savedEntry,
  required String? householdId,
}) {
  if (householdId != null && householdId.isNotEmpty) {
    container
        .read(householdOptimisticExpensesProvider.notifier)
        .replaceExpense(householdId, optimisticId, savedEntry);
    return;
  }

  container
      .read(analyticsProvider.notifier)
      .replaceOptimisticTransaction(optimisticId, savedEntry);
}
