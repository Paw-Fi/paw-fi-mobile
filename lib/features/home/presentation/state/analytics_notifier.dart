import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';

/// Analytics data provider
class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(AnalyticsData());

  Future<void> loadData(String userId) async {
    // Set hasLoadedOnce immediately to prevent infinite retry loops
    state = state.copyWith(
      isLoading: true, 
      clearError: true,
      hasLoadedOnce: true
    );

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
          .select('id,user_id,phone_e164,verified,preferred_currency,created_at,updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false);
      
      // Debug: Log what we fetched from database (only in debug mode)
      if (kDebugMode) {
        debugPrint('🔍 Analytics: userId = $userId');
        debugPrint('🔍 Analytics: contactsResponse = $contactsResponse');
        debugPrint('🔍 Analytics: contactsResponse length = ${(contactsResponse as List).length}');
      }
      
      final contactsList = (contactsResponse as List).cast<Map<String, dynamic>>();
      final contactResponse = contactsList.isNotEmpty ? contactsList.first : null;
      
      if (kDebugMode) {
        debugPrint('🔍 Analytics: contactResponse = $contactResponse');
        debugPrint('🔍 Analytics: preferred_currency from DB = ${contactResponse?['preferred_currency']}');
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
        debugPrint('🔍 Analytics: fetchedContact.preferredCurrency = ${fetchedContact.preferredCurrency}');
      }

      // Fetch ALL historical data (all time) without date filtering
      // Ensures insights are computed from the complete history

      // Build list of all contact IDs associated with this user
      final contactIds = contactsList
          .map((c) => c['id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      // Fetch ALL PERSONAL expenses (exclude household expenses where split_group_id IS NOT NULL)
      // Aggregate across ALL contact IDs to handle historical rows.
      List<ExpenseEntry> allExpenses = [];
      try {
        dynamic expensesResponse;
        if (contactIds.length <= 1) {
          final contactId = contactIds.isNotEmpty ? contactIds.first : fetchedContact.id;
          expensesResponse = await supabase
              .from('expenses')
              .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id')
              .isFilter('split_group_id', null)
              .eq('contact_id', contactId)
              .order('date', ascending: true);
        } else {
          expensesResponse = await supabase
              .from('expenses')
              .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id')
              .isFilter('split_group_id', null)
              .inFilter('contact_id', contactIds)
              .order('date', ascending: true);
        }

        allExpenses = (expensesResponse as List)
            .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (expenseError) {
        // Handle errors gracefully and attempt a fallback using user_id if available
        debugPrint('[Analytics] Error fetching expenses by contact_id: $expenseError');
        try {
          final fallbackResponse = await supabase
              .from('expenses')
              .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url,household_id,split_group_id')
              .eq('user_id', userId)
              .isFilter('split_group_id', null)
              .order('date', ascending: true);
          allExpenses = (fallbackResponse as List)
              .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (fallbackError) {
          debugPrint('[Analytics] Fallback fetch by user_id failed: $fallbackError');
          allExpenses = [];
        }
      }

      // Fetch ALL budgets (unfiltered) aggregated across all contact IDs
      List<DailyBudgetEntry> allBudgets = [];
      try {
        dynamic budgetsResponse;
        if (contactIds.length <= 1) {
          final contactId = contactIds.isNotEmpty ? contactIds.first : fetchedContact.id;
          budgetsResponse = await supabase
              .from('daily_budgets')
              .select('id,contact_id,date,amount_cents,currency')
              .eq('contact_id', contactId)
              .order('date', ascending: true);
        } else {
          budgetsResponse = await supabase
              .from('daily_budgets')
              .select('id,contact_id,date,amount_cents,currency')
              .inFilter('contact_id', contactIds)
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
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load data: $e',
        isLoading: false,
      );
    }
  }

  void refresh(String userId) {
    loadData(userId);
  }

  void updatePreferredCurrency(String currency) {
    state = state.copyWith(
      preferredCurrency: currency.toUpperCase(),
      contact: state.contact?.copyWith(preferredCurrency: currency.toUpperCase()),
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

    final totalCurrentCents = currentBudgets.fold<int>(0, (sum, budget) => sum + budget.amountCents);

    List<DailyBudgetEntry> updatedBudgets;
    if (totalCurrentCents <= 0) {
      final perEntryCents = (newAmountCents / currentBudgets.length).round();
      updatedBudgets = currentBudgets
          .map((budget) => budget.copyWith(amountCents: perEntryCents))
          .toList();
    } else {
      final ratio = newAmountCents / totalCurrentCents;
      updatedBudgets = currentBudgets
          .map((budget) => budget.copyWith(amountCents: (budget.amountCents * ratio).round()))
          .toList();

      final diff = newAmountCents -
          updatedBudgets.fold<int>(0, (sum, budget) => sum + budget.amountCents);

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
    final currentBudgetsForCurrency = currentBudgets.where((b) => (b.currency ?? '').toUpperCase() == code).toList();

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

    final totalCurrentCents = currentBudgetsForCurrency.fold<int>(0, (sum, budget) => sum + budget.amountCents);
    List<DailyBudgetEntry> updatedBudgets = List.of(currentBudgets);

    if (totalCurrentCents <= 0) {
      final perEntryCents = (newAmountCents / currentBudgetsForCurrency.length).round();
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
          return budget.copyWith(amountCents: (budget.amountCents * ratio).round());
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
