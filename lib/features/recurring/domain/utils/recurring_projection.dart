import 'dart:math';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y$m$day';
}

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
}) {
  if (rangeEnd.isBefore(rangeStart)) return const <ExpenseEntry>[];

  final currencyFilter = selectedCurrency?.trim().toUpperCase();
  final startDay = _dateOnly(rangeStart);
  final endDay = _dateOnly(rangeEnd);

  final result = <ExpenseEntry>[];
  final now = DateTime.now();

  for (final r in recurringTransactions) {
    if (!r.isActive) continue;
    if (currencyFilter != null && currencyFilter.isNotEmpty) {
      if (r.currency.trim().toUpperCase() != currencyFilter) continue;
    }

    final rule = r.recurrenceRule;
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

    for (final day in occurrences()) {
      final ownerUserId = (r.payerUserId != null && r.payerUserId!.isNotEmpty)
          ? r.payerUserId
          : r.userId;

      result.add(
        ExpenseEntry(
          id: 'recurring_${r.id}_${_dateKey(day)}',
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
          isRecurring: false,
        ),
      );
    }
  }

  return result;
}
