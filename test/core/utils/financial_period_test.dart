import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/financial_period.dart';

void main() {
  group('financial cycle math', () {
    test('day 1 preserves calendar month boundaries', () {
      final period = financialCycleForDate(
        DateTime(2026, 8, 10, 14),
        startDay: 1,
      );

      expect(period.start, DateTime(2026, 8, 1));
      expect(period.end, DateTime(2026, 8, 31));
      expect(period.endExclusive, DateTime(2026, 9, 1));
    });

    test('day 25 runs from the 25th through the 24th', () {
      final period = financialCycleForDate(
        DateTime(2026, 8, 10),
        startDay: 25,
      );

      expect(period.start, DateTime(2026, 7, 25));
      expect(period.end, DateTime(2026, 8, 24));
      expect(period.cacheKeySuffix, 'fmsd25_2026-07-25_2026-08-24');
    });

    test('day 31 clamps short months to the last day', () {
      final beforeLeapStart = financialCycleForDate(
        DateTime(2024, 2, 15),
        startDay: 31,
      );
      final onLeapStart = financialCycleForDate(
        DateTime(2024, 2, 29),
        startDay: 31,
      );

      expect(beforeLeapStart.start, DateTime(2024, 1, 31));
      expect(beforeLeapStart.end, DateTime(2024, 2, 28));
      expect(onLeapStart.start, DateTime(2024, 2, 29));
      expect(onLeapStart.end, DateTime(2024, 3, 30));
    });

    test('previous cycle uses the same custom anchor day', () {
      final previous = previousFinancialCycleForDate(
        DateTime(2026, 8, 10),
        startDay: 25,
      );

      expect(previous.start, DateTime(2026, 6, 25));
      expect(previous.end, DateTime(2026, 7, 24));
    });

    test('previous comparison date preserves cycle-to-date progress', () {
      final comparison = matchingElapsedDateInPreviousFinancialCycle(
        DateTime(2026, 8, 10),
        startDay: 25,
      );

      expect(comparison, DateTime(2026, 7, 11));
    });

    test('every supported start day produces continuous cycle boundaries', () {
      for (var startDay = 1; startDay <= 31; startDay++) {
        for (var month = 1; month <= 12; month++) {
          final cycleStart = financialCycleStartForMonth(
            DateTime(2024, month),
            startDay: startDay,
          );
          final nextStart = nextFinancialCycleStart(
            cycleStart,
            startDay: startDay,
          );
          final lastDayInCycle = nextStart.subtract(const Duration(days: 1));

          expect(nextStart.isAfter(cycleStart), isTrue);
          expect(
            financialCycleForDate(
              cycleStart,
              startDay: startDay,
            ).start,
            cycleStart,
          );
          expect(
            financialCycleForDate(
              lastDayInCycle,
              startDay: startDay,
            ).start,
            cycleStart,
          );
          expect(
            financialCycleForDate(
              nextStart,
              startDay: startDay,
            ).start,
            nextStart,
          );
        }
      }
    });

    test('invalid stored start days safely fall back to calendar months', () {
      expect(normalizeFinancialMonthStartDay(null), 1);
      expect(normalizeFinancialMonthStartDay(0), 1);
      expect(normalizeFinancialMonthStartDay(32), 1);
    });
  });
}
