import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
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
    ExpenseEntry? originalExpense,
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

    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: expenseId,
      operation: 'update_transaction',
    );
    final user = ref.read(authProvider);
    ExpenseEntry? optimisticExpense;
    ExpenseEntry? originalForRollback;
    MonekoDatabase? localDatabase;

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
      final cachedOriginalExpense = originalExpenseIndex == -1
          ? originalExpense
          : currentExpenses[originalExpenseIndex];

      // If expense found in local cache, apply optimistic update
      if (cachedOriginalExpense != null) {
        // 2. Create optimistic update (what the UI will show immediately)
        optimisticExpense = _applyUpdates(cachedOriginalExpense, updates);
        originalForRollback = cachedOriginalExpense;

        _debugPrint('💾 Applying optimistic update');

        // 3. Update UI immediately (optimistic)
        state = state.copyWith(optimisticUpdate: optimisticExpense);
        _applyOptimisticUpdateToProvider(
          optimisticExpense,
          originalExpense: cachedOriginalExpense,
        );
        localDatabase = await _writeOptimisticUpdateToLocalStore(
          originalEntry: cachedOriginalExpense,
          updatedEntry: optimisticExpense,
          mutationMetadata: mutationMetadata,
          payload: {
            ...mutationMetadata.toRequestJson(),
            'userId': user.uid,
            'expenseId': expenseId,
            'updates': updates,
            if (extraBody != null && extraBody.isNotEmpty)
              'extraBody': extraBody,
          },
        );
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
      final supabaseClient = ref.read(transactionEditSupabaseClientProvider);
      _debugPrint('🌐 Calling update-expense API...');

      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
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

      final responseData = _responseMap(response.data);
      if (responseData == null) {
        throw Exception('Invalid response from server');
      }
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

            final retryData = _responseMap(retryResponse.data);
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

      final responseExpense = _expenseFromResponseData(
        responseData['data'],
        fallback: optimisticExpense,
      );
      final affectedHouseholdIds = <String>{
        if (originalExpense?.householdId?.trim().isNotEmpty == true)
          originalExpense!.householdId!.trim(),
        if (originalForRollback?.householdId?.trim().isNotEmpty == true)
          originalForRollback!.householdId!.trim(),
        if (optimisticExpense?.householdId?.trim().isNotEmpty == true)
          optimisticExpense!.householdId!.trim(),
        if (responseExpense?.householdId?.trim().isNotEmpty == true)
          responseExpense!.householdId!.trim(),
      };
      await Future.wait(
        affectedHouseholdIds.map(clearHouseholdPersistentCacheForHousehold),
      );
      if (localDatabase != null && responseExpense != null) {
        await localDatabase.markOptimisticTransactionUpdateSynced(
          entry: responseExpense,
          clientMutationId: mutationMetadata.clientMutationId,
        );
      } else if (localDatabase != null) {
        await localDatabase.markMutationSynced(
          mutationMetadata.clientMutationId,
        );
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

      // Keep other tabs in sync. Pockets reconciles from refresh signals
      // without disposing its visible provider.
      ref.invalidate(currencyTransactionCountsProvider);
      ref
          .read(dashboardCurrencySummariesRefreshSignalProvider.notifier)
          .state += 1;
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

      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
        ref.read(walletActionsProvider).refreshAccountData();
        state = state.copyWith(
          isLoading: false,
          clearOptimisticUpdate: true,
          clearError: true,
        );
        return true;
      }

      try {
        if (localDatabase != null && originalForRollback != null) {
          await localDatabase.rollbackOptimisticTransactionUpdate(
            originalEntry: originalForRollback,
            clientMutationId: mutationMetadata.clientMutationId,
            error: e,
          );
        }

        final originalHouseholdId =
            (originalForRollback ?? originalExpense)?.householdId?.trim();
        if (originalHouseholdId != null && originalHouseholdId.isNotEmpty) {
          ref
              .read(householdOptimisticExpensesProvider.notifier)
              .removeExpense(originalHouseholdId, expenseId);
        }

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

  Future<bool> deleteExpensesOptimistically(
    List<ExpenseEntry> expenses,
  ) async {
    final targets = expenses
        .where((entry) => entry.id.trim().isNotEmpty)
        .toList(growable: false);
    if (targets.isEmpty) return false;

    final user = ref.read(authProvider);
    final ids = targets.map((entry) => entry.id).toList(growable: false);
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: ids.join('_'),
      operation: 'delete_transaction',
    );
    MonekoDatabase? localDatabase;

    try {
      _applyOptimisticDeleteToProviders(targets);
      localDatabase = await _writeOptimisticDeleteToLocalStore(
        entries: targets,
        mutationMetadata: mutationMetadata,
        payload: {
          ...mutationMetadata.toRequestJson(),
          'userId': user.uid,
          'expenseIds': ids.join(','),
        },
      );

      final response = await ref
          .read(transactionEditSupabaseClientProvider)
          .functions
          .invoke('delete-expense', body: {
        ...mutationMetadata.toRequestJson(),
        'userId': user.uid,
        'expenseIds': ids.join(','),
      });

      final payload = _responseMap(response.data);
      if (payload == null || payload['success'] != true) {
        final message = (payload?['error'] as String?) ?? 'Delete failed';
        final failedCount = payload?['failedCount'] as int?;
        if (failedCount != null && failedCount > 0) {
          throw Exception(message);
        }
        throw Exception(message);
      }

      if (localDatabase != null) {
        await localDatabase.markOptimisticTransactionDeleteSynced(
          clientMutationId: mutationMetadata.clientMutationId,
        );
      }

      await _refreshAfterTransactionMutation(user.uid);
      _clearOptimisticDeletedIds(targets);
      state = state.copyWith(clearError: true);
      return true;
    } catch (e) {
      _debugPrint('❌ Delete failed: $e');

      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        await _refreshAfterTransactionMutation(user.uid);
        _clearOptimisticDeletedIds(targets);
        state = state.copyWith(clearError: true);
        return true;
      }

      if (localDatabase != null) {
        await localDatabase.rollbackOptimisticTransactionDelete(
          entries: targets,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }

      _rollbackOptimisticDeleteToProviders(targets);
      state = state.copyWith(
        error: ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.deleteExpense,
        ),
      );
      return false;
    }
  }

  Future<MonekoDatabase?> _writeOptimisticUpdateToLocalStore({
    required ExpenseEntry originalEntry,
    required ExpenseEntry updatedEntry,
    required TransactionMutationMetadata mutationMetadata,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransactionUpdate(
        originalEntry: originalEntry,
        updatedEntry: updatedEntry,
        clientMutationId: mutationMetadata.clientMutationId,
        payload: payload,
      );
      return database;
    } catch (error) {
      _debugPrint('⚠️ Local optimistic update unavailable: $error');
      return null;
    }
  }

  Future<MonekoDatabase?> _writeOptimisticDeleteToLocalStore({
    required List<ExpenseEntry> entries,
    required TransactionMutationMetadata mutationMetadata,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransactionDelete(
        entries: entries,
        clientMutationId: mutationMetadata.clientMutationId,
        payload: payload,
      );
      return database;
    } catch (error) {
      _debugPrint('⚠️ Local optimistic delete unavailable: $error');
      return null;
    }
  }

  ExpenseEntry? _expenseFromResponseData(
    Object? data, {
    required ExpenseEntry? fallback,
  }) {
    if (data is Map<String, dynamic>) {
      return ExpenseEntry.fromJson(data);
    }
    if (data is Map) {
      return ExpenseEntry.fromJson(Map<String, dynamic>.from(data));
    }
    return fallback;
  }

  Map<String, dynamic>? _responseMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> _refreshAfterTransactionMutation(String userId) async {
    await ref.read(analyticsProvider.notifier).loadData(userId);
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;

    ref.invalidate(userHouseholdsProvider(userId));
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(householdSplitsProvider);
    ref.invalidate(householdBudgetsProvider);
    ref.invalidate(householdMembersProvider);
    ref.invalidate(cachedHouseholdExpensesProvider);
    ref.invalidate(cachedHouseholdSplitsProvider);
    ref.read(cacheInvalidatorProvider).invalidateAll();

    ref.invalidate(currencyTransactionCountsProvider);
    ref.read(dashboardCurrencySummariesRefreshSignalProvider.notifier).state +=
        1;
    ref.read(walletActionsProvider).refreshAccountData();
  }

  void _applyOptimisticDeleteToProviders(List<ExpenseEntry> entries) {
    final analytics = ref.read(analyticsProvider);
    final ids = entries.map((entry) => entry.id).toSet();
    ref.read(analyticsProvider.notifier).state = analytics.copyWith(
      expenses: analytics.expenses
          .where((entry) => !ids.contains(entry.id))
          .toList(growable: false),
      allExpenses: analytics.allExpenses
          .where((entry) => !ids.contains(entry.id))
          .toList(growable: false),
    );

    final byHousehold = _entriesByHousehold(entries);
    final deletedNotifier =
        ref.read(householdOptimisticDeletedExpenseIdsProvider.notifier);
    for (final entry in byHousehold.entries) {
      deletedNotifier.markDeleted(
        entry.key,
        entry.value.map((expense) => expense.id),
      );
    }
  }

  void _rollbackOptimisticDeleteToProviders(List<ExpenseEntry> entries) {
    for (final entry in entries) {
      final householdId = entry.householdId?.trim();
      if (householdId != null && householdId.isNotEmpty) {
        ref
            .read(householdOptimisticExpensesProvider.notifier)
            .replaceExpense(householdId, entry.id, entry);
      } else {
        ref.read(analyticsProvider.notifier).addOptimisticTransaction(entry);
      }
    }

    _clearOptimisticDeletedIds(entries);
  }

  void _clearOptimisticDeletedIds(List<ExpenseEntry> entries) {
    final byHousehold = _entriesByHousehold(entries);
    final deletedNotifier =
        ref.read(householdOptimisticDeletedExpenseIdsProvider.notifier);
    for (final entry in byHousehold.entries) {
      deletedNotifier.restore(
        entry.key,
        entry.value.map((expense) => expense.id),
      );
    }
  }

  Map<String, List<ExpenseEntry>> _entriesByHousehold(
    List<ExpenseEntry> entries,
  ) {
    final grouped = <String, List<ExpenseEntry>>{};
    for (final entry in entries) {
      final householdId = entry.householdId?.trim();
      if (householdId == null || householdId.isEmpty) continue;
      grouped.putIfAbsent(householdId, () => <ExpenseEntry>[]).add(entry);
    }
    return grouped;
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
      householdId: updates['household_id'] is String
          ? updates['household_id'] as String
          : expense.householdId,
      accountId: updates.containsKey('account_id')
          ? (updates['account_id'] as String?)
          : expense.walletId,
      receiptImageUrl: updates.containsKey('receipt_image_url')
          ? (updates['receipt_image_url'] as String?)
          : expense.receiptImageUrl,
    );
  }

  /// Apply optimistic update to the analytics provider state
  void _applyOptimisticUpdateToProvider(
    ExpenseEntry updatedExpense, {
    required ExpenseEntry originalExpense,
  }) {
    final originalHouseholdId = originalExpense.householdId?.trim();
    final updatedHouseholdId = updatedExpense.householdId?.trim();

    if (originalHouseholdId != null && originalHouseholdId.isNotEmpty) {
      final householdNotifier =
          ref.read(householdOptimisticExpensesProvider.notifier);
      if (updatedHouseholdId != null &&
          updatedHouseholdId.isNotEmpty &&
          updatedHouseholdId != originalHouseholdId) {
        householdNotifier.removeExpense(originalHouseholdId, updatedExpense.id);
        householdNotifier.replaceExpense(
          updatedHouseholdId,
          updatedExpense.id,
          updatedExpense,
        );
      } else {
        householdNotifier.replaceExpense(
          originalHouseholdId,
          updatedExpense.id,
          updatedExpense,
        );
      }
    }

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

bool _shouldKeepQueuedLocalMutation(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('network') ||
      message.contains('socket') ||
      message.contains('failed host lookup') ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('status: 502') ||
      message.contains('status: 503') ||
      message.contains('status: 504') ||
      message.contains('service is temporarily unavailable') ||
      message.contains('supabase_edge_runtime_error');
}

final transactionEditSupabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});

/// Provider for transaction editing state
final transactionEditProvider =
    StateNotifierProvider<TransactionEditNotifier, TransactionEditState>(
  (ref) => TransactionEditNotifier(ref),
);
