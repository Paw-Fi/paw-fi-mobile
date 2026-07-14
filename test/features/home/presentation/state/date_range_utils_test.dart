import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';

void main() {
  group('getDateRangeFromFilter financial cycles', () {
    test('thisMonth uses the active financial cycle to date', () {
      final range = getDateRangeFromFilter(
        DateRangeFilter.thisMonth,
        null,
        null,
        now: DateTime(2026, 8, 10, 14),
        financialMonthStartDay: 25,
      );

      expect(range['from'], DateTime(2026, 7, 25));
      expect(range['to'], DateTime(2026, 8, 10));
    });

    test('lastMonth uses the previous complete financial cycle', () {
      final range = getDateRangeFromFilter(
        DateRangeFilter.lastMonth,
        null,
        null,
        now: DateTime(2026, 8, 10),
        financialMonthStartDay: 25,
      );

      expect(range['from'], DateTime(2026, 6, 25));
      expect(range['to'], DateTime(2026, 7, 24));
    });

    test('last3Months starts two cycles before the active financial cycle', () {
      final range = getDateRangeFromFilter(
        DateRangeFilter.last3Months,
        null,
        null,
        now: DateTime(2026, 8, 10),
        financialMonthStartDay: 25,
      );

      expect(range['from'], DateTime(2026, 5, 25));
      expect(range['to'], DateTime(2026, 8, 10));
    });

    test('non-month presets ignore the financial cycle setting', () {
      final range = getDateRangeFromFilter(
        DateRangeFilter.last7Days,
        null,
        null,
        now: DateTime(2026, 8, 10),
        financialMonthStartDay: 25,
      );

      expect(range['from'], DateTime(2026, 8, 4));
      expect(range['to'], DateTime(2026, 8, 10));
    });
  });
}
