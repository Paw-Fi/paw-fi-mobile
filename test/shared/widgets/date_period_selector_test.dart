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
    const pageExtent = 350.0; // 7 items * 50px

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
      'new user stays on current period followed by six disabled periods',
      (tester) async {
    final now = DateTime(2026, 7, 26);
    List<DateTime>? visiblePeriods;

    Widget buildSelector(DateTime? minimumAvailableDate) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: DatePeriodSelector(
              mode: HomePeriodMode.daily,
              selectedDate: now,
              now: now,
              financialMonthStartDay: 1,
              minimumAvailableDate: minimumAvailableDate,
              onVisiblePeriodsChanged: (periods) => visiblePeriods = periods,
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
    }

    // The minimum date can arrive after the selector has restored its initial
    // position, as happens when returning to Home while user data refreshes.
    await tester.pumpWidget(buildSelector(null));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildSelector(now));
    await tester.pumpAndSettle();

    expect(visiblePeriods, hasLength(7));
    expect(visiblePeriods!.first, now);
    expect(visiblePeriods!.last, DateTime(2026, 8, 1));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final settledOffset = scrollable.position.pixels;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, settledOffset);
    expect(find.bySemanticsLabel('Jul 25'), findsNothing);
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

  testWidgets('monthly ring animates progress and color changes',
      (tester) async {
    var ringColor = Colors.amber;

    Widget buildSelector() {
      return MaterialApp(
        home: Scaffold(
          body: DatePeriodSelector(
            mode: HomePeriodMode.monthly,
            selectedDate: DateTime(2026, 7, 1),
            now: DateTime(2026, 7, 26),
            financialMonthStartDay: 1,
            statusForPeriod: (_) => DatePeriodRingStatus(
              progress: 0.7,
              color: ringColor,
              percentage: 70,
            ),
            onDateSelected: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSelector());
    await tester.pump(); // Complete the selector's initial post-frame scroll.
    var indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(indicator.value, 0);

    await tester.pump(const Duration(milliseconds: 225));
    indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(indicator.value, greaterThan(0));
    expect(indicator.value, lessThan(0.7));

    await tester.pumpAndSettle();
    indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(indicator.value, 0.7);
    expect(indicator.color, Colors.amber);

    ringColor = Colors.blue;
    await tester.pumpWidget(buildSelector());
    await tester.pump(const Duration(milliseconds: 225));
    indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(indicator.color, isNot(Colors.amber));
    expect(indicator.color, isNot(Colors.blue));

    await tester.pumpAndSettle();
    indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(indicator.color, Colors.blue);
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
