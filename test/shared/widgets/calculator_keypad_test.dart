import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';

void main() {
  for (final scenario in [
    (initial: '', keys: ['-', '1', '0', '0'], expected: '-100'),
    (initial: '-100', keys: <String>[], expected: '-100'),
    (initial: '100', keys: ['-', '2', '5'], expected: '75'),
    (initial: '-100', keys: ['+', '5', '0'], expected: '-50'),
    (initial: '100', keys: ['+', '5', '0', '+'], expected: '150'),
    (initial: '', keys: ['-'], expected: '0'),
    (initial: '', keys: ['-', '1', 'AC', '2', '5'], expected: '25'),
    (initial: '', keys: ['-', '1', 'backspace'], expected: '0'),
    (
      initial: '',
      keys: ['1', '+', '1', '=', 'backspace', '-', '5'],
      expected: '-5'
    ),
  ]) {
    testWidgets('signed calculator ${scenario.initial} ${scenario.keys}',
        (tester) async {
      String? confirmed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalculatorKeypad(
            initialValue: scenario.initial,
            allowNegative: true,
            onConfirm: (value) => confirmed = value,
          ),
        ),
      ));
      for (final key in scenario.keys) {
        final icon = switch (key) {
          '-' => Icons.remove,
          '+' => Icons.add,
          'AC' => Icons.refresh,
          'backspace' => Icons.backspace_outlined,
          _ => null,
        };
        await tester
            .tap(icon == null ? find.text(key).last : find.byIcon(icon));
        await tester.pump();
      }
      await tester.tap(find.byIcon(Icons.check));
      expect(confirmed, scenario.expected);
    });
  }

  for (final locale in [const Locale('en'), const Locale('de')]) {
    testWidgets('signed fractional entry retains its sign in $locale',
        (tester) async {
      String? confirmed;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: CalculatorKeypad(
            allowNegative: true,
            onConfirm: (value) => confirmed = value,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.text(locale.languageCode == 'de' ? ',' : '.'));
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text(locale.languageCode == 'de' ? '-0,5' : '-0.5'),
          findsOneWidget);
      await tester.tap(find.byIcon(Icons.check));
      expect(confirmed, '-0.5');
    });
  }

  for (final initial in ['100', '-100']) {
    testWidgets('confirming a trailing operator preserves $initial',
        (tester) async {
      String? confirmed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalculatorKeypad(
            initialValue: initial,
            onConfirm: (value) => confirmed = value,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.check));
      expect(confirmed, initial);
    });
  }
}
