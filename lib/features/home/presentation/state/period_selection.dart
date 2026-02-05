import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';

enum PeriodSelectionKind {
  preset,
  month,
  custom,
}

class PeriodSelection {
  final PeriodSelectionKind kind;
  final DateRangeFilter? preset;
  final DateTime? month;
  final DateTime? customStart;
  final DateTime? customEnd;

  const PeriodSelection._({
    required this.kind,
    this.preset,
    this.month,
    this.customStart,
    this.customEnd,
  });

  factory PeriodSelection.preset(DateRangeFilter preset) {
    return PeriodSelection._(kind: PeriodSelectionKind.preset, preset: preset);
  }

  factory PeriodSelection.month(DateTime month) {
    final normalized = DateTime(month.year, month.month, 1);
    return PeriodSelection._(
        kind: PeriodSelectionKind.month, month: normalized);
  }

  factory PeriodSelection.custom(DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return PeriodSelection._(
      kind: PeriodSelectionKind.custom,
      customStart: normalizedStart,
      customEnd: normalizedEnd,
    );
  }
}

class PeriodDateRange {
  final DateTime start;
  final DateTime end;

  const PeriodDateRange({required this.start, required this.end});
}

PeriodDateRange resolvePeriodDateRange(
  PeriodSelection selection, {
  DateTime? now,
}) {
  switch (selection.kind) {
    case PeriodSelectionKind.month:
      final month = selection.month ?? DateTime.now();
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      return PeriodDateRange(start: start, end: end);
    case PeriodSelectionKind.custom:
      final start = selection.customStart ?? DateTime.now();
      final end = selection.customEnd ?? start;
      return PeriodDateRange(start: start, end: end);
    case PeriodSelectionKind.preset:
      final preset = selection.preset ?? DateRangeFilter.thisMonth;
      final range = getDateRangeFromFilter(preset, null, null, now: now);
      return PeriodDateRange(start: range['from']!, end: range['to']!);
  }
}
