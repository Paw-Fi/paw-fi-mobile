import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Analytics data state
class AnalyticsData {
  final UserContact? contact;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
  final bool isLoading;
  final String? error;
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  AnalyticsData({
    this.contact,
    this.expenses = const [],
    this.budgets = const [],
    this.isLoading = true,
    this.error,
    this.dateRangeFilter = DateRangeFilter.last30Days,
    this.customStartDate,
    this.customEndDate,
  });

  AnalyticsData copyWith({
    UserContact? contact,
    List<ExpenseEntry>? expenses,
    List<DailyBudgetEntry>? budgets,
    bool? isLoading,
    String? error,
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearError = false,
    bool updateDateRange = false,
  }) {
    return AnalyticsData(
      contact: contact ?? this.contact,
      expenses: expenses ?? this.expenses,
      budgets: budgets ?? this.budgets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      dateRangeFilter: updateDateRange && dateRangeFilter != null ? dateRangeFilter : this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }
}
