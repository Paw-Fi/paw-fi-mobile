import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';

/// Analytics data provider with robust error handling and retry logic.
/// 
/// Uses a server-side RPC function for optimal performance (single round-trip),
/// with fallback to client-side batched queries if RPC is unavailable.
class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(AnalyticsData());

  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  // RPC timeout - should complete quickly with small dataset
  static const Duration _rpcTimeout = Duration(seconds: 15);
  // Fallback batched query timeouts (only used if RPC fails)
  static const Duration _primaryQueryTimeout = Duration(seconds: 10);
  static const Duration _fallbackQueryTimeout = Duration(seconds: 15);
  static const Duration _warmupTimeout = Duration(seconds: 10);
  // Overall timeout for entire fallback process
  static const Duration _fallbackProcessTimeout = Duration(seconds: 20);
  static const int _primaryExpenseBatchSize = 1000;
  static const int _fallbackExpenseBatchSize = 400;
  static const int _maxExpenseBatches = 30;
  static const Duration _batchYieldDelay = Duration(milliseconds: 20);
  
  /// Track if connection has been warmed up this session (only for fallback)
  bool _connectionWarmedUp = false;

  /// Track current load operation to prevent race conditions
  int _loadOperationId = 0;

  /// Load all analytics data for a user.
  /// Always fetches ALL transactions (no date filtering) - local filtering is done in UI.
  /// 
  /// Uses RPC function for optimal performance (single round-trip), with automatic
  /// fallback to batched queries if RPC is unavailable.
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

      // Try RPC first (faster, more reliable, single round-trip)
      bool rpcSucceeded = false;
      UserContact? fetchedContact;
      List<ExpenseEntry> allExpenses = [];
      List<DailyBudgetEntry> allBudgets = [];

      try {
        debugPrint('[Analytics] Fetching via RPC (get_user_analytics)...');
        final stopwatch = Stopwatch()..start();
        
        final rpcResponse = await supabase
            .rpc('get_user_analytics', params: {'p_user_id': userId})
            .timeout(_rpcTimeout);
        
        stopwatch.stop();
        debugPrint('[Analytics] RPC completed in ${stopwatch.elapsedMilliseconds}ms');

        if (rpcResponse != null) {
          final data = rpcResponse as Map<String, dynamic>;
          
          // Parse contact
          final contactData = data['contact'] as Map<String, dynamic>?;
          if (contactData != null) {
            fetchedContact = UserContact.fromJson(contactData);
          }
          
          // Parse expenses
          final expensesData = data['expenses'] as List<dynamic>?;
          if (expensesData != null) {
            allExpenses = expensesData
                .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          
          // Parse budgets
          final budgetsData = data['budgets'] as List<dynamic>?;
          if (budgetsData != null) {
            allBudgets = budgetsData
                .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
                .toList();
          }
          
          rpcSucceeded = true;
          debugPrint('[Analytics] RPC succeeded: ${allExpenses.length} expenses, ${allBudgets.length} budgets');
        }
      } catch (rpcError) {
        debugPrint('[Analytics] RPC failed (will fallback to batched queries): $rpcError');
        // RPC might not be deployed yet - fall back to batched queries
      }

      // Fallback to batched queries if RPC failed
      if (!rpcSucceeded) {
        debugPrint('[Analytics] Using fallback batched queries...');
        final fallbackStopwatch = Stopwatch()..start();
        
        try {
          final fallbackResult = await _loadDataWithBatchedQueries(userId, currentOperationId)
              .timeout(_fallbackProcessTimeout);
          
          if (fallbackResult == null) {
            // Operation was superseded or failed
            debugPrint('[Analytics] Fallback returned null - operation superseded or failed');
            return;
          }
          
          fallbackStopwatch.stop();
          debugPrint('[Analytics] Fallback completed in ${fallbackStopwatch.elapsedMilliseconds}ms');
          
          fetchedContact = fallbackResult.contact;
          allExpenses = fallbackResult.expenses;
          allBudgets = fallbackResult.budgets;
        } on TimeoutException {
          fallbackStopwatch.stop();
          debugPrint('[Analytics] ❌ CRITICAL: Fallback timed out after ${_fallbackProcessTimeout.inSeconds}s!');
          debugPrint('[Analytics] This suggests serious database or network issues');
          // Continue with empty data rather than hanging forever
          fetchedContact = null;
          allExpenses = [];
          allBudgets = [];
        } catch (e) {
          fallbackStopwatch.stop();
          debugPrint('[Analytics] ❌ Fallback failed with error: $e');
          fetchedContact = null;
          allExpenses = [];
          allBudgets = [];
        }
      }

      // Handle no contact case
      if (fetchedContact == null) {
        state = state.copyWith(
          contact: null,
          expenses: [],
          allExpenses: [],
          budgets: [],
          allBudgets: [],
          preferredCurrency: null,
          isLoading: false,
          hasLoadedOnce: true,
        );
        debugPrint('[Analytics] No contact found, setting empty state with hasLoadedOnce=true');
        return;
      }

      // Check if this operation is still current
      if (_loadOperationId != currentOperationId) {
        debugPrint('[Analytics] Operation $currentOperationId superseded before state update');
        return;
      }

      // Store ALL data in both allExpenses/allBudgets AND expenses/budgets
      // Filtering will be done locally in the home page
      state = state.copyWith(
        contact: fetchedContact,
        expenses: allExpenses,
        allExpenses: allExpenses,
        budgets: allBudgets,
        allBudgets: allBudgets,
        preferredCurrency: fetchedContact.preferredCurrency?.toUpperCase(),
        isLoading: false,
        hasLoadedOnce: true,
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

      // If we haven't exhausted retries, try again with exponential backoff
      if (retryCount < _maxRetries) {
        final backoffDelay = _baseRetryDelay * (1 << retryCount);
        debugPrint(
            '[Analytics] Scheduling retry ${retryCount + 1}/$_maxRetries after ${backoffDelay.inSeconds}s');
        await Future.delayed(backoffDelay);
        if (_loadOperationId != currentOperationId) {
          debugPrint('[Analytics] Operation $currentOperationId superseded during error retry delay');
          return;
        }
        return loadData(userId, retryCount: retryCount + 1);
      }

      // All retries exhausted - set error state
      state = state.copyWith(
        error: 'Failed to load data: $e',
        isLoading: false,
        hasLoadedOnce: true,
      );
      debugPrint('[Analytics] All retries exhausted, setting error state with hasLoadedOnce=true');
    }
  }

  /// Fallback method using batched queries (used when RPC is unavailable)
  Future<_BatchedQueryResult?> _loadDataWithBatchedQueries(
    String userId,
    int currentOperationId,
  ) async {
    debugPrint('[Analytics] [FALLBACK] Starting batched query process...');
    
    // Fetch contacts with timeout
    debugPrint('[Analytics] [FALLBACK] Fetching user contacts...');
    final contactStopwatch = Stopwatch()..start();
    
    final contactsResponse = await supabase
        .from('user_contacts')
        .select(
            'id,user_id,phone_e164,verified,preferred_currency,preferred_timezone,created_at,updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 5));
    
    contactStopwatch.stop();
    debugPrint('[Analytics] [FALLBACK] Contacts fetched in ${contactStopwatch.elapsedMilliseconds}ms');

    final contactsList =
        (contactsResponse as List).cast<Map<String, dynamic>>();
    final contactResponse =
        contactsList.isNotEmpty ? contactsList.first : null;

    if (contactResponse == null) {
      return _BatchedQueryResult(contact: null, expenses: [], budgets: []);
    }

    final fetchedContact = UserContact.fromJson(contactResponse);

    // Warm up connection if needed
    if (!_connectionWarmedUp) {
      await _warmupConnection(userId);
    }

    // Build contact IDs list
    final contactIds = contactsList
        .map((c) => c['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    // Fetch expenses
    List<ExpenseEntry> allExpenses = [];
    try {
      debugPrint('[Analytics] Fetching expenses via batched DB query...');
      final rawExpenses = await _fetchExpensesInBatches(
        userId: userId,
        contactIds: contactIds,
        applyPersonalFiltersInQuery: true,
        batchSize: _primaryExpenseBatchSize,
        perBatchTimeout: _primaryQueryTimeout,
      );
      allExpenses = rawExpenses.map(ExpenseEntry.fromJson).toList();
      debugPrint('[Analytics] Batched DB query succeeded: ${allExpenses.length} expenses');
    } catch (primaryError) {
      debugPrint('[Analytics] Primary DB query failed: $primaryError');
      try {
        debugPrint('[Analytics] Trying fallback batched query...');
        final fallbackRaw = await _fetchExpensesInBatches(
          userId: userId,
          contactIds: contactIds,
          applyPersonalFiltersInQuery: false,
          batchSize: _fallbackExpenseBatchSize,
          perBatchTimeout: _fallbackQueryTimeout,
        );
        final filteredData = fallbackRaw.where((json) {
          final splitGroupId = json['split_group_id'];
          final isRecurring = json['is_recurring'];
          return splitGroupId == null && (isRecurring == null || isRecurring == false);
        }).toList();
        allExpenses = filteredData.map(ExpenseEntry.fromJson).toList();
        debugPrint('[Analytics] Fallback batched query succeeded: ${allExpenses.length} expenses');
      } catch (fallbackError) {
        debugPrint('[Analytics] Fallback query also failed: $fallbackError');
        allExpenses = [];
      }
    }

    // Fetch budgets with timeout
    debugPrint('[Analytics] [FALLBACK] Fetching budgets...');
    final budgetStopwatch = Stopwatch()..start();
    List<DailyBudgetEntry> allBudgets = [];
    try {
      dynamic budgetsResponse;
      if (contactIds.length <= 1) {
        final contactId = contactIds.isNotEmpty ? contactIds.first : fetchedContact.id;
        budgetsResponse = await supabase
            .from('daily_budgets')
            .select('id,contact_id,date,amount_cents,currency')
            .eq('contact_id', contactId)
            .limit(10000)
            .order('date', ascending: true)
            .timeout(const Duration(seconds: 5));
      } else {
        budgetsResponse = await supabase
            .from('daily_budgets')
            .select('id,contact_id,date,amount_cents,currency')
            .inFilter('contact_id', contactIds)
            .limit(10000)
            .order('date', ascending: true)
            .timeout(const Duration(seconds: 5));
      }
      allBudgets = (budgetsResponse as List)
          .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
          .toList();
      
      budgetStopwatch.stop();
      debugPrint('[Analytics] [FALLBACK] Budgets fetched in ${budgetStopwatch.elapsedMilliseconds}ms');
    } catch (budgetError) {
      budgetStopwatch.stop();
      debugPrint('[Analytics] [FALLBACK] Error fetching budgets: $budgetError');
      allBudgets = [];
    }

    // Check if operation is still current
    if (_loadOperationId != currentOperationId) {
      debugPrint('[Analytics] Operation $currentOperationId superseded during batched queries');
      return null;
    }

    return _BatchedQueryResult(
      contact: fetchedContact,
      expenses: allExpenses,
      budgets: allBudgets,
    );
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
    _connectionWarmedUp = false; // Reset warmup flag on logout
  }

  /// Warm up the Supabase connection before making expensive queries.
  /// This helps avoid cold-start timeouts by establishing the connection pool.
  /// 
  /// IMPORTANT: We warm up BOTH user_contacts AND expenses tables because
  /// each table may use different connection paths. The main expense query
  /// was timing out on cold start because only user_contacts was warmed up.
  Future<void> _warmupConnection(String userId) async {
    try {
      debugPrint('[Analytics] Warming up Supabase connection...');
      final stopwatch = Stopwatch()..start();
      
      // Warmup both tables in parallel - this establishes connection paths
      // for both tables and primes the query planner
      await Future.wait([
        // Warmup 1: user_contacts table
        supabase
            .from('user_contacts')
            .select('id')
            .eq('user_id', userId)
            .limit(1)
            .timeout(_warmupTimeout),
        // Warmup 2: expenses table - critical for the main batch query
        // This primes the connection path that was causing cold-start timeouts
        supabase
            .from('expenses')
            .select('id')
            .eq('user_id', userId)
            .limit(1)
            .timeout(_warmupTimeout),
      ]);
      
      // Small delay to let connection pool fully stabilize
      // This helps prevent race conditions on the first real query
      await Future.delayed(const Duration(milliseconds: 50));
      
      stopwatch.stop();
      _connectionWarmedUp = true;
      debugPrint('[Analytics] Connection warmed up in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      // If warmup fails, we'll still try the main query
      // The increased timeouts should handle it
      debugPrint('[Analytics] Connection warmup failed (non-critical): $e');
      _connectionWarmedUp = true; // Mark as attempted to avoid repeated warmup failures
    }
  }

  Future<List<Map<String, dynamic>>> _fetchExpensesInBatches({
    required String userId,
    required List<String> contactIds,
    required bool applyPersonalFiltersInQuery,
    required int batchSize,
    required Duration perBatchTimeout,
  }) async {
    final results = <Map<String, dynamic>>[];
    int offset = 0;
    int batchNumber = 0;
    final stopwatch = Stopwatch()..start();

    while (true) {
      if (batchNumber >= _maxExpenseBatches) {
        debugPrint(
            '[Analytics] Max expense batches ($_maxExpenseBatches) reached while fetching expenses');
        break;
      }

      final batch = await _fetchExpenseBatch(
        userId: userId,
        contactIds: contactIds,
        applyPersonalFiltersInQuery: applyPersonalFiltersInQuery,
        from: offset,
        to: offset + batchSize - 1,
        timeout: perBatchTimeout,
      );

      results.addAll(batch);
      batchNumber += 1;

      if (batch.length < batchSize) {
        break; // Finished fetching all pages
      }

      offset += batchSize;
      // Give the event loop a moment to breathe before the next network call
      await Future.delayed(_batchYieldDelay);
    }

    stopwatch.stop();
    debugPrint(
        '[Analytics] Batched fetch completed in ${stopwatch.elapsedMilliseconds}ms across $batchNumber batches');
    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchExpenseBatch({
    required String userId,
    required List<String> contactIds,
    required bool applyPersonalFiltersInQuery,
    required int from,
    required int to,
    required Duration timeout,
  }) async {
    var query = supabase
        .from('expenses')
        .select(
            'id,contact_id,user_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id,type,is_recurring');

    if (contactIds.isNotEmpty) {
      query = query.inFilter('contact_id', contactIds);
    } else {
      query = query.eq('user_id', userId);
    }

    if (applyPersonalFiltersInQuery) {
      query = query
          .isFilter('split_group_id', null)
          .or('is_recurring.is.false,is_recurring.is.null');
    }

    final orderedQuery = query.order('date', ascending: false);

    final response = await orderedQuery.range(from, to).timeout(timeout);
    return (response as List).cast<Map<String, dynamic>>();
  }
}

/// Internal result type for batched query fallback
class _BatchedQueryResult {
  final UserContact? contact;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;

  _BatchedQueryResult({
    required this.contact,
    required this.expenses,
    required this.budgets,
  });
}
