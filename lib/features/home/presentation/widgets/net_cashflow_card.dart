import 'dart:math';

import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/core/core.dart';

import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';

Widget buildNetCashflowCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> allTransactions,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
}) {
  final now = DateTime.now();

  return Consumer(builder: (context, ref, _) {
    final viewMode = ref.watch(viewModeProvider);
    // Guard: this card is only used in personal mode
    if (viewMode.mode != ViewMode.personal) {
      return const SizedBox.shrink();
    }
    const String? householdId = null;

    // NOTE: Recurring transactions are loaded by app_initialization_provider
    // The derived providers below (recurringExpensesProvider, recurringIncomesProvider)
    // automatically watch the base provider

    // 1. Define Date Ranges
    final currentRange = _getDateRangeForFilter(filter, now);
    final previousRange = _getPreviousDateRangeForFilter(filter, now);

    // 2. Filter Transactions & Calculate Actuals
    final currentTransactions = _filterTransactions(
        allTransactions, currentRange.$1, currentRange.$2, selectedCurrency);
    final previousTransactions = _filterTransactions(
        allTransactions, previousRange.$1, previousRange.$2, selectedCurrency);

    final currentActuals = _getIncomeAndExpenses(currentTransactions);
    final previousActuals = _getIncomeAndExpenses(previousTransactions);

    // 3. Calculate Recurring (Projected for the ranges)
    final recurringExpensesAV =
        ref.watch(recurringExpensesProvider(householdId));
    final recurringIncomesAV = ref.watch(recurringIncomesProvider(householdId));

    final recurringExpenses = recurringExpensesAV.valueOrNull ?? [];
    final recurringIncomes = recurringIncomesAV.valueOrNull ?? [];

    final currentRecurringNet = _calculateRecurringNet(
      recurringIncomes,
      recurringExpenses,
      currentRange.$1,
      currentRange.$2,
      selectedCurrency,
    );

    final previousRecurringNet = _calculateRecurringNet(
      recurringIncomes,
      recurringExpenses,
      previousRange.$1,
      previousRange.$2,
      selectedCurrency,
    );

    // 4. Compute Net Cashflows
    // Current Net = (Actual Income + Recurring Income) - (Actual Expense + Recurring Expense)
    final currentNet =
        (currentActuals.$1 - currentActuals.$2) + currentRecurringNet;

    final previousNet =
        (previousActuals.$1 - previousActuals.$2) + previousRecurringNet;

    final isNegative = currentNet < 0;
    final absAmount = currentNet.abs();
    final symbol = resolveCurrencySymbol(selectedCurrency ?? 'USD');
    final localizedAmount = formatLocalizedNumber(context, absAmount);
    final displayText =
        isNegative ? '-$symbol$localizedAmount' : '$symbol$localizedAmount';

    final title = _netCashflowTitleForFilter(context, filter);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 5. Comparison Logic
    final isBetter = currentNet > previousNet;
    // final diff = currentNet - previousNet;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: _netCashflowFontSize(displayText),
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                color: colorScheme.foreground,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  (isBetter ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBetter
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: isBetter
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 16,
                ),
              ],
            ),
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

String _netCashflowTitleForFilter(
    BuildContext context, DateRangeFilter filter) {
  final l10n = context.l10n;
  // Always show "This Month" regardless of external filters
  return l10n.netCashflowThisMonth;
}

double _netCashflowFontSize(String displayText) {
  final length = displayText.length;

  if (length <= 6) {
    return 35;
  } else if (length <= 7) {
    return 34;
  } else if (length <= 8) {
    return 33;
  } else {
    return 32;
  }
}

// --- Helper Methods for Comparison Logic ---

(DateTime, DateTime) _getDateRangeForFilter(
    DateRangeFilter filter, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (filter) {
    case DateRangeFilter.thisMonth:
      return (DateTime(now.year, now.month, 1), today);
    case DateRangeFilter.last30Days:
      return (
        today.subtract(const Duration(days: 29)),
        today
      ); // 30 days inclusive
    case DateRangeFilter.thisWeek:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return (weekStart, today);
    case DateRangeFilter.today:
      return (DateTime(now.year, now.month, now.day), today);
    default:
      // Default to This Month if logic is unclear or AllTime
      return (DateTime(now.year, now.month, 1), today);
  }
}

(DateTime, DateTime) _getPreviousDateRangeForFilter(
    DateRangeFilter filter, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (filter) {
    case DateRangeFilter.thisMonth:
      // Previous month, up to same day
      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0).day;
      final dayToCompare = min(now.day, lastDayPrevMonth);
      final prevMonthEnd =
          DateTime(now.year, now.month - 1, dayToCompare, 23, 59, 59);
      return (prevMonthStart, prevMonthEnd);

    case DateRangeFilter.last30Days:
      // Previous 30 days (31-60 days ago)
      final end = today.subtract(const Duration(days: 30));
      final start = end.subtract(const Duration(days: 29));
      return (start, end);

    case DateRangeFilter.thisWeek:
      // Previous week, up to same weekday
      final currentStart = today.subtract(Duration(days: today.weekday - 1));
      final prevStart = currentStart.subtract(const Duration(days: 7));
      final prevEnd = today.subtract(const Duration(days: 7));
      return (prevStart, prevEnd);

    case DateRangeFilter.today:
      final yesterday = today.subtract(const Duration(days: 1));
      final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      return (start, yesterday);

    default:
      // Fallback
      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0).day;
      final dayToCompare = min(now.day, lastDayPrevMonth);
      final prevMonthEnd =
          DateTime(now.year, now.month - 1, dayToCompare, 23, 59, 59);
      return (prevMonthStart, prevMonthEnd);
  }
}

