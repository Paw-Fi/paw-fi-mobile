import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
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
}
