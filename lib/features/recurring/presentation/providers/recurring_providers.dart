import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart'
    show SplitType, MemberSplit;
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/app/router.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

String _buildAnchorDateYmd(DateTime startDate) {
  return formatDateOnlyYmd(
    DateTime(startDate.year, startDate.month, startDate.day),
  );
}

String _buildClientCreatedAtIso(Ref ref) {
  return DateTime.now().toUtc().toIso8601String();
}

String? _buildEndDateYmd(DateTime? endDate) {
  if (endDate == null) return null;
  return formatDateOnlyYmd(DateTime(endDate.year, endDate.month, endDate.day));
}

String _makeOptimisticRecurringId() {
  return 'optimistic-recurring-${DateTime.now().microsecondsSinceEpoch}';
}

RecurringTransaction _recurringTransactionFromExpenseEntry(ExpenseEntry entry) {
  final description = entry.rawText?.trim();
  return RecurringTransaction(
    id: entry.id,
    userId: entry.userId,
    date: entry.date,
    category: entry.category ?? 'Uncategorized',
    description: description?.isEmpty == true ? null : description,
    merchant: entry.merchant,
    amount: entry.amount,
    currency: entry.currency ?? 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: entry.householdId,
    splitGroupId: entry.splitGroupId,
    accountId: entry.walletId,
    recurrenceRule: null,
    type: entry.type ?? 'expense',
    attachments: const [],
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
  );
}

ExpenseEntry _expenseEntryFromRecurringTransaction(
  RecurringTransaction transaction,
  String fallbackUserId,
) {
  return ExpenseEntry(
    id: transaction.id,
    userId: transaction.userId?.trim().isNotEmpty == true
        ? transaction.userId
        : fallbackUserId,
    householdId: transaction.householdId,
    date: transaction.date,
    amountCents: (transaction.amount * 100).round(),
    currency: transaction.currency,
    category: transaction.category,
    createdAt: transaction.createdAt,
    updatedAt: transaction.updatedAt,
    rawText:
        transaction.description ?? transaction.merchant ?? transaction.source,
    merchant: transaction.merchant,
    splitGroupId: transaction.splitGroupId,
    walletId: transaction.accountId,
    type: transaction.type,
    isRecurring: true,
  );
}

RecurringTransaction _buildOptimisticRecurringTransaction({
  required String userId,
  required String type,
  required double amount,
  required String category,
  required String currency,
  required DateTime startDate,
  required String frequency,
  DateTime? endDate,
  int? interval,
  String? description,
  String? merchant,
  String? source,
  bool? hasReminder,
  int? reminderValue,
  String? reminderUnit,
  String ownerType = 'me',
  String privacyScope = 'full',
  String? householdId,
  String? payerUserId,
  String? accountId,
}) {
  final now = DateTime.now();
  return RecurringTransaction(
    id: _makeOptimisticRecurringId(),
    userId: userId,
    date: DateTime(startDate.year, startDate.month, startDate.day),
    category: category,
    description: description,
    merchant: merchant,
    source: source,
    amount: amount,
    currency: currency,
    ownerType: ownerType,
    privacyScope: privacyScope,
    householdId: householdId,
    payerUserId: payerUserId,
    accountId: accountId,
    recurrenceRule: RecurrenceRule(
      frequency: frequency,
      anchorDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endDate == null
          ? null
          : DateTime(endDate.year, endDate.month, endDate.day),
      interval: interval,
      reminderEnabled: hasReminder,
      reminderValue: hasReminder == true ? reminderValue : null,
      reminderUnit: hasReminder == true ? reminderUnit : null,
    ),
    type: type,
    attachments: const [],
    createdAt: now,
    updatedAt: now,
  );
}

// ============================================================================
// STATE CLASSES WITH CACHING SUPPORT - SINGLE SOURCE OF TRUTH
// ============================================================================

/// Combined state class for ALL recurring transactions (single source of truth)
/// Frontend will filter by type (expense/income) from this unified list
class RecurringTransactionsState {
  final AsyncValue<List<RecurringTransaction>> data;
  final bool hasLoadedOnce;

  RecurringTransactionsState({
    required this.data,
    this.hasLoadedOnce = false,
  });

