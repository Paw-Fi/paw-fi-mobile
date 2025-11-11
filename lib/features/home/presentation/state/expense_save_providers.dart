// State providers for expense save flow

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/auth/auth.dart';

// ============================================================================
// PENDING EXPENSE PROVIDER
// ============================================================================

/// Holds the parsed expense before user confirms and saves
final pendingExpenseProvider = StateProvider<ParsedExpense?>((ref) => null);

// ============================================================================
// SELECTED HOUSEHOLD FOR SHARING
// ============================================================================

/// Tracks which household to share expense with (null = personal only)
final selectedHouseholdForSharingProvider = StateProvider<String?>((ref) => null);

// ============================================================================
// EXPENSE SAVE NOTIFIER
// ============================================================================

/// Handles saving confirmed expense to database
class ExpenseSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ExpenseSaveNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Save expense to database
  /// If householdId provided, creates household split
  /// If customSplits provided, uses custom split configuration
  Future<void> saveExpense({
    required ParsedExpense expense,
    String? householdId,
    String? receiptImageUrl,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(authProvider);
      
      debugPrint('💾 Saving expense: ${expense.formattedAmount} ${expense.category}');
      if (householdId != null) {
        debugPrint('👥 Sharing with household: $householdId');
        if (customSplitType != null && customSplits != null) {
          debugPrint('📊 Custom split type: $customSplitType with ${customSplits.length} members');
        }
      }

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'userId': user.uid,
        'amount': expense.amount,
        'category': expense.category,
        'currency': expense.currency,
        // Date is used by BE for the calendar day; includes time here but DB stores DATE
        'date': expense.date.toIso8601String(),
        // Preserve client timezone by sending an explicit UTC timestamp for created_at
        'clientCreatedAt': expense.date.toUtc().toIso8601String(),
        'description': expense.description,
        'receiptImageUrl': receiptImageUrl,
        'householdId': householdId, // null = personal, id = shared
        // Explicitly set type for new expenses
        'type': 'expense',
      };

      // Add custom splits if provided
      if (householdId != null && customSplitType != null && customSplits != null) {
        final splitTypeStr = customSplitType.toString().split('.').last;
        
        debugPrint('🔍 [SAVE EXPENSE] Preparing custom splits:');
        debugPrint('  - Split type: $splitTypeStr');
        debugPrint('  - Number of members: ${customSplits.length}');
        
        requestBody['customSplits'] = {
          'splitType': splitTypeStr,
          'memberSplits': customSplits.map((split) {
            final memberData = <String, dynamic>{
              'userId': split.member.userId,
            };
            
            // Add the appropriate field based on split type
            switch (customSplitType) {
              case SplitType.amount:
                memberData['amount'] = split.amount;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: amount=${split.amount}');
                break;
              case SplitType.percentage:
                memberData['percentage'] = split.percentage;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: percentage=${split.percentage}');
                break;
              case SplitType.shares:
                memberData['shares'] = split.shares;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: shares=${split.shares}');
                break;
              case SplitType.equal:
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: equal (no data)');
                // No additional data needed for equal splits
                break;
            }
            
            return memberData;
          }).toList(),
        };
        
        debugPrint('📊 Custom splits payload: ${requestBody['customSplits']}');
      } else if (householdId != null) {
        debugPrint('⚠️ [SAVE EXPENSE] No custom splits - backend will default to equal split');
        debugPrint('  - customSplitType: $customSplitType');
        debugPrint('  - customSplits: ${customSplits?.length ?? 0} members');
      }

      // Call save-expense edge function
      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? 'Failed to save expense');
      }

      debugPrint('✅ Expense saved successfully');

      // Invalidate providers to trigger UI refresh
      await _invalidateProviders(user.uid, householdId);

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      debugPrint('❌ Error saving expense: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Invalidate appropriate providers based on sharing preference
  Future<void> _invalidateProviders(String userId, String? householdId) async {
    debugPrint('🔄 Invalidating providers...');

    // Always refresh personal analytics (expense is in user's expenses table)
    ref.read(analyticsProvider.notifier).refresh(userId);
    
    if (householdId != null) {
      // Shared expense: refresh household data
      debugPrint('🔄 Invalidating household providers for household: $householdId');

      // Invalidate household list (to update counts)
      ref.invalidate(userHouseholdsProvider(userId));

      // Invalidate family providers so all parameterized instances refresh
      ref.invalidate(householdSummaryProvider);
      ref.invalidate(householdExpensesProvider); // fix: refresh all limits (e.g., 500)
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);

      debugPrint('✅ Invalidated families: expenses, splits, budgets, summary');
    }
    
    // Small delay to ensure backend has propagated changes
    await Future.delayed(const Duration(milliseconds: 300));
    
    debugPrint('✅ Providers invalidated and ready for refresh');
  }

  /// Upload receipt image to storage (if needed)
  Future<String?> uploadReceiptImage(File imageFile, String userId) async {
    try {
      debugPrint('📤 Uploading receipt image...');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      //This Path is fixed, SO DO NOT CHANGE IT!
      final path = 'receipts/$userId/$fileName';

      final response = await supabase.storage
          .from('expense-receipts')
          .upload(path, imageFile);

      if (response.isEmpty) {
        throw Exception('Upload failed');
      }

      final publicUrl = supabase.storage
          .from('expense-receipts')
          .getPublicUrl(path);

      debugPrint('✅ Receipt uploaded: $publicUrl');
      return publicUrl;
    } catch (error) {
      debugPrint('❌ Receipt upload failed: $error');
      return null; // Continue without receipt image
    }
  }
}

final expenseSaveNotifierProvider =
    StateNotifierProvider<ExpenseSaveNotifier, AsyncValue<void>>((ref) {
  return ExpenseSaveNotifier(ref);
});
