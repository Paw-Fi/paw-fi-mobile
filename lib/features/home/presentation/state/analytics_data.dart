import 'package:moneko/features/home/presentation/models/models.dart';

/// Analytics data state - stores ALL unfiltered data
/// Filtering is done locally in home page, keeping insights page data intact
class AnalyticsData {
  final UserContact? contact;
  final List<ExpenseEntry> expenses;
  final List<ExpenseEntry> allExpenses;
  final List<DailyBudgetEntry> budgets;
  final List<DailyBudgetEntry> allBudgets;
  final bool isLoading;
  final String? error;
  final String? preferredCurrency;

  AnalyticsData({
    this.contact,
    this.expenses = const [],
    this.allExpenses = const [],
    this.budgets = const [],
    this.allBudgets = const [],
    this.isLoading = true,
    this.error,
    this.preferredCurrency,
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
    bool clearError = false,
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
    );
  }
}
