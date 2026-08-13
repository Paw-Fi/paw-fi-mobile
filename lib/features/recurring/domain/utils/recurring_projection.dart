import 'dart:developer' as developer;
import 'dart:math';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

final RegExp _projectedRecurringExpenseIdPattern =
    RegExp(r'^recurring_(.+)_([0-9]{8})$');

String _dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y$m$day';
}

String buildProjectedRecurringExpenseId(
  String recurringTransactionId,
  DateTime occurrenceDate,
) {
  return 'recurring_${recurringTransactionId}_${_dateKey(occurrenceDate)}';
}

String? extractRecurringTransactionIdFromProjectedExpenseId(String expenseId) {
  final match = _projectedRecurringExpenseIdPattern.firstMatch(expenseId);
  return match?.group(1);
}

bool shouldShowRecurringChipForExpense(ExpenseEntry expense) =>
    expense.isRecurring ||
    expense.providerRecurring ||
    expense.parentRecurringId != null ||
    expense.scheduledOccurrenceDate != null ||
    extractRecurringTransactionIdFromProjectedExpenseId(expense.id) != null;

int _clampDayOfMonth(
    {required int year, required int month, required int day}) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return day <= lastDay ? day : lastDay;
}

DateTime _buildDatePreservingTime({
  required DateTime anchor,
  required int year,
  required int month,
  required int day,
}) {
  return DateTime(
    year,
    month,
    day,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
}

DateTime _addMonthsFromAnchor(DateTime anchor, int monthsToAdd) {
  final newMonth = anchor.month + monthsToAdd;
  final newYear = anchor.year + (newMonth - 1) ~/ 12;
  final adjustedMonth = ((newMonth - 1) % 12) + 1;
  final newDay = _clampDayOfMonth(
    year: newYear,
    month: adjustedMonth,
    day: anchor.day,
  );
  return _buildDatePreservingTime(
    anchor: anchor,
    year: newYear,
    month: adjustedMonth,
    day: newDay,
  );
}

DateTime _addYearsFromAnchor(DateTime anchor, int yearsToAdd) {
  final newYear = anchor.year + yearsToAdd;
  final newDay = _clampDayOfMonth(
    year: newYear,
    month: anchor.month,
    day: anchor.day,
  );
  return _buildDatePreservingTime(
    anchor: anchor,
    year: newYear,
    month: anchor.month,
    day: newDay,
  );
}

DateTime _minDate(DateTime a, DateTime? b) {
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime _firstOnOrAfterDayStep({
  required DateTime anchor,
  required DateTime rangeStart,
  required int stepDays,
}) {
  if (stepDays <= 0) return anchor;

  if (!rangeStart.isAfter(anchor)) return anchor;

  final anchorDate = _dateOnly(anchor);
  final startDate = _dateOnly(rangeStart);
  final diffDays = startDate.difference(anchorDate).inDays;
  final offsetDays = diffDays % stepDays;
  final k = offsetDays == 0 ? diffDays : diffDays + (stepDays - offsetDays);
  return anchor.add(Duration(days: k));
}

/// Expands recurring transactions into synthetic [ExpenseEntry] occurrences
/// within [rangeStart, rangeEnd], inclusive.
///
/// Important: The returned entries have `isRecurring=false` so that callers can
/// safely filter out template rows (`ExpenseEntry.isRecurring==true`) while
/// still counting projected recurring occurrences.
List<ExpenseEntry> projectRecurringTransactionsAsExpenseEntries({
  required List<RecurringTransaction> recurringTransactions,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  String? selectedCurrency,
  List<String>? selectedCurrencies,
}) {
  if (rangeEnd.isBefore(rangeStart)) return const <ExpenseEntry>[];

  final currencyFilters = _normalizeCurrencySet(selectedCurrencies) ??
      _normalizeCurrencySet(
        selectedCurrency == null ? null : <String>[selectedCurrency],
      );
  final startDay = _dateOnly(rangeStart);
  final endDay = _dateOnly(rangeEnd);

  final result = <ExpenseEntry>[];
  final now = DateTime.now();

  for (final r in recurringTransactions) {
    if (currencyFilters != null && currencyFilters.isNotEmpty) {
      if (!currencyFilters.contains(r.currency.trim().toUpperCase())) continue;
    }

    final rule = r.recurrenceRule;
    if (rule?.projectionEnabled == false) continue;
    final anchor = (rule?.anchorDate ?? r.date).toLocal();
    final endLocal = rule?.endDate?.toLocal();
    if (endLocal != null && endLocal.isBefore(startDay)) continue;

    final effectiveEnd = _dateOnly(_minDate(endDay, endLocal));
    if (_dateOnly(anchor).isAfter(effectiveEnd)) continue;

    Iterable<DateTime> occurrences() sync* {
      if (rule == null) {
        final d = _dateOnly(r.date.toLocal());
        if (!d.isBefore(startDay) && !d.isAfter(effectiveEnd)) {
          yield d;
        }
        return;
      }

      final freq = rule.frequency.toLowerCase();
      final interval = rule.interval ?? 1;

      switch (freq) {
        case 'daily':
          final stepDays = max(1, interval);
          var current = _firstOnOrAfterDayStep(
            anchor: anchor,
            rangeStart: startDay,
            stepDays: stepDays,
          );
          while (!_dateOnly(current).isAfter(effectiveEnd)) {
            yield _dateOnly(current);
            current = current.add(Duration(days: stepDays));
          }
          return;

        case 'weekly':
          final stepDays = max(1, interval) * 7;
          var current = _firstOnOrAfterDayStep(
            anchor: anchor,
            rangeStart: startDay,
            stepDays: stepDays,
          );
          while (!_dateOnly(current).isAfter(effectiveEnd)) {
            yield _dateOnly(current);
            current = current.add(Duration(days: stepDays));
          }
          return;

        case 'biweekly':
          const stepDays = 14;
          var current = _firstOnOrAfterDayStep(
            anchor: anchor,
            rangeStart: startDay,
            stepDays: stepDays,
          );
          while (!_dateOnly(current).isAfter(effectiveEnd)) {
            yield _dateOnly(current);
            current = current.add(const Duration(days: stepDays));
          }
          return;

        case 'monthly':
          final stepMonths = max(1, interval);
          final monthsBetween = (startDay.year - anchor.year) * 12 +
              (startDay.month - anchor.month);
          var n = monthsBetween <= 0 ? 0 : (monthsBetween ~/ stepMonths);
          var current = _addMonthsFromAnchor(anchor, n * stepMonths);
          while (_dateOnly(current).isBefore(startDay)) {
            n += 1;
            current = _addMonthsFromAnchor(anchor, n * stepMonths);
          }
          while (!_dateOnly(current).isAfter(effectiveEnd)) {
            yield _dateOnly(current);
            n += 1;
            current = _addMonthsFromAnchor(anchor, n * stepMonths);
          }
          return;

        case 'yearly':
          final stepYears = max(1, interval);
          final yearsBetween = startDay.year - anchor.year;
          var n = yearsBetween <= 0 ? 0 : (yearsBetween ~/ stepYears);
          var current = _addYearsFromAnchor(anchor, n * stepYears);
          while (_dateOnly(current).isBefore(startDay)) {
            n += 1;
            current = _addYearsFromAnchor(anchor, n * stepYears);
          }
          while (!_dateOnly(current).isAfter(effectiveEnd)) {
            yield _dateOnly(current);
            n += 1;
            current = _addYearsFromAnchor(anchor, n * stepYears);
          }
          return;

        default:
          final d = _dateOnly(anchor);
          if (!d.isBefore(startDay) && !d.isAfter(effectiveEnd)) {
            yield d;
          }
          return;
      }
    }

    final amountCents = (r.amount * 100).round();
    if (amountCents == 0) continue;

    // Build excluded date keys set for fast lookup
    final excludedKeys = rule != null
        ? rule.excludedDates.map((d) => _dateKey(_dateOnly(d))).toSet()
        : <String>{};

    for (final day in occurrences()) {
      // Skip excluded dates
      if (excludedKeys.contains(_dateKey(day))) continue;
      final ownerUserId =
          (r.userId != null && r.userId!.isNotEmpty) ? r.userId : r.payerUserId;

      result.add(
        ExpenseEntry(
          id: buildProjectedRecurringExpenseId(r.id, day),
          householdId: r.householdId,
          userId: ownerUserId,
          date: day,
          amountCents: amountCents,
          currency: r.currency,
          category: r.category,
          createdAt: now,
          rawText: r.description,
          type: r.type,
          splitGroupId: r.splitGroupId,
          walletId: r.accountId,
          analyticsClass: r.analyticsClass,
          analyticsIsFinal: r.analyticsIsFinal,
          analyticsSpendingMultiplier: r.analyticsSpendingMultiplier,
          analyticsCountsTowardIncome: r.analyticsCountsTowardIncome,
          parentRecurringId: r.id,
          scheduledOccurrenceDate: day,
          isRecurring: false,
        ),
      );
    }
  }

  return result;
}

List<ExpenseEntry> projectUpcomingRecurringTransactionsAsExpenseEntries({
  required List<RecurringTransaction> recurringTransactions,
  required DateTime monthStart,
  required DateTime now,
  int financialMonthStartDay = 1,
  String? selectedCurrency,
  List<String>? selectedCurrencies,
}) {
  final normalizedStartDay =
      normalizeFinancialMonthStartDay(financialMonthStartDay);
  final currentCycleStart = financialCycleStartForDate(
    now,
    startDay: normalizedStartDay,
  );
  final targetMonthStart = financialCycleStartForMonth(
    monthStart,
    startDay: normalizedStartDay,
  );

  if (currentCycleStart != targetMonthStart) {
    return const <ExpenseEntry>[];
  }

  final monthEnd = nextFinancialCycleStart(
    targetMonthStart,
    startDay: normalizedStartDay,
  ).subtract(const Duration(days: 1));
  final rangeStart = targetMonthStart;

  return projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions
        .where((transaction) => transaction.type.toLowerCase() == 'expense')
        .toList(growable: false),
    rangeStart: rangeStart,
    rangeEnd: monthEnd,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
  );
}

List<ExpenseEntry> dedupeProjectedRecurringExpenseEntries({
  required List<ExpenseEntry> projectedExpenses,
  required List<ExpenseEntry> actualExpenses,
}) {
  if (projectedExpenses.isEmpty || actualExpenses.isEmpty) {
    return projectedExpenses;
  }

  final legacyActualKeys = actualExpenses
      .where((expense) => expense.parentRecurringId?.trim().isNotEmpty != true)
      .map(_projectedExpenseComparisonKey)
      .toSet();
  final linkedActualOccurrences = actualExpenses
      .where((expense) => expense.parentRecurringId?.trim().isNotEmpty == true)
      .map(_linkedActualOccurrenceKey)
      .toSet();

  return projectedExpenses.where((expense) {
    final occurrenceKey = _projectedOccurrenceKey(expense);
    if (occurrenceKey != null &&
        linkedActualOccurrences.contains(occurrenceKey)) {
      return false;
    }
    return !legacyActualKeys.contains(_projectedExpenseComparisonKey(expense));
  }).toList(growable: false);
}

List<ExpenseEntry> buildConfirmedOccurrenceSuppressionEntries({
  required String recurringId,
  required Iterable<DateTime> confirmedScheduledDates,
}) =>
    confirmedScheduledDates
        .map(
          (scheduledDate) => ExpenseEntry(
            id: 'occurrence-suppression:$recurringId:${_dateKey(scheduledDate)}',
            date: scheduledDate,
            createdAt: scheduledDate,
            amountCents: 0,
            parentRecurringId: recurringId,
            scheduledOccurrenceDate: scheduledDate,
          ),
        )
        .toList(growable: false);

List<ExpenseEntry> mergeActualExpensesWithProjectedRecurring({
  required List<ExpenseEntry> actualExpenses,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  Iterable<ExpenseEntry> confirmedOccurrenceSuppressionEntries =
      const <ExpenseEntry>[],
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  bool includeFutureOccurrences = true,
  DateTime? now,
}) {
  final normalizedStart = _dateOnly(rangeStart);
  final normalizedEnd = _dateOnly(rangeEnd);
  final today = _dateOnly(now ?? DateTime.now());
  final projectionEnd =
      includeFutureOccurrences ? normalizedEnd : _minDate(normalizedEnd, today);
  final currencyFilters = _normalizeCurrencySet(selectedCurrencies) ??
      _normalizeCurrencySet(
        selectedCurrency == null ? null : <String>[selectedCurrency],
      );
  final scopedActualExpenses = actualExpenses.where((expense) {
    if (currencyFilters == null || currencyFilters.isEmpty) {
      return true;
    }
    final expenseCurrency = expense.currency?.trim().toUpperCase() ?? '';
    return expenseCurrency.isEmpty || currencyFilters.contains(expenseCurrency);
  }).toList(growable: false);
  final filteredActualExpenses = scopedActualExpenses.where((expense) {
    final expenseDay = _dateOnly(expense.date);
    return !expenseDay.isBefore(normalizedStart) &&
        !expenseDay.isAfter(projectionEnd);
  }).toList(growable: false);

  if (recurringTransactions.isEmpty) {
    return filteredActualExpenses;
  }

  if (projectionEnd.isBefore(normalizedStart)) {
    return filteredActualExpenses;
  }

  final projectedExpenses = projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions,
    rangeStart: normalizedStart,
    rangeEnd: projectionEnd,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
  );
  final dedupedProjectedExpenses = dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projectedExpenses,
    actualExpenses: <ExpenseEntry>[
      ...scopedActualExpenses,
      ...confirmedOccurrenceSuppressionEntries,
    ],
  );
  assert(() {
    String identities(Iterable<ExpenseEntry> entries) => entries
        .map(
          (entry) =>
              '${entry.parentRecurringId ?? extractRecurringTransactionIdFromProjectedExpenseId(entry.id) ?? '-'}'
              '@${_dateKey(entry.scheduledOccurrenceDate ?? entry.date)}',
        )
        .take(12)
        .join(',');
    developer.log(
      'merge range=${_dateKey(normalizedStart)}..${_dateKey(normalizedEnd)} '
      'actual=${scopedActualExpenses.length} recurring=${recurringTransactions.length} '
      'projected=${projectedExpenses.length} suppression=${confirmedOccurrenceSuppressionEntries.length} '
      'deduped=${dedupedProjectedExpenses.length} dropped=${projectedExpenses.length - dedupedProjectedExpenses.length} '
      'projectedKeys=[${identities(projectedExpenses)}] '
      'suppressionKeys=[${identities(confirmedOccurrenceSuppressionEntries)}] '
      'actualKeys=[${identities(scopedActualExpenses)}]',
      name: 'RecurringProjection',
    );
    return true;
  }());

  if (dedupedProjectedExpenses.isEmpty) {
    return filteredActualExpenses;
  }

  return <ExpenseEntry>[
    ...filteredActualExpenses,
    ...dedupedProjectedExpenses,
  ];
}

