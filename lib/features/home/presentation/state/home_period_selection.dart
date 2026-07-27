import 'package:moneko/core/utils/financial_period.dart';

enum HomePeriodMode {
  daily,
  monthly,
}

class HomePeriodDateRange {
  const HomePeriodDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  /// Keeps legacy map-style dashboard consumers readable during migration.
  DateTime? operator [](String key) => switch (key) {
        'from' => start,
        'to' => end,
        _ => null,
      };
}

DateTime normalizeHomePeriodDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

List<DateTime> homePeriodItems({
  required HomePeriodMode mode,
  required DateTime selectedDate,
  required DateTime now,
  required int financialMonthStartDay,
}) {
  final selected = normalizeHomePeriodDate(selectedDate);
  if (mode == HomePeriodMode.daily) {
    return List<DateTime>.generate(
      7,
      (index) => selected.subtract(Duration(days: 5 - index)),
      growable: false,
    );
  }

  final selectedCycle = financialCycleStartForMonth(
    selected,
    startDay: financialMonthStartDay,
  );
  return List<DateTime>.generate(
    7,
    (index) => addFinancialCycles(
      selectedCycle,
      index - 5,
      startDay: financialMonthStartDay,
    ),
    growable: false,
  );
}

bool isHomePeriodSelectable(
  DateTime period, {
  required HomePeriodMode mode,
  required DateTime now,
  required int financialMonthStartDay,
}) {
  final today = normalizeHomePeriodDate(now);
  if (mode == HomePeriodMode.daily) {
    return !normalizeHomePeriodDate(period).isAfter(today);
  }

  final currentCycle = financialCycleStartForDate(
    today,
    startDay: financialMonthStartDay,
  );
  final candidateCycle = financialCycleStartForMonth(
    period,
    startDay: financialMonthStartDay,
  );
  return !candidateCycle.isAfter(currentCycle);
}

DateTime normalizeHomePeriodSelection(
  DateTime selectedDate, {
  required HomePeriodMode mode,
  required DateTime now,
  required int financialMonthStartDay,
}) {
  final today = normalizeHomePeriodDate(now);
  if (mode == HomePeriodMode.daily) {
    final selected = normalizeHomePeriodDate(selectedDate);
    return selected.isAfter(today) ? today : selected;
  }

  final selectedCycle = financialCycleStartForMonth(
    selectedDate,
    startDay: financialMonthStartDay,
  );
  final currentCycle = financialCycleStartForDate(
    today,
    startDay: financialMonthStartDay,
  );
  return selectedCycle.isAfter(currentCycle) ? currentCycle : selectedCycle;
}

DateTime convertHomePeriodMode({
  required HomePeriodMode mode,
  required DateTime selectedDate,
  required HomePeriodMode nextMode,
  required DateTime now,
  required int financialMonthStartDay,
}) {
  final today = normalizeHomePeriodDate(now);
  if (mode == nextMode) {
    return normalizeHomePeriodSelection(
      selectedDate,
      mode: mode,
      now: today,
      financialMonthStartDay: financialMonthStartDay,
    );
  }
  if (nextMode == HomePeriodMode.monthly) {
    return financialCycleStartForDate(
      selectedDate,
      startDay: financialMonthStartDay,
    );
  }

  final selectedCycle = financialCycleStartForMonth(
    selectedDate,
    startDay: financialMonthStartDay,
  );
  final currentCycle = financialCycleStartForDate(
    today,
    startDay: financialMonthStartDay,
  );
  if (selectedCycle == currentCycle) return today;

  final elapsedDays = today.difference(currentCycle).inDays;
  final selectedPeriod = financialCycleForMonth(
    selectedCycle,
    startDay: financialMonthStartDay,
  );
  final candidate = selectedCycle.add(Duration(days: elapsedDays));
  return candidate.isAfter(selectedPeriod.end) ? selectedPeriod.end : candidate;
}

HomePeriodDateRange resolveHomePeriodRange({
  required HomePeriodMode mode,
  required DateTime selectedDate,
  required int financialMonthStartDay,
}) {
  final selected = normalizeHomePeriodDate(selectedDate);
  if (mode == HomePeriodMode.daily) {
    return HomePeriodDateRange(start: selected, end: selected);
  }
  final cycle = financialCycleForMonth(
    selected,
    startDay: financialMonthStartDay,
  );
  return HomePeriodDateRange(start: cycle.start, end: cycle.end);
}
