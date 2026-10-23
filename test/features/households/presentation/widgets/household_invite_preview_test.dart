import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/households/presentation/widgets/household_invite_preview.dart';
import 'package:moneko/l10n/app_localizations.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  group('householdInviteCalendarDaysUntil', () {
    test('counts local calendar days, not 24-hour periods', () {
      final lateEvening = DateTime(2026, 3, 9, 23, 0);
      expect(
        householdInviteCalendarDaysUntil(DateTime(2026, 3, 10, 1, 0),
            now: lateEvening),
        1,
      );
      expect(
        householdInviteCalendarDaysUntil(DateTime(2026, 3, 9, 23, 59),
            now: lateEvening),
        0,
      );
      expect(
        householdInviteCalendarDaysUntil(DateTime(2026, 3, 16, 0, 30),
            now: lateEvening),
        7,
      );
    });

    test('is stable across a daylight-saving boundary', () {
      expect(
        householdInviteCalendarDaysUntil(DateTime(2026, 3, 9, 12),
            now: DateTime(2026, 3, 7, 12)),
        2,
      );
      expect(
        householdInviteCalendarDaysUntil(DateTime(2026, 11, 2, 12),
            now: DateTime(2026, 10, 31, 12)),
        2,
      );
    });
  });

  test('fromValidation converts the UTC expiry to local time', () {
    final preview = HouseholdInvitePreviewData.fromValidation(
      {
        'household': {'name': 'Home'},
        'expires_at': '2026-03-10T01:30:00.000Z',
      },
      fallbackHouseholdName: 'Household',
      fallbackInviterLabel: 'Unknown',
    );
    final expected = DateTime.utc(2026, 3, 10, 1, 30).toLocal();
    expect(preview.expiresAt, expected);
    expect(preview.expiresAt!.isUtc, isFalse);
  });

  testWidgets('formats relative and absolute local dates', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      }),
    ));
    final now = DateTime(2026, 3, 9, 23, 0);
    String format(DateTime date) =>
        formatHouseholdInviteDate(context, date, now: now);

    expect(format(DateTime(2026, 3, 9, 23, 30)), _english.today);
    expect(format(DateTime(2026, 3, 10, 1, 0)), _english.tomorrow);
    expect(format(DateTime(2026, 3, 12, 8, 0)), _english.inDays(3));
    expect(format(DateTime(2026, 4, 2, 8, 0)), '${_english.april} 2, 2026');
  });
}
