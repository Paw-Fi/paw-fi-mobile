import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
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
    int limit = 100,
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

    // Log current state
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugPrint('🔄 [RecurringTx] LOAD REQUESTED');
    _debugPrint(
        '   Scope: ${householdId == null ? 'PERSONAL' : 'HOUSEHOLD($householdId)'}');
    _debugPrint('   User context present');
    _debugPrint('   ForceRefresh: $forceRefresh');
    _debugPrint('   HasLoadedOnce: ${state.hasLoadedOnce}');
    _debugPrint('   IsLoading: ${state.data.isLoading}');

    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) {
      _debugPrint('   ⏭️  SKIPPING: Already loaded');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    _debugPrint('   ✅ PROCEEDING with load');
    state = state.copyWith(data: const AsyncValue.loading());

    try {
      _debugPrint(
          '🌐 [RecurringTx] Loading recurring transactions from expenses table...');

      // For recurring transactions we only need rows from the `expenses`
      // table where is_recurring=true. This avoids the heavier
      // list-expenses/list-income Edge Functions and keeps the data
      // flow simple and predictable.
      const timeout = Duration(seconds: 10);

      // Build base query for recurring rows only.
      final baseQuery = supabase
          .from('expenses')
          .select(
            'id, date, category, raw_text, breakdown, source, amount_cents, '
            'currency, owner_type, privacy_scope, household_id, is_recurring, '
            'user_id, split_group_id, '
            'recurrence_rule, type, attachments, created_at, updated_at',
          )
          .eq('is_recurring', true);

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

      _debugPrint('   📊 Raw recurring rows count: ${typedRows.length}');

      for (final item in typedRows) {
        try {
          final transaction = RecurringTransaction.fromJson(item);
          allTransactions.add(transaction);
          _debugPrint(
              '      ✅ Tx: ${transaction.id} | ${transaction.type} | ${transaction.category} | ${transaction.amount} | household=${transaction.householdId}');
        } catch (parseError) {
          _debugPrint('      ❌ Error parsing recurring row: $parseError');
          _debugPrint('      Raw row omitted for privacy');
        }
      }

      _debugPrint(
          '   📦 Total recurring transactions after scoping: ${allTransactions.length}');

      if (!mounted) {
        _debugPrint('   ⚠️  Provider unmounted, aborting');
        return;
      }

      state = state.copyWith(
        data: AsyncValue.data(allTransactions),
        hasLoadedOnce: true,
      );

      _debugPrint('   ✅ State updated successfully');
      _debugPrint('   📊 Final transaction list:');
      for (var t in allTransactions) {
        _debugPrint(
            '      - ${t.type}: ${t.category} | ${t.amount} ${t.currency} | ${t.recurrenceRule?.frequency ?? "one-time"}');
      }
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, st) {
      _debugPrint('❌ [RecurringTx] Exception: $e');
      _debugPrint('   Stack trace captured');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (!mounted) return;
      // Mark hasLoadedOnce=true even on error so the RecurringPage does
      // not keep auto-retrying in a loop. The error state will be
      // rendered and the user can manually pull-to-refresh.
      state = state.copyWith(
        data: AsyncValue.error(e, st),
        hasLoadedOnce: true,
      );
    }
  }

  /// Refresh recurring transactions list
  Future<void> refresh(String userId) async {
    if (!mounted) return;
    _debugPrint('🔄 Refresh requested for $householdId');
    await loadRecurringTransactions(
      userId,
      forceRefresh: true,
    );
  }

  /// Add transaction (optimistic update)
  void addRecurring(RecurringTransaction transaction) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      final updated = [transaction, ...transactions];
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

  /// Delete transaction
  Future<DeleteRecurringResult> deleteRecurring(
    String userId,
    String transactionId,
  ) async {
    if (_guardPreviewWrites()) {
      return const DeleteRecurringResult.failure('preview_mode_blocked');
    }
    try {
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugPrint('🗑️ [RecurringTx] DELETE REQUESTED');
      _debugPrint(
          '   Scope: ${householdId == null ? 'PERSONAL' : 'HOUSEHOLD($householdId)'}');
      _debugPrint('   User context present');
      _debugPrint('   TransactionId: $transactionId');

      // Optimistic update
      if (!mounted) {
        return const DeleteRecurringResult.failure('Provider unmounted');
      }
      state.data.whenData((transactions) {
        state = state.copyWith(
          data: AsyncValue.data(
            transactions.where((t) => t.id != transactionId).toList(),
          ),
        );
      });

      // Backend call
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {'userId': userId, 'expenseIds': transactionId},
      );

      _debugPrint(
          '✅ [RecurringTx] delete-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
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
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] DELETE EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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
      RecurringTransaction? target;
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
      final updatedExcluded = [...rule.excludedDates, dateToSkip];
      final updatedRule = rule.copyWith(excludedDates: updatedExcluded);

      // Optimistic update
      final updatedTransaction = target!.copyWith(recurrenceRule: updatedRule);
      updateRecurring(updatedTransaction);

      // Backend call - update the recurrence_rule via update-expense
      final response = await supabase.functions.invoke(
        'update-expense',
        body: {
          'userId': userId,
          'expenseId': transactionId,
          'updates': {
            'recurrence_rule': updatedRule.toJson(),
          },
        },
      );

      _debugPrint(
          '✅ [RecurringTx] update-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
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
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] SKIP EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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

  return allTransactions.data.when(
    data: (transactions) {
      final preferredTimezone = ref
          .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
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
    },
    loading: () => null,
    error: (_, __) => null,
  );
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
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

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
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
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

      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final expense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(expense);

        // Force refresh the list provider to show the new transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, transaction will be reloaded by invalidation');

        return expense;
      } else {
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
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

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

      final response = await supabase.functions.invoke(
        'save-income',
        body: {
          'userId': userId,
          'amount': amount,
          'category': category,
          'currency': currency,
          'date': formattedAccountingDate,
          'clientCreatedAt': clientCreatedAtIso,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (source != null && source.isNotEmpty) 'source': source,
          'ownerType': ownerType,
          'privacyScope': privacyScope,
          if (householdId != null) 'householdId': householdId,
          if (householdId != null)
            'isPortfolio':
                ref.read(householdScopeProvider).isPortfolioId(householdId),
          'isRecurring': true,
          'recurrence_rule': recurrenceRule,
        },
      );

      if (response.data['success'] == true) {
        final income = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(income);

        // Force refresh the list provider to show the new transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, transaction will be reloaded by invalidation');

        return income;
      } else {
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
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

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
      };
      if (description != null && description.trim().isNotEmpty) {
        updates['raw_text'] = description.trim();
      }

      _debugPrint('📝 [UpdateRecurring] Building update-expense request body');
      _debugPrint('   userId: $userId');
      _debugPrint('   expenseId: $expenseId');
      _debugPrint('   updates prepared');

      // Build base request body
      final requestBody = <String, dynamic>{
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
          if (previousHouseholdId == null) {
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

      final response = await supabase.functions.invoke(
        'update-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final updatedExpense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
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
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

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
      };
      if (description != null && description.trim().isNotEmpty) {
        updatesIncome['raw_text'] = description.trim();
      }
      if (source != null && source.trim().isNotEmpty) {
        updatesIncome['source'] = source.trim();
      }

      final response = await supabase.functions.invoke(
        'update-expense',
        body: {
          'userId': userId,
          'expenseId': expenseId,
          'updates': updatesIncome,
          // Keep update-expense date validation aligned with the caller's
          // local calendar day.
          'clientTimezoneOffsetMinutes':
              DateTime.now().timeZoneOffset.inMinutes,
        },
      );

      if (response.data['success'] == true) {
        final updatedIncome = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(updatedIncome);

        // Force refresh the list provider to show the updated transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [UpdateRecurring] Updated successfully, transaction will be reloaded by invalidation');

        return updatedIncome;
      } else {
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
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
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
