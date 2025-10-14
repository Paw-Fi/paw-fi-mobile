import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
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

      print(contactResponse);

      if (contactResponse == null) {
        state = state.copyWith(
          contact: null,
          preferredCurrency: null,
          isLoading: false,
        );
        return;
      }

      final fetchedContact = UserContact.fromJson(contactResponse);

      // Calculate date range based on filter
      final dateRange = _getDateRange(state.dateRangeFilter, state.customStartDate, state.customEndDate);
      final from = dateRange['from']!;
      final to = dateRange['to']!;

      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr = '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

      // Fetch expenses
      final expensesResponse = await supabase
          .from('expenses')
          .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      // Fetch budgets
      final budgetsResponse = await supabase
          .from('daily_budgets')
          .select('id,contact_id,date,amount_cents,currency')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      state = state.copyWith(
        contact: fetchedContact,
        expenses: (expensesResponse as List)
            .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        budgets: (budgetsResponse as List)
            .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
            .toList(),
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

  void setDateRangeFilter(DateRangeFilter filter, String userId, {DateTime? startDate, DateTime? endDate}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: startDate,
      customEndDate: endDate,
      updateDateRange: true,
    );
    loadData(userId);
  }

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

  Map<String, DateTime> _getDateRange(DateRangeFilter filter, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case DateRangeFilter.today:
        return {'from': today, 'to': today};

      case DateRangeFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return {'from': yesterday, 'to': yesterday};

      case DateRangeFilter.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return {'from': weekStart, 'to': today};

      case DateRangeFilter.lastWeek:
        final lastWeekEnd = today.subtract(Duration(days: today.weekday));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        return {'from': lastWeekStart, 'to': lastWeekEnd};

      case DateRangeFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return {'from': monthStart, 'to': today};

      case DateRangeFilter.last30Days:
        final from = today.subtract(const Duration(days: 29));
        return {'from': from, 'to': today};

      case DateRangeFilter.custom:
        if (customStart != null && customEnd != null) {
          return {'from': customStart, 'to': customEnd};
        }
        // Fallback to last 30 days if custom dates not set
        final from = today.subtract(const Duration(days: 29));
        return {'from': from, 'to': today};
    }
  }

  /// Clear all user data (on logout)
  void clear() {
    state = AnalyticsData();
  }
}
