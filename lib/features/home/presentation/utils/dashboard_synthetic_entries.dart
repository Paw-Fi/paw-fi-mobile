import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

ExpenseEntry buildSyntheticDashboardExpenseEntry({
  required String id,
  required DateTime date,
  required int amountCents,
  required String currency,
  required String category,
  String? householdId,
  String type = 'expense',
}) {
  final normalizedDate = DateTime(date.year, date.month, date.day);
  return ExpenseEntry(
    id: id,
    householdId: householdId,
    date: normalizedDate,
    amountCents: amountCents,
    createdAt: normalizedDate,
    currency: currency,
    category: category,
    type: type,
  );
}

List<ExpenseEntry> buildSyntheticExpensesFromPeriodTotals({
  required Map<DateTime, double> periodTotals,
  required String currency,
  String? householdId,
  String category = '_dashboard_period_total',
}) {
  final entries = <ExpenseEntry>[];
  final sortedBuckets = periodTotals.keys.toList()..sort();
  for (final bucket in sortedBuckets) {
    final amount = periodTotals[bucket] ?? 0;
    if (amount <= 0) {
      continue;
    }
    entries.add(
      buildSyntheticDashboardExpenseEntry(
        id: 'dashboard-period-${bucket.toIso8601String()}',
        date: bucket,
        amountCents: (amount * 100).round(),
        currency: currency,
        category: category,
        householdId: householdId,
      ),
    );
  }
  return entries;
}

List<ExpenseEntry> buildSyntheticExpensesFromCategorySummaries({
  required List<DashboardCategorySummary> categorySummaries,
  required String currency,
  required DateTime anchorDate,
  String? householdId,
}) {
  return categorySummaries
      .where((summary) => summary.amount > 0)
      .map(
        (summary) => buildSyntheticDashboardExpenseEntry(
          id: 'dashboard-category-${summary.category}',
          date: anchorDate,
          amountCents: (summary.amount * 100).round(),
          currency: currency,
          category: summary.category,
          householdId: householdId,
        ),
      )
      .toList(growable: false);
}

List<ExpenseEntry> buildSyntheticExpensesFromHouseholdCategories({
  required List<CategoryBreakdown> categoryBreakdown,
  required String currency,
  required DateTime anchorDate,
  String? householdId,
}) {
  return categoryBreakdown
      .where((summary) => summary.amountCents > 0)
      .map(
        (summary) => buildSyntheticDashboardExpenseEntry(
          id: 'household-category-${summary.category}',
          date: anchorDate,
          amountCents: summary.amountCents,
          currency: currency,
          category: summary.category,
          householdId: householdId,
        ),
      )
      .toList(growable: false);
}

List<ExpenseEntry> buildSyntheticNetCashflowTransactions({
  required String currency,
  required DateTime currentAnchorDate,
  required DateTime previousAnchorDate,
  required double currentExpenseTotal,
  required double currentIncomeTotal,
  required double previousExpenseTotal,
  required double previousIncomeTotal,
  String? householdId,
}) {
  final entries = <ExpenseEntry>[];

  void addIfPositive({
    required String id,
    required DateTime date,
    required double amount,
    required String type,
    required String category,
  }) {
    if (amount <= 0) {
      return;
    }
    entries.add(
      buildSyntheticDashboardExpenseEntry(
        id: id,
        date: date,
        amountCents: (amount * 100).round(),
        currency: currency,
        category: category,
        householdId: householdId,
        type: type,
      ),
    );
  }

  addIfPositive(
    id: 'net-current-income',
    date: currentAnchorDate,
    amount: currentIncomeTotal,
    type: 'income',
    category: 'income',
  );
  addIfPositive(
    id: 'net-current-expense',
    date: currentAnchorDate,
    amount: currentExpenseTotal,
    type: 'expense',
    category: 'expense',
  );
  addIfPositive(
    id: 'net-previous-income',
    date: previousAnchorDate,
    amount: previousIncomeTotal,
    type: 'income',
    category: 'income',
  );
  addIfPositive(
    id: 'net-previous-expense',
    date: previousAnchorDate,
    amount: previousExpenseTotal,
    type: 'expense',
    category: 'expense',
  );

  return entries;
}

ExpenseEntry buildSyntheticSpentByUserExpense({
  required String userId,
  required int totalSpentCents,
  required DateTime anchorDate,
  required String currency,
  String? householdId,
}) {
  return buildSyntheticDashboardExpenseEntry(
    id: 'spent-by-user-$userId',
    date: anchorDate,
    amountCents: totalSpentCents,
    currency: currency,
    category: 'expense',
    householdId: householdId,
  ).copyWith(userId: userId);
}
