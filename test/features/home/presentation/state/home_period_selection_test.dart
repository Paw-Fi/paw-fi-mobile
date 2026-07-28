import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';

void main() {
  const financialMonthStartDay = 15;
  final now = DateTime(2026, 7, 26, 12);

  test(
      'daily periods anchor selected day with five prior days and one later day',
      () {
    final periods = homePeriodItems(
      mode: HomePeriodMode.daily,
      selectedDate: DateTime(2026, 7, 21),
      now: now,
      financialMonthStartDay: financialMonthStartDay,
    );

    expect(periods, [
      DateTime(2026, 7, 16),
      DateTime(2026, 7, 17),
      DateTime(2026, 7, 18),
      DateTime(2026, 7, 19),
      DateTime(2026, 7, 20),
      DateTime(2026, 7, 21),
      DateTime(2026, 7, 22),
    ]);
  });

  test(
      'monthly periods use financial cycle starts and include one future cycle',
      () {
    final periods = homePeriodItems(
      mode: HomePeriodMode.monthly,
      selectedDate: DateTime(2026, 7, 15),
      now: now,
      financialMonthStartDay: financialMonthStartDay,
    );

    expect(periods, [
      DateTime(2026, 2, 15),
      DateTime(2026, 3, 15),
      DateTime(2026, 4, 15),
      DateTime(2026, 5, 15),
      DateTime(2026, 6, 15),
      DateTime(2026, 7, 15),
      DateTime(2026, 8, 15),
    ]);
  });

  test('future dates and cycles are disabled', () {
    expect(
      isHomePeriodSelectable(
        DateTime(2026, 7, 27),
        mode: HomePeriodMode.daily,
        now: now,
        financialMonthStartDay: financialMonthStartDay,
      ),
      isFalse,
    );
    expect(
      isHomePeriodSelectable(
        DateTime(2026, 8, 15),
        mode: HomePeriodMode.monthly,
        now: now,
        financialMonthStartDay: financialMonthStartDay,
      ),
      isFalse,
    );
  });

  test('switching historical monthly to daily preserves elapsed cycle position',
      () {
    final selection = convertHomePeriodMode(
      mode: HomePeriodMode.monthly,
      selectedDate: DateTime(2026, 5, 15),
      nextMode: HomePeriodMode.daily,
      now: now,
      financialMonthStartDay: financialMonthStartDay,
    );

    expect(selection, DateTime(2026, 5, 26));
  });

  test('switching the current monthly cycle to daily selects today', () {
    final selection = convertHomePeriodMode(
      mode: HomePeriodMode.monthly,
      selectedDate: DateTime(2026, 7, 15),
      nextMode: HomePeriodMode.daily,
      now: now,
      financialMonthStartDay: financialMonthStartDay,
    );

    expect(selection, DateTime(2026, 7, 26));
  });

  test('monthly selection resolves complete financial cycle', () {
    final range = resolveHomePeriodRange(
      mode: HomePeriodMode.monthly,
      selectedDate: DateTime(2026, 7, 15),
      financialMonthStartDay: financialMonthStartDay,
    );

    expect(range.start, DateTime(2026, 7, 15));
    expect(range.end, DateTime(2026, 8, 14));
  });
}