List<ExpenseEntry> _filterTransactions(
    List<ExpenseEntry> all, DateTime start, DateTime end, String? currency) {
  final currencyFilter = currency?.toUpperCase();
  return all.where((t) {
    if (currencyFilter != null &&
        (t.currency ?? '').toUpperCase() != currencyFilter) {
      return false;
    }
    // Ensure date comparison ignores time for start, but end includes time if needed
    // Actually ExpenseEntry date usually has time 00:00:00 or specific time.
    // Let's rely on standard comparison.
    return !t.date.isBefore(start) && !t.date.isAfter(end);
  }).toList();
}

double _calculateRecurringNet(
  List<RecurringTransaction> incomes,
  List<RecurringTransaction> expenses,
  DateTime start,
  DateTime end,
  String? currency,
) {
  double incomeSum = 0;
  double expenseSum = 0;

  for (final item in incomes) {
    incomeSum += _sumRecurringItem(item, start, end, currency);
  }
  for (final item in expenses) {
    expenseSum += _sumRecurringItem(item, start, end, currency);
  }

  return incomeSum - expenseSum;
}

double _sumRecurringItem(
    RecurringTransaction item, DateTime start, DateTime end, String? currency) {
  if (currency != null &&
      item.currency.toUpperCase() != currency.toUpperCase()) {
    return 0;
  }
  if (!_isActiveNow(item, end)) return 0; // Check if active by end of period

  final count = _countOccurrencesInPeriod(item, start, end);
  if (count > 0) {
    return item.amount.abs() * count;
  }
  return 0;
}

bool _isActiveNow(RecurringTransaction item, DateTime checkDate) {
  final rule = item.recurrenceRule;
  if (rule == null) return true;
  final end = rule.endDate;
  if (end == null) return true;
  return !end.isBefore(checkDate);
}

int _countOccurrencesInPeriod(
    RecurringTransaction item, DateTime start, DateTime end) {
  final rule = item.recurrenceRule;
  if (rule == null) {
    final d = item.date.toLocal();
    return (!d.isBefore(start) && !d.isAfter(end)) ? 1 : 0;
  }

  final anchor = rule.anchorDate.toLocal();
  final endLocal = rule.endDate?.toLocal();
  if (endLocal != null && endLocal.isBefore(start)) return 0;

  final effectiveEnd = _minDate(end, endLocal);
  if (anchor.isAfter(effectiveEnd)) return 0;

  final interval = rule.interval ?? 1;
  final freq = rule.frequency.toLowerCase();

  switch (freq) {
    case 'daily':
      return _countOccurrencesByStep(
          anchor, start, effectiveEnd, Duration(days: interval));
    case 'weekly':
      return _countOccurrencesByStep(
          anchor, start, effectiveEnd, Duration(days: 7 * interval));
    case 'biweekly':
      return _countOccurrencesByStep(
          anchor, start, effectiveEnd, const Duration(days: 14));
    case 'monthly':
      return _countOccurrencesMonthly(anchor, interval, start, effectiveEnd);
    case 'yearly':
      return _countOccurrencesYearly(anchor, interval, start, effectiveEnd);
    default:
      return (!anchor.isBefore(start) && !anchor.isAfter(effectiveEnd)) ? 1 : 0;
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
  return remainder == 0
      ? start
      : start.add(Duration(days: stepDays - remainder));
}

int _countOccurrencesMonthly(
    DateTime anchor, int interval, DateTime start, DateTime end) {
  int count = 0;
  // Start checking from anchor or start, whichever is later (roughly)
  // Actually simpler to iterate from anchor
  DateTime current = anchor;
  while (!current.isAfter(end)) {
    if (!current.isBefore(start)) {
      count++;
    }
    // Add months
    // Logic to add months correctly (handling end of month)
    int newMonth = current.month + interval;
    int newYear = current.year + (newMonth - 1) ~/ 12;
    newMonth = (newMonth - 1) % 12 + 1;
    int newDay = min(current.day, DateTime(newYear, newMonth + 1, 0).day);
    current = DateTime(newYear, newMonth, newDay, current.hour, current.minute);
  }
  return count;
}

int _countOccurrencesYearly(
    DateTime anchor, int interval, DateTime start, DateTime end) {
  int count = 0;
  DateTime current = anchor;
  while (!current.isAfter(end)) {
    if (!current.isBefore(start)) {
      count++;
    }
    current = DateTime(current.year + interval, current.month, current.day,
        current.hour, current.minute);
  }
  return count;
}

DateTime _minDate(DateTime a, DateTime? b) {
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}
