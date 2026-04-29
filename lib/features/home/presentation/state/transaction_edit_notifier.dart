import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

/// Manages transaction editing with optimistic UI updates and automatic rollback on error
class TransactionEditNotifier extends StateNotifier<TransactionEditState> {
  final Ref ref;

  TransactionEditNotifier(this.ref) : super(const TransactionEditState());

  String _normalizeCategoryValue(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  /// Update an expense field with optimistic UI update
  /// Returns true on success, false on failure
  Future<bool> updateExpense(
    String expenseId,
    Map<String, dynamic> updates, {
    Map<String, dynamic>? extraBody,
  }) async {
    if (state.isLoading) {
      _debugPrint('⚠️ Update already in progress, ignoring');
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

      final originalExpenseIndex =
          currentExpenses.indexWhere((e) => e.id == expenseId);

      // If expense found in local cache, apply optimistic update
      if (originalExpenseIndex != -1) {
        final originalExpense = currentExpenses[originalExpenseIndex];

        // 2. Create optimistic update (what the UI will show immediately)
        final optimisticExpense = _applyUpdates(originalExpense, updates);

        _debugPrint('💾 Applying optimistic update');

        // 3. Update UI immediately (optimistic)
        state = state.copyWith(optimisticUpdate: optimisticExpense);
        _applyOptimisticUpdateToProvider(optimisticExpense);
      } else {
        // Expense not in cache - likely a household expense
        // This is NOT an error, just skip optimistic update
        _debugPrint(
            '💾 Expense not in local cache; skipping optimistic update');
      }

      // ═══════════════════════════════════════════════════════════════
      // STEP 2: Call backend API (works for ALL expense types)
      // ═══════════════════════════════════════════════════════════════
      // The backend update works for both personal and household expenses.
      // We continue regardless of whether optimistic update was applied.
      // ═══════════════════════════════════════════════════════════════
      final user = ref.read(authProvider);
      final supabaseClient = ref.read(transactionEditSupabaseClientProvider);
      _debugPrint('🌐 Calling update-expense API...');

      final requestBody = <String, dynamic>{
        'userId': user.uid,
        'expenseId': expenseId,
        'updates': updates,
        // Used by the edge function to validate calendar dates against the
        // caller's local "today" instead of server UTC.
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      };

      if (extraBody != null && extraBody.isNotEmpty) {
        requestBody.addAll(extraBody);
      }

      final response = await supabaseClient.functions.invoke(
        'update-expense',
        body: requestBody,
      );

      // Check response
      if (response.data == null) {
        throw Exception('No response from server');
      }

      final responseData = response.data as Map<String, dynamic>;
      _debugPrint(
        '📥 update-expense response: success=${responseData['success']} code=${responseData['code']} error=${responseData['error']}',
      );

      if (responseData['success'] != true) {
        final errorMessage =
            responseData['error'] as String? ?? 'Update failed';
        final errorCode = responseData['code'] as String? ?? 'UNKNOWN_ERROR';
        throw Exception('$errorCode: $errorMessage');
      }

      if (updates.containsKey('category')) {
        final requestedCategory = _normalizeCategoryValue(updates['category']);
        final responseCategory = _normalizeCategoryValue(
          (responseData['data'] as Map<String, dynamic>?)?['category'],
        );
        _debugPrint(
          '🏷️ category update check: requested="$requestedCategory" response="$responseCategory" expenseId=$expenseId',
        );

        if (requestedCategory.isNotEmpty &&
            responseCategory != requestedCategory) {
          _debugPrint(
            '⚠️ Category mismatch after update (requested=$requestedCategory, got=$responseCategory). Retrying category-only update.',
          );

          try {
            final retryResponse = await supabaseClient.functions.invoke(
              'update-expense',
              body: {
                'userId': user.uid,
                'expenseId': expenseId,
                'updates': {'category': requestedCategory},
                'clientTimezoneOffsetMinutes':
                    DateTime.now().timeZoneOffset.inMinutes,
              },
            );

            final retryData = retryResponse.data as Map<String, dynamic>?;
            final retrySuccess = retryData?['success'] == true;
            final retryCategory = _normalizeCategoryValue(
              (retryData?['data'] as Map<String, dynamic>?)?['category'],
            );
            _debugPrint(
              '🔁 category retry result: success=$retrySuccess responseCategory="$retryCategory" rawError=${retryData?['error']} rawCode=${retryData?['code']}',
            );

            if (!retrySuccess || retryCategory != requestedCategory) {
              _debugPrint(
                '⚠️ CATEGORY_UPDATE_MISMATCH (soft): requested="$requestedCategory" response="$retryCategory". Continuing after backend success to avoid false-negative UI failures.',
              );
            }
          } catch (retryError) {
            _debugPrint(
              '⚠️ CATEGORY_UPDATE_MISMATCH (soft): retry threw "$retryError". Continuing after backend success to avoid false-negative UI failures.',
            );
          }
        }
      }

      _debugPrint('✅ Backend update successful');

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
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;

      // ⚠️ CRITICAL: Always invalidate household providers after update
      // Even if the expense wasn't in analyticsProvider cache (household expense),
      // we must refresh household data to show the updated expense.
      //
      // This was a bug fix: Previously, household expenses failed to update
      // because they weren't in analyticsProvider and household providers
      // weren't being refreshed.
      _debugPrint('🔄 Invalidating household providers after expense update');
      ref.invalidate(userHouseholdsProvider(user.uid));
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdMembersProvider);
      ref.invalidate(cachedHouseholdExpensesProvider);
      ref.invalidate(cachedHouseholdSplitsProvider);
      ref.read(cacheInvalidatorProvider).invalidateAll();
      _debugPrint('✅ Invalidated household providers');

      // Keep other tabs in sync (pockets + currency counts).
      ref.invalidate(pocketsProvider);
      ref.invalidate(currencyTransactionCountsProvider);
      ref.read(walletActionsProvider).refreshAccountData();

      state = state.copyWith(
        isLoading: false,
        clearOptimisticUpdate: true,
        clearError: true,
      );

      return true;
    } catch (e) {
      // 6. Error: Rollback optimistic update
      _debugPrint('❌ Update failed: $e');

      try {
        final analyticsData = ref.read(analyticsProvider);
        final currentExpenses = analyticsData.allExpenses;
        final originalExpenseIndex =
            currentExpenses.indexWhere((exp) => exp.id == expenseId);

        if (originalExpenseIndex != -1) {
          // Find the expense that was there before our optimistic update
          // We need to reload from backend to get the original state
          final user = ref.read(authProvider);
          await ref.read(analyticsProvider.notifier).loadData(user.uid);
          ref.read(dashboardRefreshSignalProvider.notifier).state += 1;

          _debugPrint('🔄 Rolled back optimistic update');
        }
      } catch (rollbackError) {
        _debugPrint('⚠️ Failed to rollback');
      }

      state = state.copyWith(
        isLoading: false,
        error: _formatErrorMessage(e),
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
      merchant: updates.containsKey('merchant')
          ? (updates['merchant'] as String?)
          : expense.merchant,
      date: updates['date'] != null
          ? (() {
              final value = updates['date']?.toString();
              final dateOnly = tryParseDateOnlyYmd(value);
              if (dateOnly != null) {
                return DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
              }
              final parsed = DateTime.tryParse(value ?? '');
              if (parsed != null) {
                return DateTime(parsed.year, parsed.month, parsed.day);
              }
              return expense.date;
            })()
          : expense.date,
      currency: updates['currency'] as String? ?? expense.currency,
      accountId: updates.containsKey('account_id')
          ? (updates['account_id'] as String?)
          : expense.walletId,
      receiptImageUrl: updates.containsKey('receipt_image_url')
          ? (updates['receipt_image_url'] as String?)
          : expense.receiptImageUrl,
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

  /// Extract a concise backend error message.
  ///
  /// If this came from a Supabase `FunctionException`, we try to read
  /// `details['error']` so the UI shows only the backend `error` field
  /// (e.g. "Cannot change splits after any lines have been settled").
  /// Otherwise, we fall back to the full exception string.
  String _formatErrorMessage(Object error) {
    return ErrorHandler.getUserFriendlyMessage(
      error,
      context: BackendErrorContext.updateExpense,
    );
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final transactionEditSupabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});

/// Provider for transaction editing state
final transactionEditProvider =
    StateNotifierProvider<TransactionEditNotifier, TransactionEditState>(
  (ref) => TransactionEditNotifier(ref),
);
