import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

class InsightsScopedData {
  const InsightsScopedData({
    required this.expenses,
    required this.budgets,
  });

  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
}

InsightsScopedData buildInsightsScopedData(
  AnalyticsData analyticsData,
  HouseholdScope scope,
) {
  final filteredExpenses = analyticsData.allExpenses.where((expense) {
    final householdId = expense.householdId;
    switch (scope.activeAccountType) {
      case ActiveAccountType.personal:
        return householdId == null || householdId.isEmpty;
      case ActiveAccountType.portfolio:
        final activeId = scope.activeAccountHouseholdId;
        return activeId != null && householdId == activeId;
      case ActiveAccountType.household:
        final selectedId = scope.selectedHouseholdId;
        return selectedId != null && householdId == selectedId;
    }
  }).toList(growable: false);

  final filteredBudgets = scope.activeAccountType == ActiveAccountType.personal
      ? analyticsData.allBudgets.toList(growable: false)
      : const <DailyBudgetEntry>[];

  return InsightsScopedData(
    expenses: filteredExpenses,
    budgets: filteredBudgets,
  );
}
