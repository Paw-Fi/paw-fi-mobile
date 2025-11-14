import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/core/core.dart';

Widget buildNetCashflowCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> transactions,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
}) {
  final now = DateTime.now();
  final thisMonthTransactions = transactions
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .toList();

  return Consumer(builder: (context, ref, _) {
    final recState = ref.watch(recurringTransactionsProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId != null && !recState.hasLoadedOnce && !recState.data.isLoading) {
      // Lazy-load recurring data when the card appears
      Future.microtask(() {
        // Double-check again inside task to avoid duplicate triggers
        final s = ref.read(recurringTransactionsProvider);
        if (!s.hasLoadedOnce && !s.data.isLoading) {
          debugPrint('[NetCashflow] Triggering initial recurring load for user=$userId');
          ref.read(recurringTransactionsProvider.notifier).loadRecurringTransactions(userId);
        }
      });
    }

    final totals = _getIncomeAndExpenses(thisMonthTransactions);
    final totalIncome = totals.$1;
    final totalSpent = totals.$2;

    final recurringExpensesAV = ref.watch(recurringExpensesProvider);
    final recurringIncomesAV = ref.watch(recurringIncomesProvider);

    final recurringExpenseThisMonth = recurringExpensesAV.maybeWhen(
      data: (items) {
        debugPrint('[NetCashflow] Recurring expenses loaded: count=${items.length}');
        final sum = _sumRecurringForMonth(items, now, selectedCurrency: selectedCurrency);
        debugPrint('[NetCashflow] Recurring expenses (this month) sum=$sum');
        return sum;
      },
      orElse: () {
        debugPrint('[NetCashflow] Recurring expenses not loaded yet');
        return 0.0;
      },
    );
    final recurringIncomeThisMonth = recurringIncomesAV.maybeWhen(
      data: (items) {
        debugPrint('[NetCashflow] Recurring incomes loaded: count=${items.length}');
        final sum = _sumRecurringForMonth(items, now, selectedCurrency: selectedCurrency);
        debugPrint('[NetCashflow] Recurring incomes (this month) sum=$sum');
        return sum;
      },
      orElse: () {
        debugPrint('[NetCashflow] Recurring incomes not loaded yet');
        return 0.0;
      },
    );

    final netCashflow =
        (totalIncome + recurringIncomeThisMonth) - (totalSpent + recurringExpenseThisMonth);
    debugPrint('[NetCashflow] totals: income=$totalIncome, spent=$totalSpent, recIncome=$recurringIncomeThisMonth, recExpense=$recurringExpenseThisMonth, net=$netCashflow');
    final isNegative = netCashflow < 0;

    final absAmount = netCashflow.abs();
    final formattedAmount = formatCurrency(absAmount, selectedCurrency ?? 'USD');
    final displayText = isNegative ? '-$formattedAmount' : formattedAmount;

    final title = _netCashflowTitleForFilter(context, filter);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.circle,
                color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 8,
              ),
              const SizedBox(width: 4),
              Text(
                isNegative ? context.l10n.negative : context.l10n.positive,
                style: TextStyle(
                  fontSize: 12,
                  color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });
}

/// Returns (income, expenses)
(double, double) _getIncomeAndExpenses(List<ExpenseEntry> transactions) {
  double income = 0;
  double spend = 0;
  for (final t in transactions) {
    final ttype = (t.type ?? 'expense').toLowerCase();
    if (ttype == 'income') {
      income += t.amount.abs();
    } else {
      spend += t.amount.abs();
    }
  }
  return (income, spend);
}

String _netCashflowTitleForFilter(BuildContext context, DateRangeFilter filter) {
  final l10n = context.l10n;
  // Always show "This Month" regardless of external filters
  return l10n.netCashflowThisMonth;
}

double _sumRecurringForMonth(List<RecurringTransaction> items, DateTime now, {String? selectedCurrency}) {
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);
  double sum = 0;
  final currencyFilter = selectedCurrency?.toUpperCase();
  for (final item in items) {
    // Only include active recurring transactions
    if (!_isActiveNow(item, now)) continue;
    if (currencyFilter != null && item.currency.toUpperCase() != currencyFilter) {
      continue;
    }
    final count = _occurrencesInMonth(item, monthStart, monthEnd);
    final rule = item.recurrenceRule;
    final ruleStr = rule != null
        ? '{freq=${rule.frequency}, anchor=${rule.anchorDate.toIso8601String()}, interval=${rule.interval?.toString() ?? 'null'}, end=${rule.endDate?.toIso8601String() ?? 'null'}}'
        : 'null';
    debugPrint('[NetCashflow] Item id=${item.id}, type=${item.type}, amount=${item.amount}, curr=${item.currency}, date=${item.date.toIso8601String()}, rule=$ruleStr, countThisMonth=$count');
    if (count > 0) {
      sum += item.amount.abs() * count;
    }
  }
  return sum;
}

bool _isActiveNow(RecurringTransaction item, DateTime now) {
  final rule = item.recurrenceRule;
  if (rule == null) return true; // Treat as active if no rule present
  final end = rule.endDate;
  if (end == null) return true; // No end date -> never expires
  return !end.isBefore(now); // Active if end date is not in the past
}

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
      // Fallback: count first anchor if it falls within this month
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
