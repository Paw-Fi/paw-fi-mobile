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
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _primaryQueryTimeout = Duration(seconds: 10);
  static const Duration _fallbackQueryTimeout = Duration(seconds: 8);

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
          hasLoadedOnce: true, // Mark as loaded so other providers don't wait forever
        );
        debugPrint('[Analytics] Empty userId, setting error state with hasLoadedOnce=true');
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
        // IMPORTANT: Still set hasLoadedOnce = true so other providers know we're done
        state = state.copyWith(
          contact: null,
          expenses: [],
          allExpenses: [],
          budgets: [],
          allBudgets: [],
          preferredCurrency: null,
          isLoading: false,
          hasLoadedOnce: true, // Mark as loaded even with no contact
        );
        debugPrint('[Analytics] No contact found, setting empty state with hasLoadedOnce=true');
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

      // Fetch ALL PERSONAL expenses using direct DB query (faster, more reliable)
      // EXCLUDE recurring transactions and household expenses
      List<ExpenseEntry> allExpenses = [];
      bool expenseLoadFailed = false;
      
      debugPrint('[Analytics] Fetching expenses via direct DB query...');
      try {
        // Primary: Direct DB query - faster and more reliable than edge function
        final response = await supabase
            .from('expenses')
            .select(
                'id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id,type,is_recurring')
            .eq('user_id', userId)
            .isFilter('split_group_id', null) // Personal only
            .or('is_recurring.is.false,is_recurring.is.null') // Exclude recurring
            .limit(5000) // Safety limit
            .order('date', ascending: false)
            .timeout(_primaryQueryTimeout);

        allExpenses = (response as List)
            .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[Analytics] Direct DB query succeeded: ${allExpenses.length} expenses');
      } catch (primaryError) {
        debugPrint('[Analytics] Primary DB query failed: $primaryError');
        
        // Fallback: Try simpler query without filters, then filter in memory
        try {
          debugPrint('[Analytics] Trying fallback query...');
          final fallbackResponse = await supabase
              .from('expenses')
              .select(
                  'id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id,type,is_recurring')
              .eq('user_id', userId)
              .limit(5000)
              .order('date', ascending: false)
              .timeout(_fallbackQueryTimeout);

          // Filter in memory using raw JSON before parsing
          final filteredData = (fallbackResponse as List)
              .where((e) {
                final json = e as Map<String, dynamic>;
                final splitGroupId = json['split_group_id'];
                final isRecurring = json['is_recurring'];
                return splitGroupId == null && (isRecurring == null || isRecurring == false);
              })
              .toList();
          
          allExpenses = filteredData
              .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          debugPrint('[Analytics] Fallback query succeeded: ${allExpenses.length} expenses');
        } catch (fallbackError) {
          debugPrint('[Analytics] Fallback query also failed: $fallbackError');
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

      // All retries exhausted - set error state
      // Set hasLoadedOnce = true so other providers don't wait forever
      // Home page can still show retry button based on error state
      state = state.copyWith(
        error: 'Failed to load data: $e',
        isLoading: false,
        hasLoadedOnce: true, // Mark as "attempted" so other providers don't wait
      );
      debugPrint('[Analytics] All retries exhausted, setting error state with hasLoadedOnce=true');
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
