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
    if (expense.isRecurring) return false;
    final householdId = expense.householdId;
    switch (scope.activeAccountType) {
      case ActiveWalletType.personal:
        return householdId == null || householdId.isEmpty;
      case ActiveWalletType.portfolio:
        final activeId = scope.activeAccountHouseholdId;
        return activeId != null && householdId == activeId;
      case ActiveWalletType.household:
        final selectedId = scope.selectedHouseholdId;
        return selectedId != null && householdId == selectedId;
    }
  }).toList(growable: false);

  final filteredBudgets = scope.activeAccountType == ActiveWalletType.personal
      ? analyticsData.allBudgets.toList(growable: false)
      : const <DailyBudgetEntry>[];

  return InsightsScopedData(
    expenses: filteredExpenses,
    budgets: filteredBudgets,
  );
}
