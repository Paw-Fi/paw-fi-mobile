import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/period_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

/// Daily net cashflow series (income - expenses) grouped by date
final homeCashflowSeriesProvider = Provider<Map<DateTime, double>>((ref) {
  final txs = ref.watch(homeFilteredTransactionsProvider);
  final map = <DateTime, double>{};
  for (final t in txs) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    final delta = t.countsTowardIncome ? t.amount.abs() : -t.spendingEffect;
    map[d] = (map[d] ?? 0) + delta;
  }
  final keys = map.keys.toList()..sort();
  return {for (final k in keys) k: map[k]!};
});

/// Savings rate = (income - expenses) / income for current filter window
final savingsRateProvider = Provider<double>((ref) {
  final txs = ref.watch(homeFilteredTransactionsProvider);
  double income = 0, spend = 0;
  for (final t in txs) {
    if (t.countsTowardIncome) {
      income += t.amount.abs();
    } else if (t.effectiveSpendingMultiplier != 0) {
      spend += t.spendingEffect;
    }
  }
  if (income <= 0) return 0;
  return ((income - spend) / income).clamp(-1.0, 1.0);
});

List<DateTime> _momTrendCycleStarts(
  DateTime now, {
  required int financialMonthStartDay,
}) {
  final currentCycleStart = financialCycleStartForDate(
    now,
    startDay: financialMonthStartDay,
  );
  return List<DateTime>.generate(3, (index) {
    return addFinancialCycles(
      currentCycleStart,
      -index,
      startDay: financialMonthStartDay,
    );
  });
}

Map<String, double> calculateMomTrend({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime now,
  required int financialMonthStartDay,
  String? selectedCurrency,
}) {
  final normalizedCurrency = selectedCurrency?.trim().toUpperCase();
  final months = _momTrendCycleStarts(
    now,
    financialMonthStartDay: financialMonthStartDay,
  );
  final keys = months.map(formatFinancialPeriodDate).toList(growable: false);
  final totals = <String, double>{for (final key in keys) key: 0};
  final eligibleActualExpenses = <ExpenseEntry>[];

  for (final expense in actualTransactions) {
    if (expense.effectiveSpendingMultiplier == 0) continue;
    // Recurring rows are schedule templates, not posted transactions. Their
    // actual/projected occurrences are supplied by recurringTransactions.
    if (expense.isRecurring) continue;
    // Personal Home's historical MoM contract excludes split transactions;
    // household split analytics are rendered by the household dashboard.
    if (expense.splitGroupId?.trim().isNotEmpty == true) continue;
    if (normalizedCurrency != null &&
        expense.currency?.toUpperCase() != normalizedCurrency) {
      continue;
    }
    eligibleActualExpenses.add(expense);
  }

  for (final start in months) {
    final end = nextFinancialCycleStart(
      start,
      startDay: financialMonthStartDay,
    ).subtract(const Duration(days: 1));
    final key = formatFinancialPeriodDate(start);
    final mergedExpenses = mergeActualExpensesWithProjectedRecurring(
      // Include all actuals for scheduled-occurrence suppression, while the
      // merge keeps returned actuals scoped to this paid-date period.
      actualExpenses: eligibleActualExpenses,
      recurringTransactions: recurringTransactions,
      rangeStart: start,
      rangeEnd: end,
      selectedCurrency: normalizedCurrency,
      includeFutureOccurrences: false,
      now: now,
    );
    totals[key] = mergedExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.spendingEffect,
    );
  }
  return totals;
}