  RecurringTransactionsState copyWith({
    AsyncValue<List<RecurringTransaction>>? data,
    bool? hasLoadedOnce,
  }) {
    return RecurringTransactionsState(
      data: data ?? this.data,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

@immutable
class DeleteRecurringResult {
  final bool success;
  final String? error;

  const DeleteRecurringResult._({
    required this.success,
    this.error,
  });

  const DeleteRecurringResult.success() : this._(success: true);

  const DeleteRecurringResult.failure([String? error])
      : this._(success: false, error: error);
}

// ============================================================================
// UNIFIED RECURRING TRANSACTIONS PROVIDER (SINGLE SOURCE OF TRUTH)
// ============================================================================

/// Unified recurring transactions provider - fetches recurring transactions for a specific scope (Personal or Household)
/// householdId: null for Personal, non-null for Household
final recurringTransactionsProvider = StateNotifierProvider.family<
    RecurringTransactionsNotifier, RecurringTransactionsState, String?>(
  (ref, householdId) {
    return RecurringTransactionsNotifier(ref, householdId);
  },
);

class RecurringTransactionsNotifier
    extends StateNotifier<RecurringTransactionsState> {
  final Ref ref;
  final String? householdId; // Scope: null = Personal, non-null = Household

  RecurringTransactionsNotifier(this.ref, this.householdId)
      : super(RecurringTransactionsState(
          // Start with an empty dataset so widgets can trigger the first load
          // even when this provider instance hasn't fetched yet.
          data: const AsyncValue.data(<RecurringTransaction>[]),
          hasLoadedOnce: false,
        ));

  bool get _isPreview => ref.read(previewModeProvider).isActive;

  bool _guardPreviewWrites() {
    if (_isPreview) {
      _showPreviewToast();
      return true;
    }
    return false;
  }

  /// Load recurring transactions for the current scope (Personal or Household)
  Future<void> loadRecurringTransactions(
    String userId, {
    int limit = 250,
    bool forceRefresh = false,
  }) async {
    if (_isPreview) {
      final mockData = PreviewMockData.recurringTransactions;
      state = state.copyWith(
        data: AsyncValue.data(mockData),
        hasLoadedOnce: true,
      );
      return;
    }

    if (!mounted) return;

    final isOffline =
        ref.read(networkReachabilityProvider).valueOrNull == false;
    if (!forceRefresh) {
      final hydrated = await _hydrateFromLocalCache(userId, limit: limit);
      if (hydrated) {
        if (!isOffline) {
          unawaited(_refreshRecurringTransactionsFromNetwork(
            userId,
            limit,
            preserveCachedDataOnError: true,
          ));
        }
        return;
      }
    }

    if (isOffline) {
      state = state.copyWith(
        data: state.data.hasValue
            ? state.data
            : const AsyncValue.data(<RecurringTransaction>[]),
        hasLoadedOnce: true,
      );
      return;
    }

    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) return;
    if (!state.hasLoadedOnce || forceRefresh) {
      state = state.copyWith(
        data: const AsyncValue<List<RecurringTransaction>>.loading()
            .copyWithPrevious(state.data),
      );
    }

    await _refreshRecurringTransactionsFromNetwork(userId, limit);
  }

  Future<void> _refreshRecurringTransactionsFromNetwork(
    String userId,
    int limit, {
    bool preserveCachedDataOnError = false,
  }) async {
    if (!mounted) return;

    try {
      // For recurring transactions we only need rows from the `expenses`
      // table where is_recurring=true. This avoids the heavier
      // list-expenses/list-income Edge Functions and keeps the data
      // flow simple and predictable.
      const timeout = Duration(seconds: 10);

      // CRITICAL: keep account_id in this recurring base query.
      // STRICT REQUIREMENT: wallet pages need account_id to attach projected
      // recurring occurrences to the correct wallet. Removing it makes wallet
      // recurring transactions silently disappear again.
      // Build base query for recurring rows only.
      final baseQuery = supabase
          .from('expenses')
          .select(
            'id, date, category, raw_text, merchant, breakdown, source, amount_cents, '
            'currency, owner_type, privacy_scope, household_id, is_recurring, '
            'user_id, split_group_id, account_id, bank_account_id, provider, '
            'recurrence_rule, type, attachments, created_at, updated_at',
          )
          .eq('is_recurring', true)
          .isFilter('deleted_at', null)
          .isFilter('provider', null)
          .isFilter('bank_account_id', null);

      // Scope by household when in household mode; otherwise restrict to
      // the current user's personal recurring items (including portfolio households).
      // Portfolio households have is_portfolio=true and should be treated as personal.
      // The non-null assertion is safe because we only enter the first branch when householdId != null.
      dynamic scopedQuery;
      if (householdId != null && householdId!.trim().isNotEmpty) {
        final householdScope = ref.read(householdScopeProvider);
        if (householdScope.isPortfolioId(householdId)) {
          // Portfolio account: scoped to the selected portfolio household + current user.
          scopedQuery =
              baseQuery.eq('user_id', userId).eq('household_id', householdId!);
        } else {
          // Household-group account: scoped to the selected household.
          scopedQuery = baseQuery.eq('household_id', householdId!);
        }
      } else {
        // Personal account: household_id is null.
        scopedQuery =
            baseQuery.eq('user_id', userId).isFilter('household_id', null);
      }

      final rows = await scopedQuery
          .order('date', ascending: false)
          .limit(limit)
          .timeout(timeout);

      final allTransactions = <RecurringTransaction>[];
      final typedRows = (rows as List).cast<Map<String, dynamic>>();

      for (final item in typedRows) {
        try {
          allTransactions.add(RecurringTransaction.fromJson(item));
        } catch (parseError) {
          _debugPrint('[RecurringTx] Error parsing row: $parseError');
        }
      }

      if (!mounted) return;

      final currentTransactions =
          state.data.valueOrNull ?? const <RecurringTransaction>[];
      final pendingOptimistic = currentTransactions
          .where((transaction) =>
              transaction.id.startsWith('optimistic-recurring-'))
          .toList(growable: false);
      final serverIds =
          allTransactions.map((transaction) => transaction.id).toSet();
      final mergedTransactions = <RecurringTransaction>[
        ...pendingOptimistic.where(
          (transaction) => !serverIds.contains(transaction.id),
        ),
        ...allTransactions,
      ];

      state = state.copyWith(
        data: AsyncValue.data(mergedTransactions),
        hasLoadedOnce: true,
      );
      unawaited(_cacheRecurringTransactions(allTransactions, userId));

      _debugPrint(
          '[RecurringTx] Loaded ${allTransactions.length} recurring transactions');
    } catch (e, st) {
      _debugPrint('[RecurringTx] Load failed: $e');
      if (!mounted) return;
      if (preserveCachedDataOnError && state.data.hasValue) {
        return;
      }
      // Mark hasLoadedOnce=true even on error so the RecurringPage does
      // not keep auto-retrying in a loop. The error state will be
      // rendered and the user can manually pull-to-refresh.
      state = state.copyWith(
        data: AsyncValue.error(e, st),
        hasLoadedOnce: true,
      );
    }
  }

  Future<bool> _hydrateFromLocalCache(
    String userId, {
    required int limit,
  }) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      final rows = await database.getRecurringTransactions(
        userId: userId,
        householdId: householdId,
        limit: limit,
      );
      if (rows.isEmpty || !mounted) return false;

      state = state.copyWith(
        data: AsyncValue.data(
          rows.map(_recurringTransactionFromExpenseEntry).toList(
                growable: false,
              ),
        ),
        hasLoadedOnce: true,
      );
      return true;
    } catch (error) {
      _debugPrint('[RecurringTx] Local hydrate failed: $error');
      return false;
    }
  }

