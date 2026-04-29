import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

class WidgetFinancialSummary {
  const WidgetFinancialSummary({
    required this.totalSpent,
    required this.totalBudget,
    required this.remainingBudget,
    required this.progress,
  });

  final double totalSpent;
  final double totalBudget;
  final double remainingBudget;
  final double progress;
}

bool isWidgetSpendExpense(ExpenseEntry entry) {
  return (entry.type ?? 'expense').toLowerCase() != 'income';
}

List<String?> widgetSourceHouseholdIds({
  required String scopeId,
  required Set<String> portfolioHouseholdIds,
}) {
  if (scopeId == 'personal') {
    return const <String?>[null];
  }
  return <String?>[scopeId];
}

int widgetSpentCents(ExpenseEntry entry) {
  if (!isWidgetSpendExpense(entry)) return 0;
  return entry.amountCents.abs();
}

int calculateWidgetSpentCents(Iterable<ExpenseEntry> entries) {
  return entries.fold<int>(
    0,
    (sum, entry) => sum + widgetSpentCents(entry),
  );
}

Map<String, int> calculateWidgetCategorySpentCents(
  Iterable<ExpenseEntry> entries,
) {
  final totals = <String, int>{};
  for (final entry in entries) {
    final spentCents = widgetSpentCents(entry);
    if (spentCents <= 0) continue;

    final category = entry.category ?? 'uncategorized';
    totals[category] = (totals[category] ?? 0) + spentCents;
  }
  return totals;
}

double widgetCentsToAmount(int cents) => cents / 100.0;

Map<String, DateTime> buildWidgetThisMonthRange(DateTime referenceNow) {
  final today = DateTime(
    referenceNow.year,
    referenceNow.month,
    referenceNow.day,
  );
  return {
    'from': DateTime(referenceNow.year, referenceNow.month, 1),
    'to': today,
  };
}

WidgetFinancialSummary buildWidgetSummaryFromSpentAndBudget({
  required double totalSpent,
  required double totalBudget,
}) {
  final remainingBudget = totalBudget - totalSpent;
  final progress =
      totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

  return WidgetFinancialSummary(
    totalSpent: totalSpent,
    totalBudget: totalBudget,
    remainingBudget: remainingBudget,
    progress: progress,
  );
}

WidgetFinancialSummary buildHouseholdWidgetSummary({
  required double totalSpent,
  required Iterable<BudgetStatus> budgets,
}) {
  var totalBudgetCents = 0;
  var totalBudgetSpentCents = 0;
  var totalBudgetRemainingCents = 0;

  for (final budget in budgets) {
    totalBudgetCents += budget.amountCents;
    totalBudgetSpentCents += budget.spentCents;
    totalBudgetRemainingCents += budget.remainingCents;
  }

  final totalBudget = widgetCentsToAmount(totalBudgetCents);
  final remainingBudget = widgetCentsToAmount(totalBudgetRemainingCents);
  final progress = totalBudgetCents > 0
      ? (totalBudgetSpentCents / totalBudgetCents).clamp(0.0, 1.0)
      : 0.0;

  return WidgetFinancialSummary(
    totalSpent: totalSpent,
    totalBudget: totalBudget,
    remainingBudget: remainingBudget,
    progress: progress,
  );
}
