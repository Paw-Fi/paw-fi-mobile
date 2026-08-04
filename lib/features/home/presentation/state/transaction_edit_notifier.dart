import 'dart:async';

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

final RegExp _serverExpenseIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

const Duration _transactionUpdateRequestTimeout = Duration(seconds: 30);
const Duration _localCommitReconciliationTimeout = Duration(seconds: 5);

final activeTransactionCreateSyncIdsProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
);

/// Manages transaction editing with optimistic UI updates and automatic rollback on error
class TransactionEditNotifier extends StateNotifier<TransactionEditState> {
  final Ref ref;

  TransactionEditNotifier(this.ref) : super(const TransactionEditState());

  String _normalizeCategoryValue(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _analyticsClassForCategory(ExpenseEntry expense, dynamic category) {
    final normalizedCategory = _normalizeCategoryValue(category);
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    if (normalizedCategory == 'transfers') {
      return isIncome ? 'transfer_in' : 'transfer_out';
    }
    if (normalizedCategory == 'debt payments') return 'debt_payment';
    if (normalizedCategory == 'bank fees') return 'bank_fee';
    return isIncome ? 'income' : 'consumer_spend';
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
    var backendCommitted = false;

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
        ref.read(transactionsFeedEditedEntryProvider.notifier).state =
            optimisticExpense;
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
        if (localDatabase != null) {
          await _refreshAfterLocalTransactionMutation(user.uid);
        }
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

      final response = await supabaseClient.functions
          .invoke(
            'update-expense',
            body: requestBody,
          )
          .timeout(_transactionUpdateRequestTimeout);

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
      backendCommitted = true;

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
            ).timeout(_transactionUpdateRequestTimeout);

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
      final responsePreservingUpdates = <String, dynamic>{
        if (updates.containsKey('merchant')) 'merchant': updates['merchant'],
        if (updates.containsKey('raw_text')) 'raw_text': updates['raw_text'],
        if (updates.containsKey('receipt_image_url'))
          'receipt_image_url': updates['receipt_image_url'],
      };
      final confirmedExpense = responseExpense == null
          ? optimisticExpense
          : responsePreservingUpdates.isEmpty
              ? responseExpense
              : _applyUpdates(responseExpense, responsePreservingUpdates);
      final affectedHouseholdIds = <String>{
        if (originalExpense?.householdId?.trim().isNotEmpty == true)
          originalExpense!.householdId!.trim(),
        if (originalForRollback?.householdId?.trim().isNotEmpty == true)
          originalForRollback!.householdId!.trim(),
        if (optimisticExpense?.householdId?.trim().isNotEmpty == true)
          optimisticExpense!.householdId!.trim(),
        if (confirmedExpense?.householdId?.trim().isNotEmpty == true)
          confirmedExpense!.householdId!.trim(),
      };

      // The backend response is authoritative. Apply it before doing any broad
      // refresh so a slow analytics reload cannot keep the save dialog open or
      // temporarily replace the edited row with stale data.
      if (confirmedExpense != null) {
        final rollbackSource =
            originalForRollback ?? originalExpense ?? confirmedExpense;
        ref.read(transactionsFeedEditedEntryProvider.notifier).state =
            confirmedExpense;
        _applyOptimisticUpdateToProvider(
          confirmedExpense,
          originalExpense: rollbackSource,
        );
      }

      // Reconcile the durable outbox promptly, but never leave the user behind
      // a blocking dialog indefinitely if device storage is unhealthy. The
      // mutation is idempotent and remains safely retryable if reconciliation
      // cannot finish within this small bound.
      if (localDatabase != null) {
        try {
          final reconciliation = confirmedExpense != null
              ? localDatabase.markOptimisticTransactionUpdateSynced(
                  entry: confirmedExpense,
                  clientMutationId: mutationMetadata.clientMutationId,
                )
              : localDatabase.markMutationSynced(
                  mutationMetadata.clientMutationId,
                );
          await reconciliation.timeout(_localCommitReconciliationTimeout);
        } catch (error) {
          _debugPrint(
            '⚠️ Backend update committed but local reconciliation was deferred: $error',
          );
        }
      }

      // Notify derived local-first consumers immediately. The edited-entry
      // overlay already refreshes the transaction feed; the dashboard signal
      // propagates the same committed row to pockets and summary surfaces.
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;

      state = state.copyWith(
        isLoading: false,
        clearOptimisticUpdate: true,
        clearError: true,
      );

      // A single-row edit must not wait for a full-history analytics download,
      // SQLite recache, or household cache maintenance. The confirmed row above
      // is already visible and durable; broad reconciliation is best-effort
      // background maintenance.
      unawaited(_refreshAfterCommittedUpdate(
        userId: user.uid,
        affectedHouseholdIds: affectedHouseholdIds,
      ));

      return true;
    } catch (e) {
      // 6. Error: Rollback optimistic update
      if (backendCommitted) {
        _debugPrint(
          '⚠️ Backend update succeeded; keeping the confirmed optimistic state despite refresh failure',
        );
        try {
          if (optimisticExpense != null) {
            ref.read(transactionsFeedEditedEntryProvider.notifier).state =
                optimisticExpense;
          }
          ref.read(walletActionsProvider).refreshAccountData();
        } catch (refreshError) {
          _debugPrint('⚠️ Post-update invalidation failed: $refreshError');
        }
        state = state.copyWith(
          isLoading: false,
          clearOptimisticUpdate: true,
          clearError: true,
        );
        return true;
      }

      _debugPrint('❌ Update failed: $e');

      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
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
          ref.read(transactionsFeedEditedEntryProvider.notifier).state =
              originalForRollback;
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

      try {
        final rollbackEntry = originalForRollback ?? originalExpense;
        if (rollbackEntry != null) {
          ref.read(transactionsFeedEditedEntryProvider.notifier).state =
              rollbackEntry;
          await _refreshAfterLocalTransactionMutation(user.uid);
        }
      } catch (refreshError) {
        _debugPrint('⚠️ Failed to refresh rolled-back update: $refreshError');
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
    final serverTargets = targets
        .where((entry) => _isServerBackedExpenseId(entry.id))
        .toList(growable: false);
    final localTargets = targets
        .where((entry) => !_isServerBackedExpenseId(entry.id))
        .toList(growable: false);

    if (localTargets.isNotEmpty) {
      final activeCreateSyncIds =
          ref.read(activeTransactionCreateSyncIdsProvider);
      final hasActiveCreateSync = localTargets.any(
        (entry) => activeCreateSyncIds.contains(entry.id.trim()),
      );
      if (hasActiveCreateSync) {
        state = state.copyWith(
          error:
              'This transaction is still syncing. Please try again in a moment.',
        );
        return false;
      }

      final cancelledLocalCreates =
          await _cancelQueuedLocalCreateTransactions(localTargets);
      if (!cancelledLocalCreates) {
        state = state.copyWith(
          error:
              'This transaction is still syncing. Please try again in a moment.',
        );
        return false;
      }

      _removeLocalOptimisticTransactionsFromProviders(localTargets);
      await _refreshAfterLocalTransactionMutation(user.uid);
      state = state.copyWith(clearError: true);

      if (serverTargets.isEmpty) {
        return true;
      }
    }

    final ids = serverTargets.map((entry) => entry.id).toList(growable: false);
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: ids.join('_'),
      operation: 'delete_transaction',
    );
    MonekoDatabase? localDatabase;
    var backendCommitted = false;

    try {
      _applyOptimisticDeleteToProviders(serverTargets);
      localDatabase = await _writeOptimisticDeleteToLocalStore(
        entries: serverTargets,
        mutationMetadata: mutationMetadata,
        payload: {
          ...mutationMetadata.toRequestJson(),
          'userId': user.uid,
          'expenseIds': ids.join(','),
        },
      );
      await _refreshAfterLocalTransactionMutation(user.uid);

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
      backendCommitted = true;
      final affectedHouseholdIds = serverTargets
          .map((entry) => entry.householdId?.trim())
          .whereType<String>()
          .where((householdId) => householdId.isNotEmpty)
          .toSet();
      await Future.wait(
        affectedHouseholdIds.map((householdId) async {
          try {
            await clearHouseholdTransactionPersistentCacheForHousehold(
              householdId,
            );
          } catch (error) {
            _debugPrint('⚠️ Failed to clear household cache: $error');
          }
        }),
      );

      if (localDatabase != null) {
        await localDatabase.markOptimisticTransactionDeleteSynced(
          clientMutationId: mutationMetadata.clientMutationId,
        );
      }

      await _refreshAfterTransactionMutation(user.uid);
      _clearOptimisticDeletedIds(serverTargets);
      state = state.copyWith(clearError: true);
      return true;
    } catch (e) {
      if (backendCommitted) {
        _debugPrint(
          '⚠️ Backend delete succeeded; preserving the optimistic deletion despite refresh failure',
        );
        // The remote delete is authoritative at this point. Leaving the
        // in-memory tombstone behind would make settlement preflight treat a
        // completed delete as permanently pending for this process lifetime.
        _clearOptimisticDeletedIds(serverTargets);
        try {
          await _refreshAfterLocalTransactionMutation(user.uid);
        } catch (refreshError) {
          _debugPrint('⚠️ Post-delete invalidation failed: $refreshError');
        }
        state = state.copyWith(clearError: true);
        return true;
      }

      _debugPrint('❌ Delete failed: $e');

      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        await _refreshAfterLocalTransactionMutation(user.uid);
        state = state.copyWith(clearError: true);
        return true;
      }

      if (localDatabase != null) {
        await localDatabase.rollbackOptimisticTransactionDelete(
          entries: serverTargets,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }

      _rollbackOptimisticDeleteToProviders(serverTargets);
      await _refreshAfterLocalTransactionMutation(user.uid);
      state = state.copyWith(
        error: ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.deleteExpense,
        ),
      );
      return false;
    }
  }

  bool _isServerBackedExpenseId(String id) {
    return _serverExpenseIdPattern.hasMatch(id.trim());
  }

  Future<bool> _cancelQueuedLocalCreateTransactions(
    List<ExpenseEntry> entries,
  ) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      return database.cancelQueuedOptimisticTransactions(
        transactionIds: entries.map((entry) => entry.id),
        error: 'Deleted before sync completed',
      );
    } catch (error) {
      _debugPrint(
          '⚠️ Local optimistic delete cancellation unavailable: $error');
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
        actingUserId: ref.read(authProvider).uid,
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
    ExpenseEntry fallbackWith(Map<String, dynamic> updates) {
      return fallback == null
          ? ExpenseEntry.fromJson(updates)
          : _applyUpdates(fallback, updates);
    }

    if (data is Map<String, dynamic>) {
      if (!data.containsKey('id') || data['id'] == null) {
        return fallbackWith(data);
      }
      return ExpenseEntry.fromJson(data);
    }
    if (data is Map) {
      final updates = Map<String, dynamic>.from(data);
      if (!updates.containsKey('id') || updates['id'] == null) {
        return fallbackWith(updates);
      }
      return ExpenseEntry.fromJson(updates);
    }
    return fallback;
  }

  Map<String, dynamic>? _responseMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> _refreshAfterCommittedUpdate({
    required String userId,
    required Set<String> affectedHouseholdIds,
  }) async {
    try {
      // `confirmedExpense` has already replaced the optimistic local row. Do
      // not clear household SQLite snapshots or independently invalidate the
      // expense and split providers here: their remote reads are not atomic,
      // and doing so publishes a temporary payer-full view after every edit.
      ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      ref
          .read(dashboardCurrencySummariesRefreshSignalProvider.notifier)
          .state += 1;

      // Household rows do not belong to the personal analytics feed. Keep its
      // expensive reload for a personal edit only; household reconciliation is
      // performed by the normal outbox/resume delta sync.
      if (affectedHouseholdIds.isEmpty) {
        await ref.read(analyticsProvider.notifier).loadData(userId);
      }
      _debugPrint('✅ Background expense update reconciliation completed');
    } catch (error) {
      // The backend commit and confirmed local row remain authoritative. A
      // later app/tab refresh will retry reconciliation naturally.
      _debugPrint('⚠️ Background expense update reconciliation failed: $error');
    }
  }

  Future<void> _refreshAfterTransactionMutation(String userId) async {
    await ref.read(analyticsProvider.notifier).loadData(userId);

    ref.invalidate(householdExpensesProvider);
    ref.invalidate(householdSplitsProvider);
    ref.invalidate(cachedHouseholdExpensesProvider);
    ref.invalidate(cachedHouseholdSplitsProvider);
    ref.invalidate(householdSettlementPaymentsProvider);
    ref.invalidate(householdPairwiseSettlementBalancesV2Provider);
    ref.invalidate(householdSettlementBreakdownV2Provider);
    ref.read(cacheInvalidatorProvider).invalidateAll();

    ref.invalidate(currencyTransactionCountsProvider);
    ref.read(dashboardCurrencySummariesRefreshSignalProvider.notifier).state +=
        1;
    ref.read(walletActionsProvider).refreshAccountData();
  }

  Future<void> _refreshAfterLocalTransactionMutation(String userId) async {
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardCurrencySummariesRefreshSignalProvider.notifier).state +=
        1;
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

  void _removeLocalOptimisticTransactionsFromProviders(
    List<ExpenseEntry> entries,
  ) {
    for (final entry in entries) {
      final householdId = entry.householdId?.trim();
      if (householdId != null && householdId.isNotEmpty) {
        ref
            .read(householdOptimisticExpensesProvider.notifier)
            .removeExpense(householdId, entry.id);
      } else {
        ref
            .read(analyticsProvider.notifier)
            .removeOptimisticTransactionById(entry.id);
      }
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
    final updatedDate = updates['date'] != null
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
        : expense.date;
    final updatedCreatedAt = updates['created_at'] != null
        ? DateTime.tryParse(updates['created_at'].toString()) ??
            expense.createdAt
        : expense.createdAt;
    final updatedRecurrenceRuleJson = updates.containsKey('recurrence_rule')
        ? updates['recurrence_rule'] is Map<String, dynamic>
            ? updates['recurrence_rule'] as Map<String, dynamic>?
            : updates['recurrence_rule'] is Map
                ? Map<String, dynamic>.from(updates['recurrence_rule'] as Map)
                : null
        : expense.recurrenceRuleJson;
    final analyticsClass = updates.containsKey('category')
        ? _analyticsClassForCategory(expense, updates['category'])
        : expense.analyticsClass;
    final analyticsSpendingMultiplier = updates.containsKey('category')
        ? analyticsClass == 'consumer_spend'
            ? 1
            : 0
        : expense.analyticsSpendingMultiplier;
    final analyticsCountsTowardIncome = updates.containsKey('category')
        ? analyticsClass == 'income'
        : expense.analyticsCountsTowardIncome;

    return ExpenseEntry(
      id: expense.id,
      contactId: expense.contactId,
      userId: expense.userId,
      userName: expense.userName,
      userAvatarUrl: expense.userAvatarUrl,
      householdId: updates.containsKey('household_id')
          ? updates['household_id'] as String?
          : expense.householdId,
      date: updatedDate,
      amountCents: updates['amount_cents'] as int? ?? expense.amountCents,
      currency: updates['currency'] as String? ?? expense.currency,
      category: updates.containsKey('category')
          ? updates['category'] as String?
          : expense.category,
      createdAt: updatedCreatedAt,
      updatedAt: expense.updatedAt,
      rawText: updates.containsKey('raw_text')
          ? updates['raw_text'] as String?
          : expense.rawText,
      merchant: updates.containsKey('merchant')
          ? updates['merchant'] as String?
          : expense.merchant,
      breakdown: expense.breakdown,
      receiptImageUrl: updates.containsKey('receipt_image_url')
          ? updates['receipt_image_url'] as String?
          : expense.receiptImageUrl,
      sharedMemberIds: expense.sharedMemberIds,
      splitGroupId: updates.containsKey('split_group_id')
          ? updates['split_group_id'] as String?
          : expense.splitGroupId,
      bankAccountId: expense.bankAccountId,
      walletId: updates.containsKey('account_id')
          ? updates['account_id'] as String?
          : expense.walletId,
      accountName: expense.accountName,
      accountIcon: expense.accountIcon,
      accountColor: expense.accountColor,
      type: expense.type,
      analyticsClass: analyticsClass,
      analyticsIsFinal: expense.analyticsIsFinal,
      analyticsSpendingMultiplier: analyticsSpendingMultiplier,
      analyticsCountsTowardIncome: analyticsCountsTowardIncome,
      isRecurring: updates['is_recurring'] as bool? ?? expense.isRecurring,
      recurrenceRuleJson: updatedRecurrenceRuleJson,
      clientRecordId: expense.clientRecordId,
      clientMutationId: expense.clientMutationId,
      idempotencyKey: expense.idempotencyKey,
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
      } else if (updatedHouseholdId == null || updatedHouseholdId.isEmpty) {
        householdNotifier.removeExpense(originalHouseholdId, updatedExpense.id);
      } else {
        householdNotifier.replaceExpense(
          originalHouseholdId,
          updatedExpense.id,
          updatedExpense,
        );
      }
    } else if (updatedHouseholdId != null && updatedHouseholdId.isNotEmpty) {
      ref.read(householdOptimisticExpensesProvider.notifier).replaceExpense(
          updatedHouseholdId, updatedExpense.id, updatedExpense);
    }

    final analytics = ref.read(analyticsProvider);
    final updatedIsPersonal =
        updatedHouseholdId == null || updatedHouseholdId.isEmpty;

    final updatedExpenses = analytics.expenses
        .where((e) => e.id != updatedExpense.id)
        .toList(growable: true);
    final updatedAllExpenses = analytics.allExpenses
        .where((e) => e.id != updatedExpense.id)
        .toList(growable: true);

    if (updatedIsPersonal) {
      updatedExpenses.add(updatedExpense);
      updatedAllExpenses.add(updatedExpense);
    }

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
  return ErrorHandler.isRetryable(error);
}

final transactionEditSupabaseClientProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});

/// Provider for transaction editing state
final transactionEditProvider =
    StateNotifierProvider<TransactionEditNotifier, TransactionEditState>(
  (ref) => TransactionEditNotifier(ref),
);
