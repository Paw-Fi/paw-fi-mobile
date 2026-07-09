import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

/// Daily net cashflow series (income - expenses) grouped by date
final homeCashflowSeriesProvider = Provider<Map<DateTime, double>>((ref) {
  final txs = ref.watch(homeFilteredTransactionsProvider);
  final map = <DateTime, double>{};
  for (final t in txs) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    final isIncome = (t.type ?? 'expense').toLowerCase() == 'income';
    final delta = (isIncome ? 1 : -1) * t.amount.abs();
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
    final isIncome = (t.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      income += t.amount.abs();
    } else {
      spend += t.amount.abs();
    }
  }
  if (income <= 0) return 0;
  return ((income - spend) / income).clamp(-1.0, 1.0);
});

/// Month-over-month expense totals for the last 3 months
final momTrendProvider = Provider<Map<String, double>>((ref) {
  final data = ref.watch(analyticsProvider);
  final filter = ref.watch(homeFilterProvider);
  final setCurrency = filter.selectedCurrency?.toUpperCase();
  final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);
  // MoM trend is personal-only; always scope recurring to personal data
  final recurringExpensesAV = ref.watch(recurringExpensesProvider(null));

  // Build last 3 financial-cycle keys.
  final now = DateTime.now();
  final currentCycleStart = financialCycleStartForDate(
    now,
    startDay: financialMonthStartDay,
  );
  final months = List.generate(3, (i) {
    return addFinancialCycles(
      currentCycleStart,
      -i,
      startDay: financialMonthStartDay,
    );
  });
  final keys = months.map(formatFinancialPeriodDate).toList();
  final map = {for (final k in keys) k: 0.0};
  final actualExpensesByKey = <String, List<ExpenseEntry>>{
    for (final key in keys) key: <ExpenseEntry>[],
  };

  for (final e in data.allExpenses) {
    // Expense-only
    if ((e.type ?? 'expense').toLowerCase() == 'income') continue;
    if (setCurrency != null && (e.currency?.toUpperCase() != setCurrency)) {
      continue;
    }
    final expenseDate = dateOnly(e.date);
    for (final start in months) {
      final end = nextFinancialCycleStart(
        start,
        startDay: financialMonthStartDay,
      ).subtract(const Duration(days: 1));
      if (expenseDate.isBefore(start) || expenseDate.isAfter(end)) {
        continue;
      }
      final key = formatFinancialPeriodDate(start);
      map[key] = (map[key] ?? 0) + e.amount.abs();
      actualExpensesByKey[key]!.add(e);
      break;
    }
  }

  recurringExpensesAV.when(
    data: (items) {
      final now = DateTime.now();
      for (final month in months) {
        final start = month;
        final end = nextFinancialCycleStart(
          start,
          startDay: financialMonthStartDay,
        ).subtract(const Duration(days: 1));
        final key = formatFinancialPeriodDate(start);
        final mergedExpenses = mergeActualExpensesWithProjectedRecurring(
          actualExpenses: actualExpensesByKey[key] ?? const <ExpenseEntry>[],
          recurringTransactions: items,
          rangeStart: start,
          rangeEnd: end,
          selectedCurrency: setCurrency,
          includeFutureOccurrences: false,
          now: now,
        );
        map[key] = mergedExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount.abs(),
        );
      }
    },
    loading: () {},
    error: (_, __) {},
  );
  return map;
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
  final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount.abs());
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
