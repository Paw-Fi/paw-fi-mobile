import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/utils/export_date_range.dart';

void main() {
  test('isDateInExportRange includes start and end dates', () {
    final range = DateTimeRange(
      start: DateTime(2026, 4),
      end: DateTime(2026, 4, 21),
    );

    expect(isDateInExportRange(DateTime(2026, 4), range), isTrue);
    expect(isDateInExportRange(DateTime(2026, 4, 21, 23, 59), range), isTrue);
  });

  test('isDateInExportRange excludes dates outside the selected range', () {
    final range = DateTimeRange(
      start: DateTime(2026, 4, 10),
      end: DateTime(2026, 4, 20),
    );

    expect(isDateInExportRange(DateTime(2026, 4, 9, 23, 59), range), isFalse);
    expect(isDateInExportRange(DateTime(2026, 4, 21), range), isFalse);
  });

  test('formatExportDateRange uses stable yyyy-MM-dd bounds', () {
    final range = DateTimeRange(
      start: DateTime(2026, 4, 1),
      end: DateTime(2026, 4, 21),
    );

    expect(formatExportDateRange(range), '2026-04-01..2026-04-21');
  });
}
