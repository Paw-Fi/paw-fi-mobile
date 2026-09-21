import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  test('custom interval canonicalizes singular values to null', () {
    final selection = recurrenceSelectionFromCustomInterval(
      unit: RecurrenceIntervalUnit.months,
      number: 1,
    );

    expect(selection.frequency, 'monthly');
    expect(selection.interval, isNull);
  });

  test('custom interval preserves reminder scheduler cadence values', () {
    final selections = [
      recurrenceSelectionFromCustomInterval(
        unit: RecurrenceIntervalUnit.days,
        number: 25,
      ),
      recurrenceSelectionFromCustomInterval(
        unit: RecurrenceIntervalUnit.weeks,
        number: 3,
      ),
      recurrenceSelectionFromCustomInterval(
        unit: RecurrenceIntervalUnit.years,
        number: 2,
      ),
    ];

    expect(
      selections.map((selection) => selection.frequency),
      ['daily', 'weekly', 'yearly'],
    );
    expect(
      selections.map((selection) => selection.interval),
      [25, 3, 2],
    );
  });

  test('custom intervals use the fixed one-to-52 range for every unit', () {
    for (final unit in RecurrenceIntervalUnit.values) {
      expect(clampRecurrenceInterval(0, unit), 1);
      expect(clampRecurrenceInterval(1, unit), 1);
      expect(clampRecurrenceInterval(52, unit), 52);
      expect(clampRecurrenceInterval(53, unit), 52);
    }
  });

  testWidgets('showRecurrencePicker supports every 6 months', (tester) async {
    RecurrenceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  selection = await showRecurrencePicker(
                    context: context,
                    currentFrequency: 'monthly',
                    currentInterval: null,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Every 6 months'), findsOneWidget);

    await tester.tap(find.text('Every 6 months'));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.frequency, 'monthly');
    expect(selection!.interval, 6);
  });

  testWidgets(
      'showRecurrencePicker includes custom and cancellation preserves value',
      (tester) async {
    RecurrenceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showRecurrencePicker(
                  context: context,
                  currentFrequency: 'daily',
                  currentInterval: 25,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('25 days'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(selection, isNull);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selection?.frequency, 'daily');
    expect(selection?.interval, 25);
  });

  testWidgets('custom picker preserves week and year intervals',
      (tester) async {
    RecurrenceSelection? selection;

    Future<void> select({
      required String frequency,
      required int interval,
      required String expectedLabel,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selection = await showRecurrencePicker(
                    context: context,
                    currentFrequency: frequency,
                    currentInterval: interval,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    await select(
      frequency: 'weekly',
      interval: 3,
      expectedLabel: '3 weeks',
    );
    expect(selection?.frequency, 'weekly');
    expect(selection?.interval, 3);

    selection = null;
    await select(
      frequency: 'yearly',
      interval: 2,
      expectedLabel: '2 years',
    );
    expect(selection?.frequency, 'yearly');
    expect(selection?.interval, 2);
  });

  testWidgets('custom picker returns one month as monthly with null interval',
      (tester) async {
    RecurrenceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showRecurrencePicker(
                  context: context,
                  currentFrequency: 'monthly',
                  currentInterval: null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...'));
    await tester.pumpAndSettle();
    expect(find.text('1 month'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selection?.frequency, 'monthly');
    expect(selection?.interval, isNull);
  });

  testWidgets('custom number wheel uses the fixed one-to-52 range',
      (tester) async {
    RecurrenceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showRecurrencePicker(
                  context: context,
                  currentFrequency: 'daily',
                  currentInterval: 400,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('52'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selection?.frequency, 'daily');
    expect(selection?.interval, 52);
  });

  testWidgets('changing from 30 days to years keeps the valid number',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecurrencePicker(
                context: context,
                currentFrequency: 'daily',
                currentInterval: 30,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final wheels = find.byType(ListWheelScrollView);
    expect(wheels, findsNWidgets(2));
    await tester.drag(wheels.last, const Offset(0, -132));
    await tester.pumpAndSettle();

    expect(find.text('30 years'), findsOneWidget);
  });

  testWidgets('confirming unchanged biweekly customizes as two weeks',
      (tester) async {
    RecurrenceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showRecurrencePicker(
                  context: context,
                  currentFrequency: 'biweekly',
                  currentInterval: null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...'));
    await tester.pumpAndSettle();

    expect(find.text('2 weeks'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selection?.frequency, 'weekly');
    expect(selection?.interval, 2);
  });
}
