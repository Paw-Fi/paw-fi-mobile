import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/user_timezone.dart';

void main() {
  group('user_timezone utils', () {
    test('parses UTC offsets', () {
      expect(tryParseTimezoneOffsetMinutes('UTC+08:00'), 480);
      expect(tryParseTimezoneOffsetMinutes('UTC-05:30'), -330);
      expect(tryParseTimezoneOffsetMinutes('GMT+01:00'), 60);
    });

    test('falls back for unknown timezone strings', () {
      expect(
        resolveUserTimezoneOffsetMinutes(
          'America/New_York',
          fallbackOffsetMinutes: -300,
        ),
        -300,
      );
    });

    test('effectiveNow uses device local time in device mode', () {
      final expected = DateTime.now().toLocal();
      final actual = effectiveNow(preferredTimezone: null);
      final deltaSeconds = actual.difference(expected).inSeconds.abs();
      expect(deltaSeconds < 2, isTrue);
    });

    test('effective timezone conversion round-trips with fixed offset', () {
      const preferredTimezone = 'UTC-05:00';
      final utcInstant = DateTime.utc(2026, 2, 10, 15, 30);

      final wall = toEffectiveWallTime(
        utcOrLocalInstant: utcInstant,
        preferredTimezone: preferredTimezone,
      );
      expect(wall.year, 2026);
      expect(wall.month, 2);
      expect(wall.day, 10);
      expect(wall.hour, 10);
      expect(wall.minute, 30);

      final backToUtc = utcInstantFromEffectiveLocalDateTime(
        localDateTimeWall: wall,
        preferredTimezone: preferredTimezone,
      );
      expect(backToUtc.toIso8601String(), utcInstant.toIso8601String());
    });

    test('parses date-only strings safely', () {
      final parsed = tryParseDateOnlyYmd('2026-02-10');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 2);
      expect(parsed.day, 10);
      expect(tryParseDateOnlyYmd('2026-02-30'), isNull);
      expect(tryParseDateOnlyYmd('2026-2-10'), isNull);
    });

    test('parseCalendarDateFromFlexibleInput keeps calendar day stable', () {
      final samples = <String>[
        '2026-03-26',
        '2026-03-26T00:00:00.000Z',
        '2026-03-26T23:59:59.999Z',
        '2026-03-26T00:00:00-07:00',
        '2026-03-26T00:00:00+08:00',
      ];

      for (final raw in samples) {
        final parsed = parseCalendarDateFromFlexibleInput(raw);
        expect(parsed, isNotNull, reason: raw);
        expect(parsed!.year, 2026, reason: raw);
        expect(parsed.month, 3, reason: raw);
        expect(parsed.day, 26, reason: raw);
      }
    });

    test('builds UTC instant for user local midnight', () {
      final utcMidnightForSg = utcInstantForUserLocalMidnight(
        localDate: DateTime(2026, 2, 10),
        offsetMinutes: 480,
      );
      expect(utcMidnightForSg.toIso8601String(), '2026-02-09T16:00:00.000Z');
    });

    test('combines user date and user time', () {
      // 2026-02-10 in UTC+8 should stay on the same user date while taking
      // time components from timeSource in that timezone.
      final combined = combineUserDateWithUserTime(
        date: DateTime.utc(2026, 2, 9, 16),
        timeSource: DateTime.utc(2026, 2, 10, 6, 25),
        offsetMinutes: 480,
      );
      expect(combined.year, 2026);
      expect(combined.month, 2);
      expect(combined.day, 10);
      expect(combined.hour, 14);
      expect(combined.minute, 25);
    });
  });
}
