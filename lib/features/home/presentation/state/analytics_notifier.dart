import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';

/// Analytics data provider with robust error handling and retry logic
class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(AnalyticsData());

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _edgeFunctionTimeout = Duration(seconds: 20);
  static const Duration _fallbackQueryTimeout = Duration(seconds: 15);

  /// Track current load operation to prevent race conditions
  int _loadOperationId = 0;

  /// Load all analytics data for a user.
  /// Always fetches ALL transactions (no date filtering) - local filtering is done in UI.
  Future<void> loadData(
    String userId, {
    int retryCount = 0,
  }) async {
    // Prevent concurrent loads - if already loading, skip this request
    // Exception: retries should continue (same operation)
    if (state.isLoading && retryCount == 0) {
      debugPrint('[Analytics] Skipping load - already in progress');
      return;
    }

    // Increment operation ID to track this specific load
    final currentOperationId = ++_loadOperationId;

    // Only set loading state, NOT hasLoadedOnce - that's set on success only
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (userId.isEmpty) {
        state = state.copyWith(
          error: 'Please log in to view analytics',
          isLoading: false,
        );
        return;
      }

      // Fetch ALL contacts for this user (some users may have more than one
      // historical contact id). We still use the most recent as the primary
      // contact for UI, but we will aggregate expenses/budgets across all
      // contact IDs to avoid missing older rows.
      final contactsResponse = await supabase
          .from('user_contacts')
          .select(
              'id,user_id,phone_e164,verified,preferred_currency,preferred_timezone,created_at,updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false);

      // Debug: Log what we fetched from database (only in debug mode)
      if (kDebugMode) {
        debugPrint('🔍 Analytics: userId = $userId');
        debugPrint('🔍 Analytics: contactsResponse = $contactsResponse');
        debugPrint(
            '🔍 Analytics: contactsResponse length = ${(contactsResponse as List).length}');
      }

      final contactsList =
          (contactsResponse as List).cast<Map<String, dynamic>>();
      final contactResponse =
          contactsList.isNotEmpty ? contactsList.first : null;

      if (kDebugMode) {
        debugPrint('🔍 Analytics: contactResponse = $contactResponse');
        debugPrint(
            '🔍 Analytics: preferred_currency from DB = ${contactResponse?['preferred_currency']}');
        debugPrint(
            '🔍 Analytics: preferred_timezone from DB = ${contactResponse?['preferred_timezone']}');
      }

      if (contactResponse == null) {
        // No contact found - this is okay for mobile-only users
        // Set empty state and show empty expenses/budgets
        state = state.copyWith(
          contact: null,
          expenses: [],
          allExpenses: [],
          budgets: [],
          allBudgets: [],
          preferredCurrency: null,
          isLoading: false,
        );
        return;
      }

      // Validate contact has required ID field
      if (contactResponse['id'] == null) {
        throw Exception('Contact record missing ID field');
      }

      final fetchedContact = UserContact.fromJson(contactResponse);

      // Debug: Log parsed contact (only in debug mode)
      if (kDebugMode) {
        debugPrint('🔍 Analytics: fetchedContact.id = ${fetchedContact.id}');
        debugPrint(
            '🔍 Analytics: fetchedContact.preferredCurrency = ${fetchedContact.preferredCurrency}');
      }

      // Fetch ALL historical data (all time) without date filtering
      // Ensures insights are computed from the complete history

      // Build list of all contact IDs associated with this user
      final contactIds = contactsList
          .map((c) => c['id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      // Fetch ALL PERSONAL expenses using optimized edge function
      // This uses list-expenses with proper filters instead of direct DB query
      // EXCLUDE recurring transactions and household expenses
      List<ExpenseEntry> allExpenses = [];
      bool expenseLoadFailed = false;
      try {
        // Fetch ALL transactions without date filtering
        // Local filtering is done in UI components
        final response = await supabase.functions.invoke(
          'list-expenses',
          body: {
            'userId': userId,
            'excludeRecurring': true, // Exclude recurring transactions
            'personalOnly':
                true, // Only personal expenses (split_group_id IS NULL)
            'limit': 1000, // Reduced limit for faster initial load
            // No date filters - fetch all data
          },
        ).timeout(_edgeFunctionTimeout);

        if (response.data != null) {
          final jsonData = response.data as Map<String, dynamic>;
          final expensesData = jsonData['data'] as List<dynamic>?;
          if (expensesData != null) {
            allExpenses = expensesData
                .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (expenseError) {
        // Handle errors gracefully with fallback
        debugPrint(
            '[Analytics] Error fetching expenses via edge function: $expenseError');

        // Fallback to direct DB query if edge function fails
        try {
          final fallbackResponse = await supabase
              .from('expenses')
              .select(
                  'id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id,type,is_recurring')
              .eq('user_id', userId)
              .isFilter('split_group_id', null)
              .or('is_recurring.is.false,is_recurring.is.null')
              .limit(10000)
              .order('date', ascending: false)
              .timeout(_fallbackQueryTimeout);

          allExpenses = (fallbackResponse as List)
              .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (fallbackError) {
          debugPrint('[Analytics] Fallback fetch also failed: $fallbackError');
          expenseLoadFailed = true;
          allExpenses = [];
        }
      }

      // Fetch ALL budgets without date filtering
      List<DailyBudgetEntry> allBudgets = [];
      try {
        dynamic budgetsResponse;
        if (contactIds.length <= 1) {
          final contactId =
              contactIds.isNotEmpty ? contactIds.first : fetchedContact.id;
          budgetsResponse = await supabase
              .from('daily_budgets')
              .select('id,contact_id,date,amount_cents,currency')
              .eq('contact_id', contactId)
              .limit(10000) // Safety limit
              .order('date', ascending: true);
        } else {
          budgetsResponse = await supabase
              .from('daily_budgets')
              .select('id,contact_id,date,amount_cents,currency')
              .inFilter('contact_id', contactIds)
              .limit(10000) // Safety limit
              .order('date', ascending: true);
        }

        allBudgets = (budgetsResponse as List)
            .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
            .toList();
      } catch (budgetError) {
        // Handle foreign key errors or empty results gracefully
        debugPrint('[Analytics] Error fetching budgets: $budgetError');
        allBudgets = [];
      }

      // Check if this operation is still current (not superseded by a newer load)
      if (_loadOperationId != currentOperationId) {
        debugPrint('[Analytics] Operation $currentOperationId superseded, abandoning');
        return;
      }

      // Check if we should retry due to expense load failure
      if (expenseLoadFailed && retryCount < _maxRetries) {
        debugPrint(
            '[Analytics] Expense load failed, scheduling retry ${retryCount + 1}/$_maxRetries');
        await Future.delayed(_retryDelay);
        // Check again after delay
        if (_loadOperationId != currentOperationId) {
          debugPrint('[Analytics] Operation $currentOperationId superseded during retry delay');
          return;
        }
        // Retry with incremented count
        return loadData(userId, retryCount: retryCount + 1);
      }

      // Final check before updating state
      if (_loadOperationId != currentOperationId) {
        debugPrint('[Analytics] Operation $currentOperationId superseded before state update');
        return;
      }

      // Store ALL data in both allExpenses/allBudgets AND expenses/budgets
      // Filtering will be done locally in the home page
      // Set hasLoadedOnce = true ONLY on successful completion
      state = state.copyWith(
        contact: fetchedContact,
        expenses: allExpenses,
        allExpenses: allExpenses,
        budgets: allBudgets,
        allBudgets: allBudgets,
        preferredCurrency: fetchedContact.preferredCurrency?.toUpperCase(),
        isLoading: false,
        hasLoadedOnce: true, // Mark as loaded AFTER successful data fetch
      );

      debugPrint(
          '✅ Analytics loaded: ${allExpenses.length} expenses, ${allBudgets.length} budgets');
    } catch (e) {
      debugPrint('[Analytics] Error loading data: $e');

      // Check if this operation is still current
      if (_loadOperationId != currentOperationId) {
        debugPrint('[Analytics] Operation $currentOperationId superseded during error handling');
        return;
      }

      // If we haven't exhausted retries, try again
      if (retryCount < _maxRetries) {
        debugPrint(
            '[Analytics] Scheduling retry ${retryCount + 1}/$_maxRetries after error');
        await Future.delayed(_retryDelay);
        // Check again after delay
        if (_loadOperationId != currentOperationId) {
          debugPrint('[Analytics] Operation $currentOperationId superseded during error retry delay');
          return;
        }
        return loadData(userId, retryCount: retryCount + 1);
      }

      // All retries exhausted - set error state but don't set hasLoadedOnce
      // This allows the home page to show retry button
      state = state.copyWith(
        error: 'Failed to load data: $e',
        isLoading: false,
        // Don't set hasLoadedOnce - allow retry from home page
      );
    }
  }

  /// Refresh analytics data - simply reloads all data
  void refresh(String userId) {
    loadData(userId);
  }

  void updatePreferredCurrency(String currency) {
    state = state.copyWith(
      preferredCurrency: currency.toUpperCase(),
      contact:
          state.contact?.copyWith(preferredCurrency: currency.toUpperCase()),
    );
  }

  // Removed setDateRangeFilter - filtering is now done locally in home page
  // This keeps the provider data unfiltered for insights page

  void setBudgetAmount(double amount) {
    final newAmountCents = (amount * 100).round();
    if (newAmountCents <= 0) {
      return;
    }

    final currentBudgets = state.budgets;

    if (currentBudgets.isEmpty) {
      final contactId = state.contact?.id;
      if (contactId == null || contactId.isEmpty) {
        return;
      }

      final newEntry = DailyBudgetEntry(
        id: 'local-budget-${DateTime.now().millisecondsSinceEpoch}',
        contactId: contactId,
        date: DateTime.now(),
        amountCents: newAmountCents,
        currency: state.contact?.preferredCurrency,
      );

      state = state.copyWith(budgets: [newEntry]);
      return;
    }

    final totalCurrentCents =
        currentBudgets.fold<int>(0, (sum, budget) => sum + budget.amountCents);

    List<DailyBudgetEntry> updatedBudgets;
    if (totalCurrentCents <= 0) {
      final perEntryCents = (newAmountCents / currentBudgets.length).round();
      updatedBudgets = currentBudgets
          .map((budget) => budget.copyWith(amountCents: perEntryCents))
          .toList();
    } else {
      final ratio = newAmountCents / totalCurrentCents;
      updatedBudgets = currentBudgets
          .map((budget) => budget.copyWith(
              amountCents: (budget.amountCents * ratio).round()))
          .toList();

      final diff = newAmountCents -
          updatedBudgets.fold<int>(
              0, (sum, budget) => sum + budget.amountCents);

      if (diff != 0 && updatedBudgets.isNotEmpty) {
        final lastBudget = updatedBudgets.last;
        updatedBudgets[updatedBudgets.length - 1] =
            lastBudget.copyWith(amountCents: lastBudget.amountCents + diff);
      }
    }

    state = state.copyWith(budgets: updatedBudgets);
  }

  /// Set budget amount for a specific currency
  void setBudgetAmountForCurrency(String currencyCode, double amount) {
    final code = currencyCode.toUpperCase();
    final newAmountCents = (amount * 100).round();
    if (newAmountCents <= 0) {
      return;
    }

    final currentBudgets = state.budgets;
    final currentBudgetsForCurrency = currentBudgets
        .where((b) => (b.currency ?? '').toUpperCase() == code)
        .toList();

    if (currentBudgetsForCurrency.isEmpty) {
      final contactId = state.contact?.id;
      if (contactId == null || contactId.isEmpty) {
        return;
      }

      final newEntry = DailyBudgetEntry(
        id: 'local-budget-${DateTime.now().millisecondsSinceEpoch}',
        contactId: contactId,
        date: DateTime.now(),
        amountCents: newAmountCents,
        currency: code,
      );

      state = state.copyWith(budgets: [...currentBudgets, newEntry]);
      return;
    }

    final totalCurrentCents = currentBudgetsForCurrency.fold<int>(
        0, (sum, budget) => sum + budget.amountCents);
    List<DailyBudgetEntry> updatedBudgets = List.of(currentBudgets);

    if (totalCurrentCents <= 0) {
      final perEntryCents =
          (newAmountCents / currentBudgetsForCurrency.length).round();
      updatedBudgets = updatedBudgets.map((budget) {
        if ((budget.currency ?? '').toUpperCase() == code) {
          return budget.copyWith(amountCents: perEntryCents);
        }
        return budget;
      }).toList();
    } else {
      final ratio = newAmountCents / totalCurrentCents;
      updatedBudgets = updatedBudgets.map((budget) {
        if ((budget.currency ?? '').toUpperCase() == code) {
          return budget.copyWith(
              amountCents: (budget.amountCents * ratio).round());
        }
        return budget;
      }).toList();

      final diff = newAmountCents -
          updatedBudgets
              .where((b) => (b.currency ?? '').toUpperCase() == code)
              .fold<int>(0, (sum, budget) => sum + budget.amountCents);

      if (diff != 0) {
        for (int i = updatedBudgets.length - 1; i >= 0; i--) {
          final b = updatedBudgets[i];
          if ((b.currency ?? '').toUpperCase() == code) {
            updatedBudgets[i] = b.copyWith(amountCents: b.amountCents + diff);
            break;
          }
        }
      }
    }

    state = state.copyWith(budgets: updatedBudgets);
  }

  /// Clear all user data (on logout)
  void clear() {
    state = AnalyticsData();
  }
}
