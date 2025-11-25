import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
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
  // MoM trend is personal-only; always scope recurring to personal data
  final recurringExpensesAV = ref.watch(recurringExpensesProvider(null));

  // Build last 3 month keys: yyyy-MM
  final now = DateTime.now();
  final months = List.generate(3, (i) {
    final d = DateTime(now.year, now.month - i, 1);
    return DateTime(d.year, d.month); // normalized
  });
  final keys = months.map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}').toList();
  final map = {for (final k in keys) k: 0.0};

  for (final e in data.allExpenses) {
    // Expense-only
    if ((e.type ?? 'expense').toLowerCase() == 'income') continue;
    if (setCurrency != null && (e.currency?.toUpperCase() != setCurrency)) continue;
    final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
    if (map.containsKey(key)) {
      map[key] = (map[key] ?? 0) + e.amount.abs();
    }
  }

  // Add recurring expenses occurrence sums for each of the last 3 months
  recurringExpensesAV.when(
    data: (items) {
      final now = DateTime.now();
      for (final item in items) {
        if (item.type != 'expense') continue;
        // Only include active recurring transactions as of now
        if (!_isActiveNow(item, now)) continue;
        if (setCurrency != null && item.currency.toUpperCase() != setCurrency) continue;
        for (final month in months) {
          final start = DateTime(month.year, month.month, 1);
          final end = DateTime(month.year, month.month + 1, 0);
          final count = _occurrencesInMonth(item, start, end);
          if (count > 0) {
            final key = '${start.year}-${start.month.toString().padLeft(2, '0')}';
            map[key] = (map[key] ?? 0) + item.amount.abs() * count;
          }
        }
      }
    },
    loading: () {},
    error: (_, __) {},
  );
  return map;
});


int _occurrencesInMonth(
  RecurringTransaction item,
  DateTime monthStart,
  DateTime monthEnd,
) {
  final rule = item.recurrenceRule;
  if (rule == null) {
    final d = item.date.toLocal();
    return (d.year == monthStart.year && d.month == monthStart.month) ? 1 : 0;
  }

  final anchor = rule.anchorDate.toLocal();
  final endLocal = rule.endDate?.toLocal();
  if (endLocal != null && endLocal.isBefore(monthStart)) return 0;

  final interval = rule.interval ?? 1;
  final freq = rule.frequency.toLowerCase();
  switch (freq) {
    case 'daily':
      return _countOccurrencesByStep(
          anchor, monthStart, _minDate(monthEnd, endLocal), Duration(days: interval));
    case 'weekly':
      return _countOccurrencesByStep(
          anchor, monthStart, _minDate(monthEnd, endLocal), Duration(days: 7 * interval));
    case 'biweekly':
      return _countOccurrencesByStep(
          anchor, monthStart, _minDate(monthEnd, endLocal), const Duration(days: 14));
    case 'monthly':
      return _occursMonthly(anchor, interval, monthStart) ? 1 : 0;
    case 'yearly':
      return _occursYearly(anchor, interval, monthStart) ? 1 : 0;
    default:
      return (anchor.year == monthStart.year && anchor.month == monthStart.month) ? 1 : 0;
  }
}

int _countOccurrencesByStep(
  DateTime anchor,
  DateTime rangeStart,
  DateTime rangeEnd,
  Duration step,
) {
  if (anchor.isAfter(rangeEnd)) return 0;
  final first = _firstOnOrAfter(anchor, rangeStart, step);
  if (first.isAfter(rangeEnd)) return 0;
  final totalDays = rangeEnd.difference(first).inDays;
  final stepDays = step.inDays;
  if (stepDays <= 0) return 0;
  return 1 + (totalDays ~/ stepDays);
}

DateTime _firstOnOrAfter(DateTime anchor, DateTime start, Duration step) {
  if (!start.isAfter(anchor)) return anchor;
  final diffDays = start.difference(anchor).inDays;
  final stepDays = step.inDays;
  final remainder = diffDays % stepDays;
  return remainder == 0 ? start : start.add(Duration(days: stepDays - remainder));
}

bool _occursMonthly(DateTime anchor, int interval, DateTime monthStart) {
  final months = (monthStart.year - anchor.year) * 12 + (monthStart.month - anchor.month);
  if (months < 0) return false;
  return months % interval == 0;
}

bool _occursYearly(DateTime anchor, int interval, DateTime monthStart) {
  if (monthStart.month != anchor.month) return false;
  final years = monthStart.year - anchor.year;
  if (years < 0) return false;
  return years % interval == 0;
}

DateTime _minDate(DateTime a, DateTime? b) {
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

bool _isActiveNow(RecurringTransaction item, DateTime now) {
  final rule = item.recurrenceRule;
  if (rule == null) return true;
  final end = rule.endDate;
  if (end == null) return true;
  return !end.isBefore(now);
}
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
  final filter = ref.watch(homeFilterProvider);

  if (expenses.isEmpty || budgets.isEmpty) {
    return const RunwayInfo(daysRemaining: 0, budgetRemaining: 0, avgDailySpend: 0, gauge: 0);
  }

  // Date range window
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );
  final from = DateTime(range['from']!.year, range['from']!.month, range['from']!.day);
  final to = DateTime(range['to']!.year, range['to']!.month, range['to']!.day);
  final daysInWindow = (to.difference(from).inDays + 1).clamp(1, 365).toDouble();

  // Total spent and average daily spend
  final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount.abs());
  final avgDailySpend = totalSpent / daysInWindow;

  // Budget for window (sum of entries in range)
  final totalBudget = budgets.fold<double>(0, (s, b) => s + b.amount);
  final budgetRemaining = (totalBudget - totalSpent).clamp(0.0, double.infinity).toDouble();

  // Days remaining based on average spend
  final daysRemaining = avgDailySpend > 0 ? (budgetRemaining / avgDailySpend) : daysInWindow;
  final gauge = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0).toDouble() : 0.0;

  return RunwayInfo(
    daysRemaining: daysRemaining.toDouble(),
    budgetRemaining: budgetRemaining.toDouble(),
    avgDailySpend: avgDailySpend.toDouble(),
    gauge: gauge.toDouble(),
  );
});
