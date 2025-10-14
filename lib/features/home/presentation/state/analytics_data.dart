import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Analytics data state
class AnalyticsData {
  final UserContact? contact;
  final List<ExpenseEntry> expenses;
  final List<ExpenseEntry> allExpenses;
  final List<DailyBudgetEntry> budgets;
  final List<DailyBudgetEntry> allBudgets;
  final bool isLoading;
  final String? error;
  final String? preferredCurrency;
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool updateDateRange;

  AnalyticsData({
    this.contact,
    this.expenses = const [],
    this.allExpenses = const [],
    this.budgets = const [],
    this.allBudgets = const [],
    this.isLoading = true,
    this.error,
    this.preferredCurrency,
    this.dateRangeFilter = DateRangeFilter.today,
    this.customStartDate,
    this.customEndDate,
    this.updateDateRange = false,
  });

  AnalyticsData copyWith({
    UserContact? contact,
    List<ExpenseEntry>? expenses,
    List<ExpenseEntry>? allExpenses,
    List<DailyBudgetEntry>? budgets,
    List<DailyBudgetEntry>? allBudgets,
    bool? isLoading,
    String? error,
    String? preferredCurrency,
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearError = false,
    bool updateDateRange = false,
  }) {
    return AnalyticsData(
      contact: contact ?? this.contact,
      expenses: expenses ?? this.expenses,
      allExpenses: allExpenses ?? this.allExpenses,
      budgets: budgets ?? this.budgets,
      allBudgets: allBudgets ?? this.allBudgets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      dateRangeFilter: updateDateRange && dateRangeFilter != null ? dateRangeFilter : this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      updateDateRange: updateDateRange,
    );
  }
}
