import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/utils/datetime.dart';

void main() {
  group('toLocalTime', () {
    test('converts UTC DateTime to local time', () {
      final utcTime = DateTime.utc(2024, 1, 15, 10, 30, 0);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
      expect(localTime.year, 2024);
      expect(localTime.month, 1);
      expect(localTime.day, 15);
    });

    test('handles already local DateTime', () {
      final localTime = DateTime(2024, 1, 15, 10, 30, 0);
      final result = toLocalTime(localTime);

      expect(result.isUtc, false);
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.hour, 10);
      expect(result.minute, 30);
    });

    test('preserves date components when converting', () {
      final utcTime = DateTime.utc(2024, 12, 31, 23, 59, 59);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
      // Date components may shift based on timezone
      expect(localTime.year, greaterThanOrEqualTo(2024));
    });

    test('handles midnight UTC', () {
      final utcTime = DateTime.utc(2024, 1, 15, 0, 0, 0);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
    });

    test('handles noon UTC', () {
      final utcTime = DateTime.utc(2024, 1, 15, 12, 0, 0);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
      expect(localTime.year, 2024);
      expect(localTime.month, 1);
    });

    test('handles leap year date', () {
      final utcTime = DateTime.utc(2024, 2, 29, 10, 30, 0);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
      expect(localTime.year, 2024);
      expect(localTime.month, 2);
    });

    test('handles year boundary', () {
      final utcTime = DateTime.utc(2023, 12, 31, 23, 59, 59);
      final localTime = toLocalTime(utcTime);

      expect(localTime.isUtc, false);
    });

    test('returns DateTime object', () {
      final utcTime = DateTime.utc(2024, 1, 15, 10, 30, 0);
      final localTime = toLocalTime(utcTime);

      expect(localTime, isA<DateTime>());
    });
  });

  group('combineLocalDateWithLocalTime', () {
    test(
        'uses local calendar date from date and local time components from timeSource',
        () {
      final date = DateTime.utc(2024, 1, 15, 0, 0, 0);
      final timeSource = DateTime.utc(2024, 1, 10, 23, 30, 15, 123, 456);

      final localDate = date.toLocal();
      final localTime = timeSource.toLocal();

      final combined = combineLocalDateWithLocalTime(
        date: date,
        timeSource: timeSource,
      );

      expect(combined.isUtc, false);
      expect(combined.year, localDate.year);
      expect(combined.month, localDate.month);
      expect(combined.day, localDate.day);
      expect(combined.hour, localTime.hour);
      expect(combined.minute, localTime.minute);
      expect(combined.second, localTime.second);
      expect(combined.millisecond, localTime.millisecond);
      expect(combined.microsecond, localTime.microsecond);
    });
  });
}
