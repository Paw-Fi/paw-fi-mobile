class FinancialPeriod {
  const FinancialPeriod({
    required this.start,
    required this.end,
    required this.startDay,
  });

  final DateTime start;
  final DateTime end;
  final int startDay;

  DateTime get endExclusive => end.add(const Duration(days: 1));

  String get cacheKeySuffix =>
      'fmsd${startDay}_${formatFinancialPeriodDate(start)}_'
      '${formatFinancialPeriodDate(end)}';
}

int normalizeFinancialMonthStartDay(int? value) {
  if (value == null || value < 1 || value > 31) {
    return 1;
  }
  return value;
}

DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime financialCycleStartForDate(
  DateTime date, {
  int startDay = 1,
}) {
  final normalizedDate = dateOnly(date);
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final thisMonthStart = _cycleStartForYearMonth(
    normalizedDate.year,
    normalizedDate.month,
    normalizedStartDay,
  );
  if (!normalizedDate.isBefore(thisMonthStart)) {
    return thisMonthStart;
  }
  final previousMonth = DateTime(normalizedDate.year, normalizedDate.month - 1);
  return _cycleStartForYearMonth(
    previousMonth.year,
    previousMonth.month,
    normalizedStartDay,
  );
}

DateTime financialCycleStartForMonth(
  DateTime monthAnchor, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  return _cycleStartForYearMonth(
    monthAnchor.year,
    monthAnchor.month,
    normalizedStartDay,
  );
}

FinancialPeriod financialCycleForDate(
  DateTime date, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final start = financialCycleStartForDate(
    date,
    startDay: normalizedStartDay,
  );
  final nextStart = nextFinancialCycleStart(
    start,
    startDay: normalizedStartDay,
  );
  return FinancialPeriod(
    start: start,
    end: nextStart.subtract(const Duration(days: 1)),
    startDay: normalizedStartDay,
  );
}

FinancialPeriod financialCycleForMonth(
  DateTime monthAnchor, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final start = financialCycleStartForMonth(
    monthAnchor,
    startDay: normalizedStartDay,
  );
  final nextStart = nextFinancialCycleStart(
    start,
    startDay: normalizedStartDay,
  );
  return FinancialPeriod(
    start: start,
    end: nextStart.subtract(const Duration(days: 1)),
    startDay: normalizedStartDay,
  );
}

FinancialPeriod previousFinancialCycleForDate(
  DateTime date, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final currentStart = financialCycleStartForDate(
    date,
    startDay: normalizedStartDay,
  );
  final previousStart = previousFinancialCycleStart(
    currentStart,
    startDay: normalizedStartDay,
  );
  return FinancialPeriod(
    start: previousStart,
    end: currentStart.subtract(const Duration(days: 1)),
    startDay: normalizedStartDay,
  );
}

DateTime nextFinancialCycleStart(
  DateTime cycleStart, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final base = DateTime(cycleStart.year, cycleStart.month + 1);
  return _cycleStartForYearMonth(base.year, base.month, normalizedStartDay);
}

DateTime previousFinancialCycleStart(
  DateTime cycleStart, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final base = DateTime(cycleStart.year, cycleStart.month - 1);
  return _cycleStartForYearMonth(base.year, base.month, normalizedStartDay);
}

DateTime addFinancialCycles(
  DateTime cycleStart,
  int cycleDelta, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final base = DateTime(cycleStart.year, cycleStart.month + cycleDelta);
  return _cycleStartForYearMonth(base.year, base.month, normalizedStartDay);
}

DateTime matchingElapsedDateInPreviousFinancialCycle(
  DateTime date, {
  int startDay = 1,
}) {
  final normalizedStartDay = normalizeFinancialMonthStartDay(startDay);
  final currentPeriod = financialCycleForDate(
    date,
    startDay: normalizedStartDay,
  );
  final previousPeriod = previousFinancialCycleForDate(
    date,
    startDay: normalizedStartDay,
  );
  final elapsedDays = dateOnly(date).difference(currentPeriod.start).inDays;
  final previousLengthDays =
      previousPeriod.endExclusive.difference(previousPeriod.start).inDays;
  final clampedElapsedDays =
      elapsedDays.clamp(0, previousLengthDays - 1).toInt();
  return previousPeriod.start.add(Duration(days: clampedElapsedDays));
}

String formatFinancialPeriodDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _cycleStartForYearMonth(int year, int month, int startDay) {
  final base = DateTime(year, month);
  final day = startDay.clamp(1, _lastDayOfMonth(base.year, base.month)).toInt();
  return DateTime(base.year, base.month, day);
}

int _lastDayOfMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}