  Future<void> _cacheRecurringTransactions(
    List<RecurringTransaction> transactions,
    String fallbackUserId,
  ) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.replaceRecurringTransactionsForScope(
        userId: fallbackUserId,
        householdId: householdId,
        entries: transactions
            .map((transaction) => _expenseEntryFromRecurringTransaction(
                transaction, fallbackUserId))
            .where((entry) => entry.userId?.trim().isNotEmpty == true)
            .toList(growable: false),
      );
    } catch (error) {
      _debugPrint('[RecurringTx] Local cache write failed: $error');
    }
  }

  /// Refresh recurring transactions list
  Future<void> refresh(String userId) async {
    if (!mounted) return;

    await loadRecurringTransactions(
      userId,
      forceRefresh: true,
    );
  }

  /// Add transaction (optimistic update)
  void addRecurring(RecurringTransaction transaction) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      final withoutDuplicate = transactions
          .where((existing) => existing.id != transaction.id)
          .toList(growable: false);
      final updated = [transaction, ...withoutDuplicate];
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Update transaction
  void updateRecurring(RecurringTransaction transaction) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      final updated = transactions.map((t) {
        return t.id == transaction.id ? transaction : t;
      }).toList();
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Replace an optimistic row with the saved server row.
  void replaceRecurring(
    String optimisticId,
    RecurringTransaction savedTransaction,
  ) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      final updated = <RecurringTransaction>[];
      var inserted = false;

      for (final transaction in transactions) {
        if (transaction.id == optimisticId) {
          if (!inserted) {
            updated.add(savedTransaction);
            inserted = true;
          }
          continue;
        }
        if (transaction.id == savedTransaction.id) {
          if (!inserted) {
            updated.add(savedTransaction);
            inserted = true;
          }
          continue;
        }
        updated.add(transaction);
      }

      if (!inserted) {
        updated.insert(0, savedTransaction);
      }

      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Remove a pending or deleted recurring transaction from local state.
  void removeRecurring(String transactionId) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      state = state.copyWith(
        data: AsyncValue.data(
          transactions
              .where((transaction) => transaction.id != transactionId)
              .toList(growable: false),
        ),
      );
    });
  }

  /// Delete transaction
  Future<DeleteRecurringResult> deleteRecurring(
    String userId,
    String transactionId,
  ) async {
    if (_guardPreviewWrites()) {
      return const DeleteRecurringResult.failure('preview_mode_blocked');
    }
    MonekoDatabase? localDatabase;
    List<ExpenseEntry> deletedEntries = const <ExpenseEntry>[];
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: transactionId,
      operation: 'delete_recurring_transaction',
    );

    try {
      // Optimistic update
      if (!mounted) {
        return const DeleteRecurringResult.failure('Provider unmounted');
      }
      final currentTransactions = state.data.valueOrNull ?? const [];
      final target = currentTransactions
          .where((transaction) => transaction.id == transactionId)
          .firstOrNull;
      if (target != null) {
        deletedEntries = [
          _expenseEntryFromRecurringTransaction(target, userId),
        ];
      }
      state.data.whenData((transactions) {
        state = state.copyWith(
          data: AsyncValue.data(
            transactions.where((t) => t.id != transactionId).toList(),
          ),
        );
      });

      if (deletedEntries.isNotEmpty) {
        final database = await ref.read(localDatabaseProvider.future);
        localDatabase = database;
        await database.writeOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          payload: {
            ...mutationMetadata.toRequestJson(),
            'userId': userId,
            'expenseIds': transactionId,
          },
        );
      }

      // Backend call
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {
          ...mutationMetadata.toRequestJson(),
          'userId': userId,
          'expenseIds': transactionId,
        },
      );

      _debugPrint(
          '✅ [RecurringTx] delete-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
        await localDatabase?.markOptimisticTransactionDeleteSynced(
          clientMutationId: mutationMetadata.clientMutationId,
        );
        // Keep other tabs (pockets + currency selector) in sync with the
        // underlying `expenses` table mutation.
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        _debugPrint('✅ [RecurringTx] DELETE SUCCEEDED');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.success();
      }

      final payload = response.data;
      final errorMessage = _extractFunctionError(payload) ??
          (response.status >= 400
              ? 'Request failed (${response.status})'
              : null);

      _debugPrint('❌ [RecurringTx] DELETE FAILED: $errorMessage');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (deletedEntries.isNotEmpty) {
        await localDatabase?.rollbackOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          error: errorMessage ?? 'Delete failed',
        );
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] DELETE EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);
        return const DeleteRecurringResult.success();
      }
      if (deletedEntries.isNotEmpty) {
        await localDatabase?.rollbackOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(
          ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Skip a single occurrence by adding its date to excluded_dates
  Future<DeleteRecurringResult> skipOccurrence(
    String userId,
    String transactionId,
    DateTime dateToSkip,
  ) async {
    if (_guardPreviewWrites()) {
      return const DeleteRecurringResult.failure('preview_mode_blocked');
    }
    MonekoDatabase? localDatabase;
    ExpenseEntry? originalEntry;
    ExpenseEntry? updatedEntry;
    RecurringTransaction? target;
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: transactionId,
      operation: 'skip_recurring_occurrence',
    );
    try {
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugPrint('⏭️ [RecurringTx] SKIP OCCURRENCE REQUESTED');
      _debugPrint(
          '   Scope: ${householdId == null ? 'PERSONAL' : 'HOUSEHOLD($householdId)'}');
      _debugPrint('   User context present');
      _debugPrint('   TransactionId: $transactionId');
      _debugPrint('   DateToSkip: $dateToSkip');

      if (!mounted) {
        return const DeleteRecurringResult.failure('Provider unmounted');
      }

      // Find the transaction to get its current recurrence_rule
      state.data.whenData((transactions) {
        target = transactions.where((t) => t.id == transactionId).firstOrNull;
      });

      if (target == null) {
        _debugPrint('❌ [RecurringTx] SKIP FAILED: Transaction not found');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.failure('Transaction not found');
      }

      final rule = target!.recurrenceRule;
      if (rule == null) {
        _debugPrint('❌ [RecurringTx] SKIP FAILED: No recurrence rule');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.failure('No recurrence rule');
      }

      // Build updated rule with the new excluded date
      final updatedExcluded = {
        ...rule.excludedDates.map(formatDateOnlyYmd),
        formatDateOnlyYmd(dateToSkip),
      }.map(DateTime.parse).toList(growable: false);
      final updatedRule = rule.copyWith(excludedDates: updatedExcluded);

      // Optimistic update
      final updatedTransaction = target!.copyWith(recurrenceRule: updatedRule);
      updateRecurring(updatedTransaction);
      originalEntry = _expenseEntryFromRecurringTransaction(target!, userId);
      updatedEntry = _expenseEntryFromRecurringTransaction(
        updatedTransaction,
        userId,
      );
      final updates = {'recurrence_rule': updatedRule.toJson()};
      final database = await ref.read(localDatabaseProvider.future);
      localDatabase = database;
      await database.writeOptimisticTransactionUpdate(
        originalEntry: originalEntry,
        updatedEntry: updatedEntry,
        clientMutationId: mutationMetadata.clientMutationId,
        payload: {
          ...mutationMetadata.toRequestJson(),
          'userId': userId,
          'expenseId': transactionId,
          'updates': updates,
        },
      );

      // Backend call - update the recurrence_rule via update-expense
      final response = await supabase.functions.invoke(
        'update-expense',
        body: {
          ...mutationMetadata.toRequestJson(),
          'userId': userId,
          'expenseId': transactionId,
          'updates': updates,
        },
      );

      _debugPrint(
          '✅ [RecurringTx] update-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
        await localDatabase.markMutationSynced(
          mutationMetadata.clientMutationId,
        );
        _debugPrint('✅ [RecurringTx] SKIP OCCURRENCE SUCCEEDED');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.success();
      }

      final payload = response.data;
      final errorMessage = _extractFunctionError(payload) ??
          (response.status >= 400
              ? 'Request failed (${response.status})'
              : null);

      _debugPrint('❌ [RecurringTx] SKIP FAILED: $errorMessage');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await localDatabase.rollbackOptimisticTransactionUpdate(
        originalEntry: originalEntry,
        clientMutationId: mutationMetadata.clientMutationId,
        error: errorMessage ?? 'Skip occurrence failed',
      );
      updateRecurring(target!);
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] SKIP EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);
        return const DeleteRecurringResult.success();
      }
      if (originalEntry != null && updatedEntry != null) {
        await localDatabase?.rollbackOptimisticTransactionUpdate(
          originalEntry: originalEntry,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      if (target != null) {
        updateRecurring(target!);
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(
          ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  String? _extractFunctionError(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }
}

// ============================================================================
// FILTERED PROVIDERS - Filter from single source of truth
// ============================================================================

/// Recurring expenses (filtered from unified provider by scope)
final recurringExpensesProvider =
    Provider.family<AsyncValue<List<RecurringTransaction>>, String?>(
        (ref, householdId) {
  final allTransactions = ref.watch(recurringTransactionsProvider(householdId));

  return allTransactions.data.when(
    data: (transactions) {
      final expenses = transactions.where((t) => t.type == 'expense').toList();
      return AsyncValue.data(expenses);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Recurring incomes (filtered from unified provider by scope)
final recurringIncomesProvider =
    Provider.family<AsyncValue<List<RecurringTransaction>>, String?>(
        (ref, householdId) {
  final allTransactions = ref.watch(recurringTransactionsProvider(householdId));

  return allTransactions.data.when(
    data: (transactions) {
      final incomes = transactions.where((t) => t.type == 'income').toList();
      return AsyncValue.data(incomes);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

class UpcomingRecurringScope {
  final String? householdId;
  final String? currency;

  const UpcomingRecurringScope({this.householdId, this.currency});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpcomingRecurringScope &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          currency == other.currency;

  @override
  int get hashCode => householdId.hashCode ^ (currency?.hashCode ?? 0);
}

class UpcomingRecurringTransaction {
  final RecurringTransaction transaction;
  final DateTime nextOccurrence;
  final int daysUntil;

  const UpcomingRecurringTransaction({
    required this.transaction,
    required this.nextOccurrence,
    required this.daysUntil,
  });
}

/// Next recurring transaction due within 3 days for the current scope.
final upcomingRecurringTransactionProvider =
    Provider.family<UpcomingRecurringTransaction?, UpcomingRecurringScope>(
        (ref, scope) {
  final allTransactions =
      ref.watch(recurringTransactionsProvider(scope.householdId));
  final currency = scope.currency?.trim().toUpperCase();
  final transactions = allTransactions.data.valueOrNull;
  if (transactions == null) return null;

  final preferredTimezone =
      ref.watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
  final today = effectiveToday(preferredTimezone: preferredTimezone);
  UpcomingRecurringTransaction? best;

  for (final transaction in transactions) {
    if (!transaction.isActive) continue;
    if (currency != null &&
        currency.isNotEmpty &&
        transaction.currency.toUpperCase() != currency) {
      continue;
    }

    final nextOccurrence = transaction.getNextOccurrence(today);
    final nextDate = DateTime(
      nextOccurrence.year,
      nextOccurrence.month,
      nextOccurrence.day,
    );
    final daysUntil = nextDate.difference(today).inDays;

    if (daysUntil < 0 || daysUntil > 3) continue;

    final candidate = UpcomingRecurringTransaction(
      transaction: transaction,
      nextOccurrence: nextDate,
      daysUntil: daysUntil,
    );

    if (best == null || nextDate.isBefore(best.nextOccurrence)) {
      best = candidate;
    }
  }

  return best;
});

// ============================================================================
// SAVE PROVIDER
// ============================================================================

final recurringTransactionSaveProvider = StateNotifierProvider<
    RecurringTransactionSaveNotifier, AsyncValue<RecurringTransaction?>>((ref) {
  return RecurringTransactionSaveNotifier(ref);
});

class RecurringTransactionSaveNotifier
    extends StateNotifier<AsyncValue<RecurringTransaction?>> {
  final Ref ref;

  RecurringTransactionSaveNotifier(this.ref)
      : super(const AsyncValue.data(null));

  bool get _isPreview => ref.read(previewModeProvider).isActive;

  bool _guardPreviewWrites() {
    if (_isPreview) {
      _showPreviewToast();
      return true;
    }
    return false;
  }

  /// Save recurring expense
  Future<RecurringTransaction?> saveRecurringExpense({
    required String userId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();
    RecurringTransaction? optimisticTransaction;
    TransactionMutationMetadata? mutationMetadata;
    MonekoDatabase? localDatabase;

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);
      final clientCreatedAtIso = _buildClientCreatedAtIso(ref);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final Map<String, dynamic> requestBody = {
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': clientCreatedAtIso,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
        if (accountId != null) 'accountId': accountId,
      };

      if (householdId != null) {
        final isPortfolio =
            ref.read(householdScopeProvider).isPortfolioId(householdId);
        requestBody['householdId'] = householdId;
        requestBody['isPortfolio'] = isPortfolio;

        if (!isPortfolio &&
            customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;

          requestBody['customSplits'] = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };

              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };
        }

        if (!isPortfolio && payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
        }
      }

      optimisticTransaction = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'expense',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      );
      mutationMetadata = buildTransactionMutationMetadata(
        optimisticTransaction.id,
      );
      requestBody.addAll(mutationMetadata.toRequestJson());
      ref
          .read(recurringTransactionsProvider(householdId).notifier)
          .addRecurring(optimisticTransaction);
      localDatabase = await _queueRecurringCreate(
        optimisticTransaction: optimisticTransaction,
        mutationMetadata: mutationMetadata,
        functionName: 'save-expense',
        requestBody: requestBody,
        fallbackUserId: userId,
      );

      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final expense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(optimisticTransaction.id, expense);
        await localDatabase?.replaceOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          savedEntry: _expenseEntryFromRecurringTransaction(expense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(expense);

        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, optimistic row reconciled');
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        return expense;
      } else {
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .removeRecurring(optimisticTransaction.id);
        await localDatabase?.rollbackOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          clientMutationId: mutationMetadata.clientMutationId,
          error: response.data,
        );
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to save recurring expense',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      try {
        final optimistic = optimisticTransaction;
        final metadata = mutationMetadata;
        if (optimistic != null &&
            localDatabase != null &&
            _shouldKeepQueuedLocalMutation(e)) {
          state = AsyncValue.data(optimistic);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return optimistic;
        }
        if (optimistic != null) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(optimistic.id);
          if (localDatabase != null && metadata != null) {
            await localDatabase.rollbackOptimisticTransaction(
              optimisticId: optimistic.id,
              clientMutationId: metadata.clientMutationId,
              error: e,
            );
          }
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Save recurring income
  Future<RecurringTransaction?> saveRecurringIncome({
    required String userId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();
    RecurringTransaction? optimisticTransaction;
    TransactionMutationMetadata? mutationMetadata;
    MonekoDatabase? localDatabase;

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);
      final clientCreatedAtIso = _buildClientCreatedAtIso(ref);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      optimisticTransaction = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'income',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        source: source,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        accountId: accountId,
      );
      mutationMetadata = buildTransactionMutationMetadata(
        optimisticTransaction.id,
      );
      ref
          .read(recurringTransactionsProvider(householdId).notifier)
          .addRecurring(optimisticTransaction);

      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': clientCreatedAtIso,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        if (source != null && source.isNotEmpty) 'source': source,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        if (householdId != null) 'householdId': householdId,
        if (householdId != null)
          'isPortfolio':
              ref.read(householdScopeProvider).isPortfolioId(householdId),
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
        if (accountId != null) 'accountId': accountId,
      };
      localDatabase = await _queueRecurringCreate(
        optimisticTransaction: optimisticTransaction,
        mutationMetadata: mutationMetadata,
        functionName: 'save-income',
        requestBody: requestBody,
        fallbackUserId: userId,
      );

      final response = await supabase.functions.invoke(
        'save-income',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final income = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(optimisticTransaction.id, income);
        await localDatabase?.replaceOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          savedEntry: _expenseEntryFromRecurringTransaction(income, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(income);

        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, optimistic row reconciled');
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        return income;
      } else {
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .removeRecurring(optimisticTransaction.id);
        await localDatabase?.rollbackOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          clientMutationId: mutationMetadata.clientMutationId,
          error: response.data,
        );
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to save recurring income',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      try {
        final optimistic = optimisticTransaction;
        final metadata = mutationMetadata;
        if (optimistic != null &&
            localDatabase != null &&
            _shouldKeepQueuedLocalMutation(e)) {
          state = AsyncValue.data(optimistic);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return optimistic;
        }
        if (optimistic != null) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(optimistic.id);
          if (localDatabase != null && metadata != null) {
            await localDatabase.rollbackOptimisticTransaction(
              optimisticId: optimistic.id,
              clientMutationId: metadata.clientMutationId,
              error: e,
            );
          }
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<RecurringTransaction?> updateSingleExpenseOccurrence({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
    required double amount,
    required String category,
    required String currency,
    required DateTime date,
    String? description,
    String? merchant,
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(date);

      final requestBody = <String, dynamic>{
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': _buildClientCreatedAtIso(ref),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (merchant != null && merchant.trim().isNotEmpty)
          'merchant': merchant.trim(),
        'ownerType': recurringSeries.ownerType,
        'privacyScope': recurringSeries.privacyScope,
        'isRecurring': false,
        if (accountId != null) 'accountId': accountId,
      };

      if (householdId != null) {
        final isPortfolio =
            ref.read(householdScopeProvider).isPortfolioId(householdId);
        requestBody['householdId'] = householdId;
        requestBody['isPortfolio'] = isPortfolio;

        if (!isPortfolio &&
            customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;
          requestBody['customSplits'] = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };

              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };
        }

        if (!isPortfolio && payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
        }
      }

      final createResponse = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (createResponse.data['success'] != true) {
        final errorPayload = _buildFunctionErrorPayload(
          createResponse.data,
          fallback: 'Failed to save single expense occurrence',
        );
        state = AsyncValue.error(errorPayload, StackTrace.current);
        return null;
      }

      final created = RecurringTransaction.fromJson(
          createResponse.data['data'] as Map<String, dynamic>);

      final skipSucceeded = await _excludeOccurrenceFromSeries(
        userId: userId,
        recurringSeries: recurringSeries,
        occurrenceDateToSkip: occurrenceDateToSkip,
      );

      if (!skipSucceeded) {
        await _deleteExpenseById(userId: userId, expenseId: created.id);
        state = AsyncValue.error(
          const {
            'error': 'Failed to update recurring series for single occurrence',
            'code': 'SERIES_UPDATE_FAILED',
          },
          StackTrace.current,
        );
        return null;
      }

      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<RecurringTransaction?> updateSingleIncomeOccurrence({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
    required double amount,
    required String category,
    required String currency,
    required DateTime date,
    String? description,
    String? merchant,
    String? source,
    String? householdId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(date);

      final createResponse = await supabase.functions.invoke(
        'save-income',
        body: {
          'userId': userId,
          'amount': amount,
          'category': category,
          'currency': currency,
          'date': formattedAccountingDate,
          'clientCreatedAt': _buildClientCreatedAtIso(ref),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (merchant != null && merchant.trim().isNotEmpty)
            'merchant': merchant.trim(),
          if (source != null && source.trim().isNotEmpty)
            'source': source.trim(),
          'ownerType': recurringSeries.ownerType,
          'privacyScope': recurringSeries.privacyScope,
          if (householdId != null) 'householdId': householdId,
          if (householdId != null)
            'isPortfolio':
                ref.read(householdScopeProvider).isPortfolioId(householdId),
          'isRecurring': false,
          if (accountId != null) 'accountId': accountId,
        },
      );

      if (createResponse.data['success'] != true) {
        final errorPayload = _buildFunctionErrorPayload(
          createResponse.data,
          fallback: 'Failed to save single income occurrence',
        );
        state = AsyncValue.error(errorPayload, StackTrace.current);
        return null;
      }

      final created = RecurringTransaction.fromJson(
          createResponse.data['data'] as Map<String, dynamic>);

      final skipSucceeded = await _excludeOccurrenceFromSeries(
        userId: userId,
        recurringSeries: recurringSeries,
        occurrenceDateToSkip: occurrenceDateToSkip,
      );

      if (!skipSucceeded) {
        await _deleteExpenseById(userId: userId, expenseId: created.id);
        state = AsyncValue.error(
          const {
            'error': 'Failed to update recurring series for single occurrence',
            'code': 'SERIES_UPDATE_FAILED',
          },
          StackTrace.current,
        );
        return null;
      }

      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update recurring expense
  Future<RecurringTransaction?> updateRecurringExpense({
    required String userId,
    required String expenseId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? previousHouseholdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    final originalScopeKey = previousHouseholdId ?? householdId;
    final originalExpense = ref
        .read(recurringTransactionsProvider(originalScopeKey))
        .data
        .valueOrNull
        ?.where((transaction) => transaction.id == expenseId)
        .firstOrNull;
    MonekoDatabase? localDatabase;
    TransactionMutationMetadata? mutationMetadata;

    void rollbackOptimisticExpense() {
      try {
        if (householdId != originalScopeKey) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(expenseId);
        }
        if (originalExpense != null) {
          ref
              .read(recurringTransactionsProvider(originalScopeKey).notifier)
              .replaceRecurring(expenseId, originalExpense);
        }
      } catch (_) {}
    }

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      // Keep the row's `date` aligned with the user-selected schedule day.
      // This value is date-only and is used across the UI for calendar semantics.
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final updates = <String, dynamic>{
        'amount_cents': (amount * 100).round(),
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'is_recurring': true,
        'recurrence_rule': recurrenceRule,
        'household_id': householdId,
        'account_id': accountId,
      };
      updates['raw_text'] = description != null && description.trim().isNotEmpty
          ? description.trim()
          : null;
      updates['merchant'] = merchant != null && merchant.trim().isNotEmpty
          ? merchant.trim()
          : null;

      _debugPrint('📝 [UpdateRecurring] Building update-expense request body');
      _debugPrint('   userId: $userId');
      _debugPrint('   expenseId: $expenseId');
      _debugPrint('   updates prepared');

      // Build base request body
      mutationMetadata = buildTransactionMutationMetadataForRecord(
        clientRecordId: expenseId,
        operation: 'update_recurring_expense',
      );
      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
        'userId': userId,
        'expenseId': expenseId,
        'updates': updates,
        // Keep update-expense date validation aligned with the caller's local
        // calendar day (same behavior as non-recurring transaction edits).
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      };

      // Attach household sharing + splits only for group expenses
      if (householdId != null) {
        requestBody['householdId'] = householdId;

        if (customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;
          final splitsPayload = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };
              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };

          // If the previous recurring expense was personal (no household),
          // we are converting personal -> group: mirror unified_transaction_sheet
          // by creating the initial split group via customSplits.
          if (previousHouseholdId == null ||
              previousHouseholdId != householdId) {
            requestBody['customSplits'] = splitsPayload;
          } else {
            // Existing group recurring expense: mirror unified_transaction_sheet
            // by sending splitUpdate to recompute the split lines.
            requestBody['splitUpdate'] = splitsPayload;
          }
        }

        // Always propagate payer updates for group expenses when provided
        if (payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
          updates['payer_user_id'] = payerUserId;
        }
      }

      // DEBUG: log outgoing update payload for recurring expense, including
      // splitUpdate/customSplits and payerUserId so we can confirm that
      // split edits are actually being sent to the backend.
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugPrint(
          '💾 [UpdateRecurring] Sending update-expense for recurring expense');
      _debugPrint('   expenseId: $expenseId');
      _debugPrint('   userId: $userId');
      _debugPrint('   householdId (target): $householdId');
      _debugPrint('   previousHouseholdId: $previousHouseholdId');
      _debugPrint('   payer update present: ${payerUserId != null}');
      _debugPrint('   updates prepared');
      if (requestBody.containsKey('customSplits')) {
        _debugPrint('   customSplits payload included');
      }
      if (requestBody.containsKey('splitUpdate')) {
        _debugPrint('   splitUpdate payload included');
      }
      _debugPrint('   Request key count: ${requestBody.length}');

      final optimisticExpense = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'expense',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      ).copyWith(id: expenseId);
      try {
        if (previousHouseholdId != null && previousHouseholdId != householdId) {
          ref
              .read(recurringTransactionsProvider(previousHouseholdId).notifier)
              .removeRecurring(expenseId);
        }
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(expenseId, optimisticExpense);
        if (originalExpense != null) {
          final database = await ref.read(localDatabaseProvider.future);
          localDatabase = database;
          await database.writeOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalExpense, userId),
            updatedEntry: _expenseEntryFromRecurringTransaction(
                optimisticExpense, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            payload: {
              ...mutationMetadata.toRequestJson(),
              'userId': userId,
              'expenseId': expenseId,
              'updates': updates,
              'extraBody': {
                if (householdId != null) 'householdId': householdId,
                if (requestBody.containsKey('customSplits'))
                  'customSplits': requestBody['customSplits'],
                if (requestBody.containsKey('splitUpdate'))
                  'splitUpdate': requestBody['splitUpdate'],
                if (requestBody.containsKey('payerUserId'))
                  'payerUserId': requestBody['payerUserId'],
              },
            },
          );
        }
      } catch (_) {}

      final response = await supabase.functions.invoke(
        'update-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final updatedExpense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        await localDatabase?.markOptimisticTransactionUpdateSynced(
          entry: _expenseEntryFromRecurringTransaction(updatedExpense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(updatedExpense);
        _debugPrint(
            '✅ [UpdateRecurring] update-expense succeeded for $expenseId');
        _debugPrint(
            '   Updated expense householdId: ${updatedExpense.householdId}');
        _debugPrint(
            '   Updated amount: ${updatedExpense.amount} ${updatedExpense.currency}');
        _debugPrint('   Updated category: ${updatedExpense.category}');

        // Optimistically update the unified recurring transactions list so
        // the Recurring page reflects the edited values immediately without
        // requiring a full app restart. The sheet will still trigger a
        // formal refresh after save to keep all scopes consistent.
        try {
          final scopeKey = updatedExpense.householdId;
          ref
              .read(recurringTransactionsProvider(scopeKey).notifier)
              .updateRecurring(updatedExpense);
        } catch (e, st) {
          _debugPrint(
              '⚠️ [UpdateRecurring] Failed to optimistically update list: $e');
          _debugPrint('   Stack: $st');
        }

        // Force refresh the list provider to show the updated transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [UpdateRecurring] Updated successfully, transaction will be reloaded by invalidation');

        return updatedExpense;
      } else {
        rollbackOptimisticExpense();
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to update recurring expense',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        final queued = ref
            .read(recurringTransactionsProvider(householdId))
            .data
            .valueOrNull
            ?.where((transaction) => transaction.id == expenseId)
            .firstOrNull;
        if (queued != null) {
          state = AsyncValue.data(queued);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return queued;
        }
      }
      if (localDatabase != null &&
          originalExpense != null &&
          mutationMetadata != null) {
        await localDatabase.rollbackOptimisticTransactionUpdate(
          originalEntry:
              _expenseEntryFromRecurringTransaction(originalExpense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      rollbackOptimisticExpense();
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update recurring income
  Future<RecurringTransaction?> updateRecurringIncome({
    required String userId,
    required String expenseId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    final originalIncome = ref
        .read(recurringTransactionsProvider(householdId))
        .data
        .valueOrNull
        ?.where((transaction) => transaction.id == expenseId)
        .firstOrNull;
    MonekoDatabase? localDatabase;
    TransactionMutationMetadata? mutationMetadata;

    void rollbackOptimisticIncome() {
      try {
        if (originalIncome != null) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .replaceRecurring(expenseId, originalIncome);
        }
      } catch (_) {}
    }

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      // Keep the row's `date` aligned with the user-selected schedule day.
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final updatesIncome = <String, dynamic>{
        'amount_cents': (amount * 100).round(),
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'is_recurring': true,
        'recurrence_rule': recurrenceRule,
        'household_id': householdId,
        'account_id': accountId,
      };
      updatesIncome['raw_text'] =
          description != null && description.trim().isNotEmpty
              ? description.trim()
              : null;
      updatesIncome['merchant'] = merchant != null && merchant.trim().isNotEmpty
          ? merchant.trim()
          : null;
      updatesIncome['source'] =
          source != null && source.trim().isNotEmpty ? source.trim() : null;

      final optimisticIncome = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'income',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        source: source,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        accountId: accountId,
      ).copyWith(id: expenseId);
      try {
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(expenseId, optimisticIncome);
        if (originalIncome != null) {
          mutationMetadata = buildTransactionMutationMetadataForRecord(
            clientRecordId: expenseId,
            operation: 'update_recurring_income',
          );
          final database = await ref.read(localDatabaseProvider.future);
          localDatabase = database;
          await database.writeOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalIncome, userId),
            updatedEntry:
                _expenseEntryFromRecurringTransaction(optimisticIncome, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            payload: {
              ...mutationMetadata.toRequestJson(),
              'userId': userId,
              'expenseId': expenseId,
              'updates': updatesIncome,
              'extraBody': {
                if (householdId != null) 'householdId': householdId,
              },
            },
          );
        }
      } catch (_) {}

      mutationMetadata ??= buildTransactionMutationMetadataForRecord(
        clientRecordId: expenseId,
        operation: 'update_recurring_income',
      );

      final response = await supabase.functions.invoke(
        'update-expense',
        body: {
          ...mutationMetadata.toRequestJson(),
          'userId': userId,
          'expenseId': expenseId,
          'updates': updatesIncome,
          if (householdId != null) 'householdId': householdId,
          // Keep update-expense date validation aligned with the caller's
          // local calendar day.
          'clientTimezoneOffsetMinutes':
              DateTime.now().timeZoneOffset.inMinutes,
        },
      );

      if (response.data['success'] == true) {
        final updatedIncome = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        await localDatabase?.markOptimisticTransactionUpdateSynced(
          entry: _expenseEntryFromRecurringTransaction(updatedIncome, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(updatedIncome);

        // Force refresh the list provider to show the updated transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [UpdateRecurring] Updated successfully, transaction will be reloaded by invalidation');

        return updatedIncome;
      } else {
        rollbackOptimisticIncome();
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to update recurring income',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        final queued = ref
            .read(recurringTransactionsProvider(householdId))
            .data
            .valueOrNull
            ?.where((transaction) => transaction.id == expenseId)
            .firstOrNull;
        if (queued != null) {
          state = AsyncValue.data(queued);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return queued;
        }
      }
      if (localDatabase != null &&
          originalIncome != null &&
          mutationMetadata != null) {
        await localDatabase.rollbackOptimisticTransactionUpdate(
          originalEntry:
              _expenseEntryFromRecurringTransaction(originalIncome, userId),
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      rollbackOptimisticIncome();
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }

  Future<bool> _excludeOccurrenceFromSeries({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
  }) async {
    final rule = recurringSeries.recurrenceRule;
    if (rule == null) {
      return false;
    }

    final skipDate = DateTime(
      occurrenceDateToSkip.year,
      occurrenceDateToSkip.month,
      occurrenceDateToSkip.day,
    );

    final alreadyExcluded = rule.excludedDates.any(
      (entry) =>
          entry.year == skipDate.year &&
          entry.month == skipDate.month &&
          entry.day == skipDate.day,
    );

    final updatedExcludedDates = alreadyExcluded
        ? rule.excludedDates
        : [...rule.excludedDates, skipDate];

    final updatedRule = rule.copyWith(excludedDates: updatedExcludedDates);

    final response = await supabase.functions.invoke(
      'update-expense',
      body: {
        'userId': userId,
        'expenseId': recurringSeries.id,
        'updates': {
          'recurrence_rule': updatedRule.toJson(),
        },
      },
    );

    if (response.data is! Map<String, dynamic> ||
        (response.data as Map<String, dynamic>)['success'] != true) {
      return false;
    }

    try {
      ref
          .read(recurringTransactionsProvider(recurringSeries.householdId)
              .notifier)
          .updateRecurring(
            recurringSeries.copyWith(recurrenceRule: updatedRule),
          );
    } catch (_) {}

    return true;
  }

  Future<void> _deleteExpenseById({
    required String userId,
    required String expenseId,
  }) async {
    try {
      await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': userId,
          'expenseIds': expenseId,
        },
      );
    } catch (_) {}
  }

  Map<String, dynamic> _buildFunctionErrorPayload(
    dynamic responseData, {
    required String fallback,
  }) {
    if (responseData is Map<String, dynamic>) {
      final rawError = responseData['error'] ?? responseData['message'];
      final errorText = rawError is String && rawError.trim().isNotEmpty
          ? rawError.trim()
          : fallback;
      return {
        'error': errorText,
        'code': responseData['code']?.toString(),
        'status': responseData['status'],
      };
    }

    return {
      'error': fallback,
      'code': 'SERVER_ERROR',
    };
  }

  Future<MonekoDatabase?> _queueRecurringCreate({
    required RecurringTransaction optimisticTransaction,
    required TransactionMutationMetadata mutationMetadata,
    required String functionName,
    required Map<String, dynamic> requestBody,
    required String fallbackUserId,
  }) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransaction(
        entry: _expenseEntryFromRecurringTransaction(
          optimisticTransaction,
          fallbackUserId,
        ),
        clientMutationId: mutationMetadata.clientMutationId,
        operation: 'create',
        payload: {
          ...mutationMetadata.toRequestJson(),
          'transaction': _expenseEntryFromRecurringTransaction(
            optimisticTransaction,
            fallbackUserId,
          ).toJson(),
          'functionName': functionName,
          'requestBody': requestBody,
        },
      );
      return database;
    } catch (error) {
      _debugPrint('[RecurringTx] Local recurring queue unavailable: $error');
      return null;
    }
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

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

final selectedRecurringTabProvider = StateProvider<int>((ref) => 0);

void _showPreviewToast() {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  AppToast.info(
    ctx,
    'Preview mode is read-only. Create an account to save recurring changes.',
  );
}
