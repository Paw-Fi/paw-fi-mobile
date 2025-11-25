import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart'
    show SplitType, MemberSplit;
import 'package:intl/intl.dart';

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

  /// Load recurring transactions for the current scope (Personal or Household)
  Future<void> loadRecurringTransactions(
    String userId, {
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) {
      debugPrint('📦 RecurringTransactions($householdId): Already loaded, skipping');
      return;
    }

    debugPrint(
        '🔄 RecurringTransactions($householdId): Loading for userId=$userId');
    state = state.copyWith(data: const AsyncValue.loading());

    try {
      debugPrint('🌐 Using NEW architecture: includeRecurring=true on backend');

      // Fetch recurring expenses and incomes in parallel
      // Backend filters at database level for maximum performance
      final results = await Future.wait([
        supabase.functions.invoke(
          'list-expenses',
          body: {
            'userId': userId,
            'limit': limit,
            'includeRecurring': true,
            if (householdId != null) 'householdId': householdId,
          },
        ),
        supabase.functions.invoke(
          'list-income',
          body: {
            'userId': userId,
            'limit': limit,
            'includeRecurring': true,
            if (householdId != null) 'householdId': householdId,
          },
        ),
      ]);

      final expensesResponse = results[0];
      final incomesResponse = results[1];

      final allTransactions = <RecurringTransaction>[];

      // Process expenses
      if (expensesResponse.data['success'] == true) {
        final expensesData = expensesResponse.data['data'] as List<dynamic>;
        for (final item in expensesData) {
          try {
            final transaction =
                RecurringTransaction.fromJson(item as Map<String, dynamic>);
            allTransactions.add(transaction);
          } catch (parseError) {
            debugPrint('❌ Error parsing expense: $parseError');
          }
        }
      }

      // Process incomes
      if (incomesResponse.data['success'] == true) {
        final incomesData = incomesResponse.data['data'] as List<dynamic>;
        for (final item in incomesData) {
          try {
            final transaction =
                RecurringTransaction.fromJson(item as Map<String, dynamic>);
            allTransactions.add(transaction);
          } catch (parseError) {
            debugPrint('❌ Error parsing income: $parseError');
          }
        }
      }

      // Enforce scope on the client to avoid leaking other contexts
      final scopedTransactions = allTransactions.where((t) {
        if (householdId == null) {
          // Personal scope: only personal items
          return t.householdId == null;
        }
        // Household scope: match the current household
        return t.householdId == householdId;
      }).toList();

      // Sort by date (newest first)
      scopedTransactions.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        data: AsyncValue.data(scopedTransactions),
        hasLoadedOnce: true,
      );
    } catch (e, st) {
      debugPrint('❌ Exception: $e');
      state = state.copyWith(
        data: AsyncValue.error(e, st),
      );
    }
  }

  /// Refresh recurring transactions list
  Future<void> refresh(String userId) async {
    debugPrint('🔄 Refresh requested for $householdId');
    await loadRecurringTransactions(
      userId,
      forceRefresh: true,
    );
  }

  /// Add transaction (optimistic update)
  void addRecurring(RecurringTransaction transaction) {
    state.data.whenData((transactions) {
      final updated = [transaction, ...transactions];
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Update transaction
  void updateRecurring(RecurringTransaction transaction) {
    state.data.whenData((transactions) {
      final updated = transactions.map((t) {
        return t.id == transaction.id ? transaction : t;
      }).toList();
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Delete transaction
  Future<bool> deleteRecurring(String userId, String transactionId) async {
    try {
      // Optimistic update
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
        body: {'userId': userId, 'expenseId': transactionId},
      );

      if (response.data['success'] == true) {
        return true;
      } else {
        await refresh(userId);
        return false;
      }
    } catch (e) {
      await refresh(userId);
      return false;
    }
  }
}

// ============================================================================
// FILTERED PROVIDERS - Filter from single source of truth
// ============================================================================

/// Recurring expenses (filtered from unified provider by scope)
final recurringExpensesProvider = Provider.family<
    AsyncValue<List<RecurringTransaction>>, String?>((ref, householdId) {
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
final recurringIncomesProvider = Provider.family<
    AsyncValue<List<RecurringTransaction>>, String?>((ref, householdId) {
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
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (interval != null) 'interval': interval,
        if (hasReminder == true && reminderValue != null && reminderUnit != null)
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
        'clientCreatedAt': DateTime.now().toIso8601String(),
        if (description != null && description.isNotEmpty) 'description': description,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
      };

      if (householdId != null) {
        requestBody['householdId'] = householdId;

        if (customSplitType != null && customSplits != null && customSplits.isNotEmpty) {
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

          if (payerUserId != null && payerUserId.isNotEmpty) {
            requestBody['payerUserId'] = payerUserId;
          }
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
        // Update the relevant scope provider
        ref.read(recurringTransactionsProvider(householdId).notifier).addRecurring(expense);
        return expense;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to save',
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
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (interval != null) 'interval': interval,
        if (hasReminder == true && reminderValue != null && reminderUnit != null)
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
          'clientCreatedAt': DateTime.now().toIso8601String(),
          if (description != null && description.isNotEmpty) 'description': description,
          if (source != null && source.isNotEmpty) 'source': source,
          'ownerType': ownerType,
          'privacyScope': privacyScope,
          if (householdId != null) 'householdId': householdId,
          'isRecurring': true,
          'recurrence_rule': recurrenceRule,
        },
      );

      if (response.data['success'] == true) {
        final income = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(income);
        // Update the relevant scope provider
        ref.read(recurringTransactionsProvider(householdId).notifier).addRecurring(income);
        return income;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to save',
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
  }) async {
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (interval != null) 'interval': interval,
        if (hasReminder == true && reminderValue != null && reminderUnit != null)
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
      };
      if (description != null && description.trim().isNotEmpty) {
        updates['raw_text'] = description.trim();
      }

      final response = await supabase.functions.invoke(
        'update-expense',
        body: {
          'userId': userId,
          'expenseId': expenseId,
          'updates': updates,
        },
      );

      if (response.data['success'] == true) {
        final updatedExpense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(updatedExpense);
        // Update the relevant scope provider
        ref.read(recurringTransactionsProvider(householdId).notifier).updateRecurring(updatedExpense);
        return updatedExpense;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to update',
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
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (interval != null) 'interval': interval,
        if (hasReminder == true && reminderValue != null && reminderUnit != null)
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
        },
      );

      if (response.data['success'] == true) {
        final updatedIncome = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(updatedIncome);
        // Update the relevant scope provider
        ref.read(recurringTransactionsProvider(householdId).notifier).updateRecurring(updatedIncome);
        return updatedIncome;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to update',
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
}

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

final selectedRecurringTabProvider = StateProvider<int>((ref) => 0);
