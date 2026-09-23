import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';

Future<bool?> showTransactionDetailsSheet(
  BuildContext context, {
  required ExpenseEntry expense,
  required Map<String, RecurringTransaction> recurringTransactionsById,
  RecurringOccurrenceTimelineItem? recurringOccurrence,
  String? recurringIdForOccurrence,
  UserContact? contact,
  List<WalletEntity> transferWallets = const <WalletEntity>[],
  ValueChanged<WalletTransfer>? onTransferUpdated,
  ValueChanged<WalletTransfer>? onTransferDeleted,
}) async {
  final recurringId =
      extractRecurringTransactionIdFromProjectedExpenseId(expense.id);
  final projectedRecurringTransaction =
      recurringId == null ? null : recurringTransactionsById[recurringId];

  if (projectedRecurringTransaction != null) {
    return showAddRecurringSheet(
      context,
      type: projectedRecurringTransaction.type,
      existingTransaction: projectedRecurringTransaction,
    );
  }

  // Confirmed occurrences are materialized transactions, but they retain a
  // distinct edit contract. Prefer the occurrence ledger when it is available
  // so legacy feed rows that have not yet been hydrated with provenance still
  // open the occurrence editor rather than the normal transaction editor.
  if (recurringOccurrence != null) {
    final recurringTransaction = recurringTransactionsById[
        recurringIdForOccurrence?.trim() ??
            recurringOccurrence.actualTransaction?.parentRecurringId ??
            expense.parentRecurringId ??
            ''];
    if (recurringTransaction != null) {
      await showLazyRecurringOccurrenceSheet(
        context: context,
        recurringTransaction: recurringTransaction,
        occurrence: recurringOccurrence,
      );
      return false;
    }
  }

  final actualRecurringId = expense.parentRecurringId?.trim();
  final actualRecurringTransaction =
      actualRecurringId == null || actualRecurringId.isEmpty
          ? null
          : recurringTransactionsById[actualRecurringId];
  if (actualRecurringTransaction != null &&
      expense.scheduledOccurrenceDate != null) {
    await showConfirmRecurringOccurrenceSheet(
      context: context,
      recurringTransaction: actualRecurringTransaction,
      scheduledOccurrenceDate: expense.scheduledOccurrenceDate!,
      existingOccurrence:
          RecurringOccurrenceTimelineItem.fromLocalEntry(expense),
    );
    return false;
  }

  // A paginated or stale parent map can miss the recurring template even
  // though the materialized row still has its parent identity. Resolve the
  // parent before falling back to the ordinary transaction editor.
  if (actualRecurringId != null &&
      actualRecurringId.isNotEmpty &&
      expense.scheduledOccurrenceDate != null) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final recurringTransaction = await container.read(
        recurringSeriesDetailProvider(
          RecurringSeriesDetailQuery(
            userId: expense.userId ?? '',
            recurringId: actualRecurringId,
          ),
        ).future,
      );
      if (!context.mounted) return false;
      await showConfirmRecurringOccurrenceSheet(
        context: context,
        recurringTransaction: recurringTransaction,
        scheduledOccurrenceDate: expense.scheduledOccurrenceDate!,
        existingOccurrence:
            RecurringOccurrenceTimelineItem.fromLocalEntry(expense),
      );
      return false;
    } catch (_) {
      // Preserve ordinary transaction routing if the parent cannot be loaded.
    }
  }

  if (!context.mounted) return false;
  if (isWalletTransferExpenseEntry(expense)) {
    return showWalletTransferEditorForExpense(
      context,
      transferExpense: expense,
      wallets: transferWallets,
      onUpdated: onTransferUpdated,
      onDeleted: onTransferDeleted,
    );
  }

  if (!context.mounted) return false;
  return showUnifiedTransactionSheet(
    context,
    existingExpense: expense,
    contact: contact,
  );
}
