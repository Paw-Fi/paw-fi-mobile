import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
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

/// Unified recurring transactions provider - fetches ALL recurring transactions
/// Uses NEW backend architecture with proper filtering
final recurringTransactionsProvider =
    StateNotifierProvider<RecurringTransactionsNotifier, RecurringTransactionsState>(
        (ref) {
  return RecurringTransactionsNotifier(ref);
});

class RecurringTransactionsNotifier extends StateNotifier<RecurringTransactionsState> {
  final Ref ref;

  RecurringTransactionsNotifier(this.ref)
      : super(RecurringTransactionsState(
          data: const AsyncValue.loading(),
          hasLoadedOnce: false,
        ));

  /// Load ALL recurring transactions (both expenses and income)
  /// Uses NEW backend filtering: includeRecurring=true
  Future<void> loadRecurringTransactions(
    String userId, {
    String? householdId,
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) {
      debugPrint('📦 RecurringTransactions: Already loaded, skipping');
      return;
    }

    debugPrint('🔄 RecurringTransactions: Loading for userId=$userId');
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
            'includeRecurring': true, // Backend filters: ONLY recurring expenses
            if (householdId != null) 'householdId': householdId,
          },
        ),
        supabase.functions.invoke(
          'list-income',
          body: {
            'userId': userId,
            'limit': limit,
            'includeRecurring': true, // Backend filters: ONLY recurring income
            if (householdId != null) 'householdId': householdId,
          },
        ),
      ]);

      final expensesResponse = results[0];
      final incomesResponse = results[1];

      debugPrint('📡 Expenses response status: ${expensesResponse.status}');
      debugPrint('📡 Expenses response data keys: ${expensesResponse.data?.keys.toList()}');
      debugPrint('📡 Incomes response status: ${incomesResponse.status}');
      debugPrint('📡 Incomes response data keys: ${incomesResponse.data?.keys.toList()}');

      final allTransactions = <RecurringTransaction>[];

      // Process expenses
      if (expensesResponse.data['success'] == true) {
        final expensesData = expensesResponse.data['data'] as List<dynamic>;
        final meta = expensesResponse.data['meta'];
        debugPrint('✅ Recurring expenses: ${expensesData.length} (total: ${meta['total']})');
        debugPrint('📊 First expense sample: ${expensesData.isNotEmpty ? expensesData[0] : "none"}');
        
        for (final item in expensesData) {
          try {
            final transaction = RecurringTransaction.fromJson(item as Map<String, dynamic>);
            allTransactions.add(transaction);
            debugPrint('  ✓ Parsed expense: ${transaction.id}, type: ${transaction.type}, recurring: ${transaction.recurrenceRule != null}');
          } catch (parseError) {
            debugPrint('❌ Error parsing expense: $parseError');
            debugPrint('❌ Item: ${jsonEncode(item)}');
          }
        }
      } else {
        debugPrint('❌ Expenses response failed: ${expensesResponse.data['error']}');
      }

      // Process incomes
      if (incomesResponse.data['success'] == true) {
        final incomesData = incomesResponse.data['data'] as List<dynamic>;
        final meta = incomesResponse.data['meta'];
        debugPrint('✅ Recurring incomes: ${incomesData.length} (total: ${meta['total']})');
        debugPrint('📊 First income sample: ${incomesData.isNotEmpty ? incomesData[0] : "none"}');
        
        for (final item in incomesData) {
          try {
            final transaction = RecurringTransaction.fromJson(item as Map<String, dynamic>);
            allTransactions.add(transaction);
            debugPrint('  ✓ Parsed income: ${transaction.id}, type: ${transaction.type}, recurring: ${transaction.recurrenceRule != null}');
          } catch (parseError) {
            debugPrint('❌ Error parsing income: $parseError');
            debugPrint('❌ Item: ${jsonEncode(item)}');
          }
        }
      } else {
        debugPrint('❌ Incomes response failed: ${incomesResponse.data['error']}');
      }

      // Sort by date (newest first)
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

      debugPrint('✅ Total recurring: ${allTransactions.length}');
      debugPrint('📊 Expenses: ${allTransactions.where((t) => t.type == "expense").length}');
      debugPrint('📊 Incomes: ${allTransactions.where((t) => t.type == "income").length}');
      
      state = state.copyWith(
        data: AsyncValue.data(allTransactions),
        hasLoadedOnce: true,
      );
    } catch (e, st) {
      debugPrint('❌ Exception: $e');
      debugPrint('❌ Stack: $st');
      state = state.copyWith(
        data: AsyncValue.error(e, st),
      );
    }
  }

  /// Refresh recurring transactions list
  Future<void> refresh(String userId, {String? householdId}) async {
    debugPrint('🔄 Refresh requested');
    await loadRecurringTransactions(
      userId,
      householdId: householdId,
      forceRefresh: true,
    );
  }

  /// Add transaction (optimistic update)
  void addRecurring(RecurringTransaction transaction) {
    debugPrint('➕ Adding: ${transaction.id}, type: ${transaction.type}');
    state.data.whenData((transactions) {
      final updated = [transaction, ...transactions];
      state = state.copyWith(data: AsyncValue.data(updated));
      debugPrint('✅ Added. Total: ${updated.length}');
    });
  }

  /// Update transaction
  void updateRecurring(RecurringTransaction transaction) {
    debugPrint('🔄 Updating: ${transaction.id}');
    state.data.whenData((transactions) {
      final updated = transactions.map((t) {
        return t.id == transaction.id ? transaction : t;
      }).toList();
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Delete transaction
  Future<bool> deleteRecurring(String userId, String transactionId) async {
    debugPrint('🗑️ Deleting: $transactionId');
    
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
        debugPrint('✅ Deleted successfully');
        return true;
      } else {
        debugPrint('❌ Delete failed, reloading');
        await refresh(userId);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      await refresh(userId);
      return false;
    }
  }
}

// ============================================================================
// FILTERED PROVIDERS - Filter from single source of truth
// ============================================================================

/// Recurring expenses (filtered from unified provider)
final recurringExpensesProvider = Provider<AsyncValue<List<RecurringTransaction>>>((ref) {
  final allTransactions = ref.watch(recurringTransactionsProvider);
  return allTransactions.data.when(
    data: (transactions) {
      final expenses = transactions.where((t) => t.type == 'expense').toList();
      return AsyncValue.data(expenses);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Recurring incomes (filtered from unified provider)
final recurringIncomesProvider = Provider<AsyncValue<List<RecurringTransaction>>>((ref) {
  final allTransactions = ref.watch(recurringTransactionsProvider);
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
  }) async {
    state = const AsyncValue.loading();

    try {
      // IMPORTANT: For recurring transactions:
      // - 'date' field = accounting date (must be today or in past)
      // - 'anchor_date' = schedule start date (can be in future)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // If start date is in the future, use today for accounting
      // Otherwise use the actual start date
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      debugPrint('💾 Save recurring expense:');
      debugPrint('  - User selected start: $startDate');
      debugPrint('  - Accounting date (for DB): $formattedAccountingDate');
      debugPrint('  - Schedule anchor: ${startDate.toIso8601String()}');
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(), // User-selected start (can be future)
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
        'save-expense',
        body: {
          'userId': userId,
          'amount': amount,
          'category': category,
          'currency': currency,
          'date': formattedAccountingDate, // Accounting date (today or past)
          'clientCreatedAt': DateTime.now().toIso8601String(),
          if (description != null && description.isNotEmpty) 'description': description,
          'ownerType': ownerType,
          'privacyScope': privacyScope,
          if (householdId != null) 'householdId': householdId,
          'isRecurring': true,
          'recurrence_rule': recurrenceRule,
        },
      );

      if (response.data['success'] == true) {
        final expense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(expense);
        ref.read(recurringTransactionsProvider.notifier).addRecurring(expense);
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
      // IMPORTANT: For recurring transactions:
      // - 'date' field = accounting date (must be today or in past)
      // - 'anchor_date' = schedule start date (can be in future)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // If start date is in the future, use today for accounting
      // Otherwise use the actual start date
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      debugPrint('💾 Save recurring income:');
      debugPrint('  - User selected start: $startDate');
      debugPrint('  - Accounting date (for DB): $formattedAccountingDate');
      debugPrint('  - Schedule anchor: ${startDate.toIso8601String()}');
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(), // User-selected start (can be future)
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
          'date': formattedAccountingDate, // Accounting date (today or past)
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
        ref.read(recurringTransactionsProvider.notifier).addRecurring(income);
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
      debugPrint('🔄 Updating recurring expense: $expenseId');
      
      // IMPORTANT: For recurring transactions:
      // - 'date' field = accounting date (must be today or in past)
      // - 'anchor_date' = schedule start date (can be in future)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // If start date is in the future, use today for accounting
      // Otherwise use the actual start date
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      debugPrint('  - User selected start: $startDate');
      debugPrint('  - Accounting date (for DB): $formattedAccountingDate');
      debugPrint('  - Schedule anchor: ${startDate.toIso8601String()}');
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(), // User-selected start (can be future)
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
        'date': formattedAccountingDate, // Accounting date (today or past)
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
        ref.read(recurringTransactionsProvider.notifier).updateRecurring(updatedExpense);
        debugPrint('✅ Updated successfully');
        return updatedExpense;
      } else {
        debugPrint('❌ Update failed: ${response.data['error']}');
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to update',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      debugPrint('❌ Exception during update: $e');
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update recurring income
  Future<RecurringTransaction?> updateRecurringIncome({
    required String userId,
    required String expenseId, // Uses expenses table
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
      debugPrint('🔄 Updating recurring income: $expenseId');
      
      // IMPORTANT: For recurring transactions:
      // - 'date' field = accounting date (must be today or in past)
      // - 'anchor_date' = schedule start date (can be in future)
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // If start date is in the future, use today for accounting
      // Otherwise use the actual start date
      final accountingDate = startDate.isAfter(today) ? today : startDate;
      final formattedAccountingDate = dateFormatter.format(accountingDate);
      
      debugPrint('  - User selected start: $startDate');
      debugPrint('  - Accounting date (for DB): $formattedAccountingDate');
      debugPrint('  - Schedule anchor: ${startDate.toIso8601String()}');
      
      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': startDate.toIso8601String(), // User-selected start (can be future)
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
        'date': formattedAccountingDate, // Accounting date (today or past)
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
        ref.read(recurringTransactionsProvider.notifier).updateRecurring(updatedIncome);
        debugPrint('✅ Updated successfully');
        return updatedIncome;
      } else {
        debugPrint('❌ Update failed: ${response.data['error']}');
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to update',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      debugPrint('❌ Exception during update: $e');
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
