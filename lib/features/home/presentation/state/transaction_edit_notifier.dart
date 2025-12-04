import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

/// Manages transaction editing with optimistic UI updates and automatic rollback on error
class TransactionEditNotifier extends StateNotifier<TransactionEditState> {
  final Ref ref;
  
  TransactionEditNotifier(this.ref) : super(const TransactionEditState());
  
  /// Update an expense field with optimistic UI update
  /// Returns true on success, false on failure
  Future<bool> updateExpense(
    String expenseId,
    Map<String, dynamic> updates, {
    Map<String, dynamic>? extraBody,
  }) async {
    if (state.isLoading) {
      debugPrint('⚠️ Update already in progress, ignoring');
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      editingExpenseId: expenseId,
      clearError: true,
    );
    
    try {
      // ═══════════════════════════════════════════════════════════════
      // STEP 1: Try optimistic UI update (if expense is in local cache)
      // ═══════════════════════════════════════════════════════════════
      // Optimistic updates make the UI feel instant by updating immediately
      // before waiting for the backend. However, NOT all expenses are in
      // the analytics provider cache:
      //   - Personal expenses: In analyticsProvider cache ✅
      //   - Household expenses: NOT in analyticsProvider cache ❌
      //
      // Solution: Make optimistic update optional - skip if not found.
      // ═══════════════════════════════════════════════════════════════
      final analyticsData = ref.read(analyticsProvider);
      final currentExpenses = analyticsData.allExpenses;

      final originalExpenseIndex = currentExpenses.indexWhere((e) => e.id == expenseId);

      // If expense found in local cache, apply optimistic update
      if (originalExpenseIndex != -1) {
        final originalExpense = currentExpenses[originalExpenseIndex];

        // 2. Create optimistic update (what the UI will show immediately)
        final optimisticExpense = _applyUpdates(originalExpense, updates);

        if (kDebugMode) {
          debugPrint('💾 Applying optimistic update for expense $expenseId');
          debugPrint('   Original: ${originalExpense.amount} ${originalExpense.currency}');
          debugPrint('   Updated:  ${optimisticExpense.amount} ${optimisticExpense.currency}');
        }

        // 3. Update UI immediately (optimistic)
        state = state.copyWith(optimisticUpdate: optimisticExpense);
        _applyOptimisticUpdateToProvider(optimisticExpense);
      } else {
        // Expense not in cache - likely a household expense
        // This is NOT an error, just skip optimistic update
        if (kDebugMode) {
          debugPrint('💾 Expense not in local cache (household expense), skipping optimistic update');
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // STEP 2: Call backend API (works for ALL expense types)
      // ═══════════════════════════════════════════════════════════════
      // The backend update works for both personal and household expenses.
      // We continue regardless of whether optimistic update was applied.
      // ═══════════════════════════════════════════════════════════════
      final user = ref.read(authProvider);
      if (kDebugMode) {
        debugPrint('🌐 Calling update-expense API...');
      }

      final requestBody = <String, dynamic>{
        'userId': user.uid,
        'expenseId': expenseId,
        'updates': updates,
      };

      if (extraBody != null && extraBody.isNotEmpty) {
        requestBody.addAll(extraBody);
      }

      final response = await supabase.functions.invoke(
        'update-expense',
        body: requestBody,
      );
      
      // Check response
      if (response.data == null) {
        throw Exception('No response from server');
      }
      
      final responseData = response.data as Map<String, dynamic>;
      
      if (responseData['success'] != true) {
        final errorMessage = responseData['error'] as String? ?? 'Update failed';
        final errorCode = responseData['code'] as String? ?? 'UNKNOWN_ERROR';
        throw Exception('$errorCode: $errorMessage');
      }
      
      if (kDebugMode) {
        debugPrint('✅ Backend update successful');
      }
      
      // ═══════════════════════════════════════════════════════════════
      // STEP 3: Reload data from backend to sync all providers
      // ═══════════════════════════════════════════════════════════════
      // After successful backend update, refresh all affected data:
      //   1. Personal expenses (analyticsProvider)
      //   2. Household expenses (householdExpensesProvider, etc.)
      //
      // This ensures UI shows the latest data from backend, including
      // any transformations or calculations done server-side.
      // ═══════════════════════════════════════════════════════════════
      await ref.read(analyticsProvider.notifier).loadData(user.uid);

      // ⚠️ CRITICAL: Always invalidate household providers after update
      // Even if the expense wasn't in analyticsProvider cache (household expense),
      // we must refresh household data to show the updated expense.
      //
      // This was a bug fix: Previously, household expenses failed to update
      // because they weren't in analyticsProvider and household providers
      // weren't being refreshed.
      debugPrint('🔄 Invalidating household providers after expense update');
      ref.invalidate(userHouseholdsProvider(user.uid));
      ref.invalidate(householdSummaryProvider);
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      debugPrint('✅ Invalidated household providers');

      state = state.copyWith(
        isLoading: false,
        clearOptimisticUpdate: true,
        clearError: true,
      );

      return true;
      
    } catch (e) {
      // 6. Error: Rollback optimistic update
      debugPrint('❌ Update failed: $e');
      
      try {
        final analyticsData = ref.read(analyticsProvider);
        final currentExpenses = analyticsData.allExpenses;
        final originalExpenseIndex = currentExpenses.indexWhere((exp) => exp.id == expenseId);
        
        if (originalExpenseIndex != -1) {
          // Find the expense that was there before our optimistic update
          // We need to reload from backend to get the original state
          final user = ref.read(authProvider);
          await ref.read(analyticsProvider.notifier).loadData(user.uid);
          
          if (kDebugMode) {
            debugPrint('🔄 Rolled back optimistic update');
          }
        }
      } catch (rollbackError) {
        debugPrint('⚠️ Failed to rollback: $rollbackError');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: _formatErrorMessage(e.toString()),
        clearOptimisticUpdate: true,
      );
      
      return false;
    }
  }
  
  /// Apply field updates to an expense, creating a new instance
  ExpenseEntry _applyUpdates(
    ExpenseEntry expense,
    Map<String, dynamic> updates,
  ) {
    return expense.copyWith(
      amountCents: updates['amount_cents'] as int? ?? expense.amountCents,
      category: updates.containsKey('category') 
          ? (updates['category'] as String?) 
          : expense.category,
      rawText: updates.containsKey('raw_text')
          ? (updates['raw_text'] as String?)
          : expense.rawText,
      date: updates['date'] != null 
          ? DateTime.parse(updates['date'] as String) 
          : expense.date,
      currency: updates['currency'] as String? ?? expense.currency,
    );
  }
  
  /// Apply optimistic update to the analytics provider state
  void _applyOptimisticUpdateToProvider(ExpenseEntry updatedExpense) {
    final analytics = ref.read(analyticsProvider);
    
    // Update both expenses and allExpenses lists
    final updatedExpenses = analytics.expenses.map((e) {
      return e.id == updatedExpense.id ? updatedExpense : e;
    }).toList();
    
    final updatedAllExpenses = analytics.allExpenses.map((e) {
      return e.id == updatedExpense.id ? updatedExpense : e;
    }).toList();
    
    // Update provider state
    ref.read(analyticsProvider.notifier).state = analytics.copyWith(
      expenses: updatedExpenses,
      allExpenses: updatedAllExpenses,
    );
  }
  
  /// Format error message to be user-friendly
  String _formatErrorMessage(String error) {
    if (error.contains('VALIDATION_ERROR')) {
      return 'Invalid input. Please check your values.';
    } else if (error.contains('NOT_FOUND')) {
      return 'Transaction not found.';
    } else if (error.contains('UNAUTHORIZED')) {
      return 'You don\'t have permission to edit this transaction.';
    } else if (error.contains('Network') || error.contains('Failed host lookup')) {
      return 'Network error. Please check your connection and try again.';
    } else {
      return 'Failed to update. Please try again.';
    }
  }
  
  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for transaction editing state
final transactionEditProvider = StateNotifierProvider<TransactionEditNotifier, TransactionEditState>(
  (ref) => TransactionEditNotifier(ref),
);
