// Backward compatibility wrapper for transaction_detail_sheet
// This file now delegates to unified_transaction_sheet.dart
// Kept for backward compatibility with existing code

import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';

/// Backward compatibility: Shows transaction detail sheet
/// Now delegates to unified_transaction_sheet for consistency
@Deprecated('Use showUnifiedTransactionSheet instead')
void showTransactionDetailSheet(
  BuildContext context,
  ExpenseEntry expense, {
  UserContact? contact,
  String? localImagePath,
}) {
  // Delegate to unified sheet
  showUnifiedTransactionSheet(
    context,
    existingExpense: expense,
    contact: contact,
    localImagePath: localImagePath,
  );
}
