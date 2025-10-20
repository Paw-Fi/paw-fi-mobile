import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

/// Local filter state for home page only
/// This doesn't affect the analytics provider data
class HomeFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedCurrency; // null = "All Currencies"

  HomeFilterState({
    this.dateRangeFilter = DateRangeFilter.last30Days,
    this.customStartDate,
    this.customEndDate,
    this.selectedCurrency,
  });

  HomeFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? selectedCurrency,
    bool clearCurrency = false,
  }) {
    return HomeFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedCurrency: clearCurrency ? null : (selectedCurrency ?? this.selectedCurrency),
    );
  }
}

/// Notifier for home page filter
class HomeFilterNotifier extends StateNotifier<HomeFilterState> {
  HomeFilterNotifier() : super(HomeFilterState());

  void setFilter(DateRangeFilter filter, {DateTime? startDate, DateTime? endDate}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: startDate,
      customEndDate: endDate,
    );
  }

  void setSelectedCurrency(String? currency) {
    state = state.copyWith(
      selectedCurrency: currency,
      clearCurrency: currency == null,
    );
  }
}

/// Provider for home page filter state (local to home page)
final homeFilterProvider = StateNotifierProvider<HomeFilterNotifier, HomeFilterState>((ref) {
  return HomeFilterNotifier();
});

/// Helper function to calculate date range from filter
Map<String, DateTime> getDateRangeFromFilter(
  DateRangeFilter filter,
  DateTime? customStart,
  DateTime? customEnd,
) {
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

/// Filtered expenses for home page based on local filter (date + currency)
final homeFilteredExpensesProvider = Provider<List<ExpenseEntry>>((ref) {
  final analyticsData = ref.watch(analyticsProvider);
  final filterState = ref.watch(homeFilterProvider);

  // Get all expenses from provider
  final allExpenses = analyticsData.allExpenses;

  // Calculate date range from local filter
  final dateRange = getDateRangeFromFilter(
    filterState.dateRangeFilter,
    filterState.customStartDate,
    filterState.customEndDate,
  );

  final from = dateRange['from']!;
  final to = dateRange['to']!;
  final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

  // Filter expenses locally by date AND currency
  return allExpenses.where((expense) {
    final expenseDate = DateTime(
      expense.date.year,
      expense.date.month,
      expense.date.day,
    );
    // Simplified date range check (inclusive boundaries)
    final dateOk = !expenseDate.isBefore(from) && !expenseDate.isAfter(to);
    final currencyOk = selectedCurrency == null || (expense.currency?.toUpperCase() == selectedCurrency);
    return dateOk && currencyOk;
  }).toList();
});

/// Filtered budgets for home page based on local filter (date + currency)
/// Uses most recent budget as fallback if no budget exists for the filtered date range
final homeFilteredBudgetsProvider = Provider<List<DailyBudgetEntry>>((ref) {
  final analyticsData = ref.watch(analyticsProvider);
  final filterState = ref.watch(homeFilterProvider);

  // Get all budgets from provider (sorted by date ascending)
  final allBudgets = analyticsData.allBudgets;

  // If no budgets at all, return empty
  if (allBudgets.isEmpty) {
    return [];
  }

  // Calculate date range from local filter
  final dateRange = getDateRangeFromFilter(
    filterState.dateRangeFilter,
    filterState.customStartDate,
    filterState.customEndDate,
  );

  final from = dateRange['from']!;
  final to = dateRange['to']!;
  final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

  // Filter budgets in the date range AND currency
  final budgetsInRange = allBudgets.where((budget) {
    final budgetDate = DateTime(
      budget.date.year,
      budget.date.month,
      budget.date.day,
    );
    // Simplified date range check (inclusive boundaries)
    final dateOk = !budgetDate.isBefore(from) && !budgetDate.isAfter(to);
    final currencyOk = selectedCurrency == null || (budget.currency?.toUpperCase() == selectedCurrency);
    return dateOk && currencyOk;
  }).toList();

  // If we have budgets in the range, return them
  if (budgetsInRange.isNotEmpty) {
    return budgetsInRange;
  }

  // No budgets in range - find the most recent budget before the range start date (matching currency)
  DailyBudgetEntry? mostRecentBudget;
  for (final budget in allBudgets.reversed) {
    final budgetDate = DateTime(
      budget.date.year,
      budget.date.month,
      budget.date.day,
    );
    final currencyOk = selectedCurrency == null || (budget.currency?.toUpperCase() == selectedCurrency);
    if (currencyOk && budgetDate.isBefore(from)) {
      mostRecentBudget = budget;
      break;
    }
  }

  // If we found a recent budget, use it as the default for the entire range
  if (mostRecentBudget != null) {
    // Return a single entry representing the most recent budget
    // The UI will display this as the budget for the period
    return [mostRecentBudget];
  }

  // No budgets at all before this date range - return empty
  return [];
});

/// Unique list of currencies present in expenses/budgets (uppercased)
final availableCurrenciesProvider = Provider<List<String>>((ref) {
  final data = ref.watch(analyticsProvider);
  final set = <String>{};
  
  for (final e in data.allExpenses) {
    final c = e.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  
  for (final b in data.allBudgets) {
    final c = b.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  
  final list = set.toList()..sort();
  return list;
});

/// Per-currency summaries for the current date range
final currencySummariesProvider = Provider<List<CurrencySummary>>((ref) {
  final data = ref.watch(analyticsProvider);
  final filter = ref.watch(homeFilterProvider);
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );
  final from = range['from']!;
  final to = range['to']!;

  final byCurExpenses = <String, double>{};
  final byCurBudgets = <String, double>{};
  final byCurCount = <String, int>{};

  // Group expenses by currency
  for (final e in data.allExpenses) {
    final c = (e.currency ?? '').toUpperCase();
    if (c.isEmpty) continue;
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    if (d.isBefore(from) || d.isAfter(to)) continue;
    byCurExpenses[c] = (byCurExpenses[c] ?? 0) + e.amount;
    byCurCount[c] = (byCurCount[c] ?? 0) + 1;
  }

  // Group budgets by currency
  for (final b in data.allBudgets) {
    final c = (b.currency ?? '').toUpperCase();
    if (c.isEmpty) continue;
    final d = DateTime(b.date.year, b.date.month, b.date.day);
    if (d.isBefore(from) || d.isAfter(to)) continue;
    byCurBudgets[c] = (byCurBudgets[c] ?? 0) + b.amount;
  }

  // Create summaries
  final codes = {...byCurExpenses.keys, ...byCurBudgets.keys}.toList()..sort();
  return codes
      .map((code) => CurrencySummary(
            currencyCode: code,
            totalExpenses: byCurExpenses[code] ?? 0,
            totalBudget: byCurBudgets[code] ?? 0,
            transactionCount: byCurCount[code] ?? 0,
          ))
      .toList();
});
