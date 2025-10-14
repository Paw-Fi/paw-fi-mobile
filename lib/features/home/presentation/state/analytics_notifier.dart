import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';

/// Analytics data provider
class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(AnalyticsData());

  Future<void> loadData(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (userId.isEmpty) {
        state = state.copyWith(
          error: 'Please log in to view analytics',
          isLoading: false,
        );
        return;
      }

      // Fetch user contact
      final contactResponse = await supabase
          .from('user_contacts')
          .select('id,user_id,phone_e164,verified,preferred_currency')
          .eq('user_id', userId)
          .maybeSingle();

      if (contactResponse == null) {
        state = state.copyWith(
          contact: null,
          preferredCurrency: null,
          isLoading: false,
        );
        return;
      }

      final fetchedContact = UserContact.fromJson(contactResponse);

      // Always fetch ALL data (last 365 days) without date filtering
      // This ensures insights page always has full data
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final oneYearAgo = today.subtract(const Duration(days: 365));

      final fromStr = '${oneYearAgo.year}-${oneYearAgo.month.toString().padLeft(2, '0')}-${oneYearAgo.day.toString().padLeft(2, '0')}';
      final toStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Fetch ALL expenses (unfiltered)
      final expensesResponse = await supabase
          .from('expenses')
          .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      // Fetch ALL budgets (unfiltered)
      final budgetsResponse = await supabase
          .from('daily_budgets')
          .select('id,contact_id,date,amount_cents,currency')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      final allExpenses = (expensesResponse as List)
          .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      
      final allBudgets = (budgetsResponse as List)
          .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
          .toList();

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

  /// Clear all user data (on logout)
  void clear() {
    state = AnalyticsData();
  }
}