Set<String>? _normalizeCurrencySet(Iterable<String>? currencies) {
  final normalized = currencies
      ?.map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

String _projectedExpenseComparisonKey(ExpenseEntry expense) {
  final currency = expense.currency?.trim().toUpperCase() ?? '';
  final category = expense.category?.trim().toLowerCase() ?? '';
  final householdId = expense.householdId?.trim() ?? '';
  final userId = expense.userId?.trim() ?? '';
  final walletId = expense.walletId?.trim() ?? '';
  final splitGroupId = expense.splitGroupId?.trim() ?? '';
  final description = expense.rawText?.trim().toLowerCase() ?? '';
  return '${_dateKey(_dateOnly(expense.date))}|$currency|$category|${expense.amountCents}|$householdId|$userId|$walletId|$splitGroupId|$description';
}

String _linkedActualOccurrenceKey(ExpenseEntry expense) {
  final occurrenceDate = expense.scheduledOccurrenceDate ?? expense.date;
  return '${expense.parentRecurringId!.trim()}|${_dateKey(_dateOnly(occurrenceDate))}';
}

String? _projectedOccurrenceKey(ExpenseEntry expense) {
  final recurringId = expense.parentRecurringId?.trim().isNotEmpty == true
      ? expense.parentRecurringId!.trim()
      : extractRecurringTransactionIdFromProjectedExpenseId(expense.id);
  if (recurringId == null) return null;
  final occurrenceDate = expense.scheduledOccurrenceDate ?? expense.date;
  return '$recurringId|${_dateKey(_dateOnly(occurrenceDate))}';
}
