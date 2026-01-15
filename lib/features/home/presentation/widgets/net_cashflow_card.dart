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
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

Widget buildNetCashflowCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> allTransactions,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
  DateTime? customStartDate,
  DateTime? customEndDate,
}) {
  final now = DateTime.now();

  return Consumer(builder: (context, ref, _) {
    final householdScope = ref.watch(householdScopeProvider);
    // Guard: this card is only used in personal/portfolio mode.
    // Portfolio households (is_portfolio=true) are treated as personal.
    if (householdScope.isHouseholdView) {
      return const SizedBox.shrink();
    }

    final activeAccountHouseholdId = householdScope.activeAccountHouseholdId;

    // Scope strictly to the selected account in HomeHeaderSliver:
    // - Personal account: household_id == null
    // - Portfolio account: household_id == selected portfolio household id
    final scopedTransactions = allTransactions
        .where((t) {
          final hid = t.householdId;
          return switch (householdScope.activeAccountType) {
            ActiveAccountType.personal => hid == null || hid.isEmpty,
            ActiveAccountType.portfolio =>
              activeAccountHouseholdId != null && hid == activeAccountHouseholdId,
            ActiveAccountType.household => false,
          };
        })
        .toList(growable: false);

    final recurringHouseholdId = householdScope.activeAccountType == ActiveAccountType.personal
        ? null
        : activeAccountHouseholdId;

    // NOTE: Recurring transactions are loaded by app_initialization_provider
    // The derived providers below (recurringExpensesProvider, recurringIncomesProvider)
    // automatically watch the base provider

    // 1. Define Date Ranges
    final currentRange =
        _getDateRangeForFilter(filter, now, customStartDate, customEndDate);
    final previousRange = _getPreviousDateRangeForFilter(
        filter, now, customStartDate, customEndDate);

    // 2. Filter Transactions & Calculate Actuals
    final currentTransactions = _filterTransactions(scopedTransactions,
        currentRange.$1, currentRange.$2, selectedCurrency);
    final previousTransactions = _filterTransactions(scopedTransactions,
        previousRange.$1, previousRange.$2, selectedCurrency);

    final currentActuals = _getIncomeAndExpenses(currentTransactions);
    final previousActuals = _getIncomeAndExpenses(previousTransactions);

    // 3. Calculate Recurring (Projected for the ranges)
    final recurringExpensesAV =
        ref.watch(recurringExpensesProvider(recurringHouseholdId));
    final recurringIncomesAV =
        ref.watch(recurringIncomesProvider(recurringHouseholdId));

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
    final normalized = double.parse(formatAmount(absAmount));
    final localizedAmount = formatLocalizedNumber(context, normalized);
    final displayText =
        isNegative ? '-$symbol$localizedAmount' : '$symbol$localizedAmount';

    final title = _netCashflowTitleForFilter(context, filter);

    // 5. Comparison Logic
    final isBetter = currentNet > previousNet;
    // final diff = currentNet - previousNet;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
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
              color: (isBetter ? colorScheme.success : colorScheme.destructive)
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
                  color:
                      isBetter ? colorScheme.success : colorScheme.destructive,
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
  switch (filter) {
    case DateRangeFilter.today:
      return l10n.netCashflowToday;
    case DateRangeFilter.yesterday:
      return l10n.netCashflowYesterday;
    case DateRangeFilter.thisWeek:
      return l10n.netCashflowThisWeek;
    case DateRangeFilter.lastWeek:
      return l10n.netCashflowLastWeek;
    case DateRangeFilter.last30Days:
      return l10n.netCashflowLast30Days;
    case DateRangeFilter.thisMonth:
      return l10n.netCashflowThisMonth;
    case DateRangeFilter.custom:
      return l10n.netCashflowCustom;
    // Fallback to a sensible label when we don't have a dedicated string
    case DateRangeFilter.last7Days:
    case DateRangeFilter.lastMonth:
    case DateRangeFilter.thisYear:
    case DateRangeFilter.allTime:
      return l10n.netCashflowThisMonth;
  }
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

(DateTime, DateTime) _getDateRangeForFilter(DateRangeFilter filter,
    DateTime now, DateTime? customStart, DateTime? customEnd) {
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final todayStart = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DateRangeFilter.today:
      return (todayStart, todayEnd);
    case DateRangeFilter.yesterday:
      final yStart = todayStart.subtract(const Duration(days: 1));
      final yEnd = todayEnd.subtract(const Duration(days: 1));
      return (yStart, yEnd);
    case DateRangeFilter.thisWeek:
      final weekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      return (weekStart, todayEnd);
    case DateRangeFilter.lastWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      final lastWeekEnd = thisWeekStart.subtract(const Duration(seconds: 1));
      return (lastWeekStart, lastWeekEnd);
    case DateRangeFilter.last7Days:
      final start = todayStart.subtract(const Duration(days: 6));
      return (start, todayEnd);
    case DateRangeFilter.thisMonth:
      final start = DateTime(now.year, now.month, 1);
      return (start, todayEnd);
    case DateRangeFilter.lastMonth:
      final start = DateTime(now.year, now.month - 1, 1);
      final end =
          DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
      return (start, end);
    case DateRangeFilter.last30Days:
      final start = todayStart.subtract(const Duration(days: 29));
      return (start, todayEnd);
    case DateRangeFilter.thisYear:
      final start = DateTime(now.year, 1, 1);
      return (start, todayEnd);
    case DateRangeFilter.allTime:
      final start = DateTime.fromMillisecondsSinceEpoch(0);
      return (start, todayEnd);
    case DateRangeFilter.custom:
      if (customStart != null && customEnd != null) {
        final start =
            DateTime(customStart.year, customStart.month, customStart.day);
        final end = DateTime(
            customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
        return (start, end);
      }
      // Fallback to last 30 days if custom dates are missing
      final start = todayStart.subtract(const Duration(days: 29));
      return (start, todayEnd);
  }
}

(DateTime, DateTime) _getPreviousDateRangeForFilter(DateRangeFilter filter,
    DateTime now, DateTime? customStart, DateTime? customEnd) {
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final todayStart = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DateRangeFilter.today:
      final yStart = todayStart.subtract(const Duration(days: 1));
      final yEnd = todayEnd.subtract(const Duration(days: 1));
      return (yStart, yEnd);
    case DateRangeFilter.yesterday:
      final prevStart = todayStart.subtract(const Duration(days: 2));
      final prevEnd = todayEnd.subtract(const Duration(days: 2));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final prevStart = thisWeekStart.subtract(const Duration(days: 7));
      final prevEnd = thisWeekStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.lastWeek:
      final thisWeekStart =
          todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      final prevStart = lastWeekStart.subtract(const Duration(days: 7));
      final prevEnd = lastWeekStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.last7Days:
      final currentStart = todayStart.subtract(const Duration(days: 6));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 6));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisMonth:
      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0).day;
      final dayToCompare = min(now.day, lastDayPrevMonth);
      final prevMonthEnd =
          DateTime(now.year, now.month - 1, dayToCompare, 23, 59, 59);
      return (prevMonthStart, prevMonthEnd);
    case DateRangeFilter.lastMonth:
      final currentStart = DateTime(now.year, now.month - 1, 1);
      final prevStart = DateTime(now.year, now.month - 2, 1);
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      return (prevStart, prevEnd);
    case DateRangeFilter.last30Days:
      final currentStart = todayStart.subtract(const Duration(days: 29));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      return (prevStart, prevEnd);
    case DateRangeFilter.thisYear:
      final prevYear = now.year - 1;
      final lastDayPrevYear = DateTime(prevYear + 1, 1, 0).day;
      final dayToCompare = min(now.day, lastDayPrevYear);
      final prevEnd = DateTime(prevYear, now.month, dayToCompare, 23, 59, 59);
      final prevStart = DateTime(prevYear, 1, 1);
      return (prevStart, prevEnd);
    case DateRangeFilter.allTime:
      // Mirror the current span backwards so comparison remains consistent
      final currentStart = DateTime.fromMillisecondsSinceEpoch(0);
      final currentEnd = todayEnd;
      final span = currentEnd.difference(currentStart);
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(span);
      return (prevStart, prevEnd);
    case DateRangeFilter.custom:
      if (customStart != null && customEnd != null) {
        final start =
            DateTime(customStart.year, customStart.month, customStart.day);
        final end = DateTime(
            customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
        final span = end.difference(start);
        final prevEnd = start.subtract(const Duration(seconds: 1));
        final prevStart = prevEnd.subtract(span);
        return (prevStart, prevEnd);
      }
      // Fallback to same as last30Days comparison
      final currentStart = todayStart.subtract(const Duration(days: 29));
      final prevEnd = currentStart.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      return (prevStart, prevEnd);
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
