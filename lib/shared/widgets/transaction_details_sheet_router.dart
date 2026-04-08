import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_details_sheet.dart';

Future<bool?> showTransactionDetailsSheet(
  BuildContext context, {
  required ExpenseEntry expense,
  required Map<String, RecurringTransaction> recurringTransactionsById,
  UserContact? contact,
  List<WalletEntity> transferWallets = const <WalletEntity>[],
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

  if (isWalletTransferExpenseEntry(expense)) {
    await showWalletTransferDetailsSheet(
      context,
      transferExpense: expense,
      wallets: transferWallets,
    );
    return null;
  }

  return showUnifiedTransactionSheet(
    context,
    existingExpense: expense,
    contact: contact,
  );
}
