DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Counts occurrences for a day-based recurrence (daily/weekly/biweekly) within
/// [rangeStart, rangeEnd], inclusive.
///
/// [anchor] is the first occurrence datetime. The returned occurrences preserve
/// anchor's time-of-day for comparisons.
int countOccurrencesByDayStep({
  required DateTime anchor,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required int stepDays,
}) {
  if (stepDays <= 0) return 0;
  if (rangeEnd.isBefore(rangeStart)) return 0;

  // If the anchor itself is after the range, nothing can match.
  if (anchor.isAfter(rangeEnd)) return 0;

  // Align using date-only arithmetic to avoid off-by-one from time-of-day.
  final anchorDate = _dateOnly(anchor);
  final startDate = _dateOnly(rangeStart);

  DateTime first;
  if (!rangeStart.isAfter(anchor)) {
    first = anchor;
  } else {
    final diffDays = startDate.difference(anchorDate).inDays;
    final offsetDays = diffDays % stepDays;
    final k = offsetDays == 0 ? diffDays : diffDays + (stepDays - offsetDays);
    first = anchor.add(Duration(days: k));
  }

  if (first.isAfter(rangeEnd)) return 0;

  final lastDate = _dateOnly(rangeEnd);
  final firstDate = _dateOnly(first);
  final spanDays = lastDate.difference(firstDate).inDays;
  if (spanDays < 0) return 0;

  return 1 + (spanDays ~/ stepDays);
}
