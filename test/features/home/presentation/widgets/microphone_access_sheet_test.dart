import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/microphone_access_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'explains the denied mic and dismisses on Not now ($brightness)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMicrophoneAccessSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Microphone is off'), findsOneWidget);
      expect(find.textContaining('Settings to log by voice'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Microphone is off')))
            .colorScheme
            .sheetBackground,
        isNotNull,
      );

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(find.text('Microphone is off'), findsNothing);
    });
  }
}