/// Month-over-month expense totals for the last 3 months
final momTrendProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return const AsyncValue.data(<String, double>{});
  }
  final filter = ref.watch(homeFilterProvider);
  final periodSelection = ref.watch(homePeriodSelectionProvider(userId));
  final setCurrency = filter.selectedCurrency?.toUpperCase();
  final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
  final scope = ref.watch(householdScopeProvider);
  final householdId = scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
  final recurringExpensesAV = ref.watch(recurringExpensesProvider(householdId));

  // Build last 3 financial-cycle keys.
  final now = periodSelection.selectedDate;
  final months = _momTrendCycleStarts(
    now,
    financialMonthStartDay: financialMonthStartDay,
  );
  final currentCycleStart = months.first;
  final rangeStart = months.last;
  final rangeEnd = nextFinancialCycleStart(
    currentCycleStart,
    startDay: financialMonthStartDay,
  ).subtract(const Duration(days: 1));
  final transactionsAsync = ref.watch(
    dashboardOwnedRangeTransactionsProvider(
      DashboardScopeQuery(
        userId: userId,
        householdId: householdId,
        selectedCurrency: setCurrency,
        selectedCurrencies: setCurrency == null ? null : <String>[setCurrency],
        startDate: rangeStart,
        endDate: rangeEnd,
      ),
    ),
  );
  final actualTransactions = transactionsAsync.valueOrNull;
  if (actualTransactions == null) {
    if (transactionsAsync.hasError) {
      return AsyncValue.error(
        transactionsAsync.error!,
        transactionsAsync.stackTrace ?? StackTrace.current,
      );
    }
    return const AsyncValue.loading();
  }
  final recurringExpenses = recurringExpensesAV.valueOrNull;
  if (recurringExpenses == null) {
    if (recurringExpensesAV.hasError) {
      return AsyncValue.error(
        recurringExpensesAV.error!,
        recurringExpensesAV.stackTrace ?? StackTrace.current,
      );
    }
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    calculateMomTrend(
      actualTransactions: actualTransactions,
      recurringTransactions: recurringExpenses,
      now: now,
      financialMonthStartDay: financialMonthStartDay,
      selectedCurrency: setCurrency,
    ),
  );
});

/// Budget runway gauge inputs (estimated days until budget consumed)
class RunwayInfo {
  final double daysRemaining;
  final double budgetRemaining;
  final double avgDailySpend;
  final double gauge; // 0..1 consumed
  const RunwayInfo({
    required this.daysRemaining,
    required this.budgetRemaining,
    required this.avgDailySpend,
    required this.gauge,
  });
}

final runwayProvider = Provider<RunwayInfo>((ref) {
  final expenses = ref.watch(homeFilteredExpensesProvider);
  final budgets = ref.watch(homeFilteredBudgetsProvider);
  final periodSelection = ref.watch(periodFilterProvider);
  final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);

  if (expenses.isEmpty || budgets.isEmpty) {
    return const RunwayInfo(
        daysRemaining: 0, budgetRemaining: 0, avgDailySpend: 0, gauge: 0);
  }
  // Date range window
  final range = resolvePeriodDateRange(
    periodSelection,
    financialMonthStartDay: financialMonthStartDay,
  );
  final from = DateTime(range.start.year, range.start.month, range.start.day);
  final to = DateTime(range.end.year, range.end.month, range.end.day);
  final daysInWindow =
      (to.difference(from).inDays + 1).clamp(1, 365).toDouble();

  // Total spent and average daily spend
  final totalSpent =
      expenses.fold<double>(0, (sum, expense) => sum + expense.spendingEffect);
  final avgDailySpend = totalSpent / daysInWindow;

  // Budget for window (sum of entries in range)
  final totalBudget = budgets.fold<double>(0, (s, b) => s + b.amount);
  final budgetRemaining =
      (totalBudget - totalSpent).clamp(0.0, double.infinity).toDouble();

  // Days remaining based on average spend
  final daysRemaining =
      avgDailySpend > 0 ? (budgetRemaining / avgDailySpend) : daysInWindow;
  final gauge = totalBudget > 0
      ? (totalSpent / totalBudget).clamp(0.0, 1.0).toDouble()
      : 0.0;

  return RunwayInfo(
    daysRemaining: daysRemaining.toDouble(),
    budgetRemaining: budgetRemaining.toDouble(),
    avgDailySpend: avgDailySpend.toDouble(),
    gauge: gauge.toDouble(),
  );
});
