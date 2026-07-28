import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/shared/widgets/date_period_selector.dart';

void main() {
  testWidgets('disabled future period has no tap action', (tester) async {
    var selections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.daily,
            selectedDate: DateTime(2026, 7, 26),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 1,
            onDateSelected: (_) => selections += 1,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Jul 27, unavailable'));
    expect(selections, 0);
  });

  testWidgets('tapping a valid day invokes callback once', (tester) async {
    final selections = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.daily,
            selectedDate: DateTime(2026, 7, 26),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 1,
            onDateSelected: selections.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Jul 25'));
    expect(selections, [DateTime(2026, 7, 25)]);
  });

  testWidgets(
      'supports bidirectional dragging and snaps to 7-day page boundary',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: DatePeriodSelector(
              mode: HomePeriodMode.daily,
              selectedDate: DateTime(2026, 7, 26),
              now: DateTime(2026, 7, 26),
              financialMonthStartDay: 1,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable);
    expect(listFinder, findsOneWidget);

    final state = tester.state(listFinder);
    final scrollPosition = (state as ScrollableState).position;
    final pageExtent = 350.0; // 7 items * 50px

    final initialOffset = scrollPosition.pixels;

    // Drag right (swipe right) beyond half-page to snap to previous 7-day page
    await tester.drag(listFinder, const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(scrollPosition.pixels, initialOffset - pageExtent);

    // Drag left (swipe left) beyond half-page to snap back to original 7-day page
    await tester.drag(listFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(scrollPosition.pixels, initialOffset);

    // Drag left (swipe left) to Page 1 (future 7 days)
    await tester.drag(listFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(scrollPosition.pixels, initialOffset + pageExtent);

    // Attempting to drag left again cannot advance past Page 1 (maxScrollExtent)
    await tester.drag(listFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(scrollPosition.pixels, initialOffset + pageExtent);
  });

  testWidgets(
      'monthly mode renders budget percentage status inside circle when status provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.monthly,
            selectedDate: DateTime(2026, 7, 15),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 15,
            statusForPeriod: (period) => const DatePeriodRingStatus(
              progress: 0.7,
              color: Colors.amber,
              percentage: 70,
            ),
            onDateSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('70%'), findsWidgets);
  });

  testWidgets(
      'monthly mode renders zero percent instead of the cycle start day',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.monthly,
            selectedDate: DateTime(2026, 7, 1),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 1,
            statusForPeriod: (_) => const DatePeriodRingStatus(
              progress: 0,
              color: Colors.grey,
              percentage: 0,
            ),
            onDateSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('0%'), findsWidgets);
    expect(find.text('1'), findsNothing);
  });

  testWidgets(
      'reports the snapped seven-period viewport independently of selection',
      (tester) async {
    List<DateTime>? visiblePeriods;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.monthly,
            selectedDate: DateTime(2026, 3, 1),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 1,
            onVisiblePeriodsChanged: (periods) => visiblePeriods = periods,
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(visiblePeriods, hasLength(7));
    expect(visiblePeriods, contains(DateTime(2026, 7, 1)));
  });
}
