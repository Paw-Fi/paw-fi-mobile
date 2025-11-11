import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

// ============================================================================
// STATE CLASSES WITH CACHING SUPPORT
// ============================================================================

/// State class to track if data has been loaded at least once (for expenses)
class RecurringExpensesState {
  final AsyncValue<List<RecurringTransaction>> data;
  final bool hasLoadedOnce;

  RecurringExpensesState({
    required this.data,
    this.hasLoadedOnce = false,
  });

  RecurringExpensesState copyWith({
    AsyncValue<List<RecurringTransaction>>? data,
    bool? hasLoadedOnce,
  }) {
    return RecurringExpensesState(
      data: data ?? this.data,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

/// State class for recurring incomes
class RecurringIncomesState {
  final AsyncValue<List<RecurringTransaction>> data;
  final bool hasLoadedOnce;

  RecurringIncomesState({
    required this.data,
    this.hasLoadedOnce = false,
  });

  RecurringIncomesState copyWith({
    AsyncValue<List<RecurringTransaction>>? data,
    bool? hasLoadedOnce,
  }) {
    return RecurringIncomesState(
      data: data ?? this.data,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

// ============================================================================
// RECURRING EXPENSES PROVIDER
// ============================================================================

/// Recurring expenses list provider with caching (like analyticsProvider)
final recurringExpensesProvider =
    StateNotifierProvider<RecurringExpensesNotifier, RecurringExpensesState>(
        (ref) {
  return RecurringExpensesNotifier(ref);
});

class RecurringExpensesNotifier extends StateNotifier<RecurringExpensesState> {
  final Ref ref;

  RecurringExpensesNotifier(this.ref)
      : super(RecurringExpensesState(
          data: const AsyncValue.loading(),
          hasLoadedOnce: false,
        ));

  /// Load recurring expenses for a user (only if not already loaded)
  /// Similar pattern to analyticsProvider - respects hasLoadedOnce flag
  Future<void> loadRecurringExpenses(
    String userId, {
    String? householdId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) {
      return;
    }

    state = state.copyWith(data: const AsyncValue.loading());

    try {
      final response = await supabase.functions.invoke(
        'list-expenses',
        body: {
          'userId': userId,
          'limit': limit,
          'includeRecurring': true, // Only fetch recurring transactions
          if (householdId != null) 'householdId': householdId,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as List<dynamic>;
        // Filter for recurring expenses only
        final recurringList = data
            .where((e) =>
                (e['is_recurring'] == true || e['isRecurring'] == true) &&
                e['type'] == 'expense')
            .map(
                (e) => RecurringTransaction.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          data: AsyncValue.data(recurringList),
          hasLoadedOnce: true,
        );
      } else {
        state = state.copyWith(
          data: AsyncValue.error(
            response.data['error'] ?? 'Failed to load recurring expenses',
            StackTrace.current,
          ),
        );
      }
    } catch (e, st) {
      state = state.copyWith(
        data: AsyncValue.error(e, st),
      );
    }
  }

  /// Refresh recurring expenses list (always reloads from backend)
  Future<void> refresh(String userId, {String? householdId}) async {
    await loadRecurringExpenses(
      userId,
      householdId: householdId,
      forceRefresh: true,
    );
  }

  /// Add a new recurring expense to the cached list (optimistic update)
  void addRecurringExpense(RecurringTransaction expense) {
    state.data.whenData((expenses) {
      final updated = [expense, ...expenses];
      state = state.copyWith(
        data: AsyncValue.data(updated),
      );
    });
  }

  /// Update an existing recurring expense in the cached list
  void updateRecurringExpense(RecurringTransaction expense) {
    state.data.whenData((expenses) {
      final updated = expenses.map((e) {
        return e.id == expense.id ? expense : e;
      }).toList();
      state = state.copyWith(
        data: AsyncValue.data(updated),
      );
    });
  }

  /// Delete a recurring expense (optimistic update + backend call)
  Future<bool> deleteRecurring(String userId, String expenseId) async {
    try {
      // Optimistically remove from local state first
      state.data.whenData((expenses) {
        state = state.copyWith(
          data: AsyncValue.data(
            expenses.where((e) => e.id != expenseId).toList(),
          ),
        );
      });

      // Call backend
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': userId,
          'expenseId': expenseId,
        },
      );

      if (response.data['success'] == true) {
        return true;
      } else {
        // If backend fails, reload to restore correct state
        await refresh(userId);
        return false;
      }
    } catch (e) {
      // If error, reload to restore correct state
      await refresh(userId);
      return false;
    }
  }
}

// ============================================================================
// RECURRING INCOMES PROVIDER
// ============================================================================

/// Recurring incomes list provider with caching
final recurringIncomesProvider =
    StateNotifierProvider<RecurringIncomesNotifier, RecurringIncomesState>(
        (ref) {
  return RecurringIncomesNotifier(ref);
});

class RecurringIncomesNotifier extends StateNotifier<RecurringIncomesState> {
  final Ref ref;

  RecurringIncomesNotifier(this.ref)
      : super(RecurringIncomesState(
          data: const AsyncValue.loading(),
          hasLoadedOnce: false,
        ));

  /// Load recurring incomes for a user (only if not already loaded)
  Future<void> loadRecurringIncomes(
    String userId, {
    String? householdId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Skip loading if already loaded successfully (unless forced refresh)
    if (state.hasLoadedOnce && !forceRefresh) {
      return;
    }

    state = state.copyWith(data: const AsyncValue.loading());

    try {
      final response = await supabase.functions.invoke(
        'list-income',
        body: {
          'userId': userId,
          'limit': limit,
          'includeRecurring': true, // Only fetch recurring transactions
          if (householdId != null) 'householdId': householdId,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as List<dynamic>;
        // Filter for recurring income only
        final recurringList = data
            .where((e) => e['is_recurring'] == true || e['isRecurring'] == true)
            .map(
                (e) => RecurringTransaction.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          data: AsyncValue.data(recurringList),
          hasLoadedOnce: true,
        );
      } else {
        state = state.copyWith(
          data: AsyncValue.error(
            response.data['error'] ?? 'Failed to load recurring income',
            StackTrace.current,
          ),
        );
      }
    } catch (e, st) {
      state = state.copyWith(
        data: AsyncValue.error(e, st),
      );
    }
  }

  /// Refresh recurring incomes list (always reloads from backend)
  Future<void> refresh(String userId, {String? householdId}) async {
    await loadRecurringIncomes(
      userId,
      householdId: householdId,
      forceRefresh: true,
    );
  }

  /// Add a new recurring income to the cached list (optimistic update)
  void addRecurringIncome(RecurringTransaction income) {
    state.data.whenData((incomes) {
      final updated = [income, ...incomes];
      state = state.copyWith(
        data: AsyncValue.data(updated),
      );
    });
  }

  /// Update an existing recurring income in the cached list
  void updateRecurringIncome(RecurringTransaction income) {
    state.data.whenData((incomes) {
      final updated = incomes.map((i) {
        return i.id == income.id ? income : i;
      }).toList();
      state = state.copyWith(
        data: AsyncValue.data(updated),
      );
    });
  }

  /// Delete a recurring income (optimistic update + backend call)
  Future<bool> deleteRecurring(String userId, String incomeId) async {
    try {
      // Optimistically remove from local state first
      state.data.whenData((incomes) {
        state = state.copyWith(
          data: AsyncValue.data(
            incomes.where((i) => i.id != incomeId).toList(),
          ),
        );
      });

      // Call backend
      final response = await supabase.functions.invoke(
        'delete-expense', // Income uses same endpoint (expenses table)
        body: {
          'userId': userId,
          'expenseId': incomeId,
        },
      );

      if (response.data['success'] == true) {
        return true;
      } else {
        // If backend fails, reload to restore correct state
        await refresh(userId);
        return false;
      }
    } catch (e) {
      // If error, reload to restore correct state
      await refresh(userId);
      return false;
    }
  }
}

// ============================================================================
// RECURRING TRANSACTION SAVE PROVIDER
// ============================================================================

/// Recurring transaction save provider (for both income and expense)
final recurringTransactionSaveProvider = StateNotifierProvider<
    RecurringTransactionSaveNotifier, AsyncValue<RecurringTransaction?>>((ref) {
  return RecurringTransactionSaveNotifier(ref);
});

class RecurringTransactionSaveNotifier
    extends StateNotifier<AsyncValue<RecurringTransaction?>> {
  final Ref ref;

  RecurringTransactionSaveNotifier(this.ref)
      : super(const AsyncValue.data(null));

  /// Save new recurring expense
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
      // Build recurrence rule with optional reminder
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

      debugPrint('🔶 saveRecurringExpense: Building request body');
      debugPrint('🔶 recurrenceRule: $recurrenceRule');
      
      final requestBody = {
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': startDate.toIso8601String(),
        'clientCreatedAt': DateTime.now().toIso8601String(),
        if (description != null && description.isNotEmpty)
          'description': description,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        if (householdId != null) 'householdId': householdId,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
      };
      
      debugPrint('🔶 Request body: $requestBody');
      debugPrint('🔶 Request body JSON: ${jsonEncode(requestBody)}');

      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      debugPrint('🔶 Response status: ${response.status}');
      debugPrint('🔶 Response data: ${response.data}');
      debugPrint('🔶 Response data type: ${response.data.runtimeType}');
      debugPrint('🔶 Response data[success]: ${response.data['success']}');

      if (response.data['success'] == true) {
        debugPrint('✅ Success check passed!');
        final expense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(expense);

        // Update cached list immediately (optimistic update)
        ref
            .read(recurringExpensesProvider.notifier)
            .addRecurringExpense(expense);

        return expense;
      } else {
        debugPrint('❌ Success check failed!');
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to save recurring expense',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      debugPrint('🔥 Exception caught in saveRecurringExpense: $e');
      debugPrint('🔥 Stack trace: $st');
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Save new recurring income
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
      // Build recurrence rule with optional reminder
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

      debugPrint('🔷 saveRecurringIncome: Building request body');
      debugPrint('🔷 recurrenceRule: $recurrenceRule');
      
      final requestBody = {
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': startDate.toIso8601String(),
        'clientCreatedAt': DateTime.now().toIso8601String(),
        if (description != null && description.isNotEmpty)
          'description': description,
        if (source != null && source.isNotEmpty) 'source': source,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        if (householdId != null) 'householdId': householdId,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
      };
      
      debugPrint('🔷 Request body: $requestBody');
      debugPrint('🔷 Request body JSON: ${jsonEncode(requestBody)}');

      final response = await supabase.functions.invoke(
        'save-income',
        body: requestBody,
      );

      debugPrint('🔷 Response status: ${response.status}');
      debugPrint('🔷 Response data: ${response.data}');
      debugPrint('🔷 Response data type: ${response.data.runtimeType}');
      debugPrint('🔷 Response data[success]: ${response.data['success']}');
      debugPrint('🔷 Response data[success] type: ${response.data['success'].runtimeType}');

      if (response.data['success'] == true) {
        debugPrint('✅ Success check passed!');
        final income = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(income);

        // Update cached list immediately (optimistic update)
        ref.read(recurringIncomesProvider.notifier).addRecurringIncome(income);

        return income;
      } else {
        debugPrint('❌ Success check failed!');
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to save recurring income',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      debugPrint('🔥 Exception caught: $e');
      debugPrint('🔥 Stack trace: $st');
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Reset save state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

/// Currently selected tab (expense or income)
final selectedRecurringTabProvider = StateProvider<int>((ref) => 0);
