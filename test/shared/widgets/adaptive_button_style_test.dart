import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('button variants match at $brightness text scale $scale',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  PrimaryAdaptiveButton(
                    key: const ValueKey('primary'),
                    onPressed: () {},
                    child: const Text('Copy previous month'),
                  ),
                  PrimaryAdaptiveButton.outlined(
                    key: const ValueKey('outlined'),
                    onPressed: () {},
                    child: const Text('Copy previous month'),
                  ),
                ]),
              ),
            ),
          ),
        ));

        final primary = find.byKey(const ValueKey('primary'));
        final outlined = find.byKey(const ValueKey('outlined'));
        final primaryControl = tester.widget<CupertinoButton>(find.descendant(
            of: primary, matching: find.byType(CupertinoButton)));
        final outlinedControl = tester.widget<CupertinoButton>(find.descendant(
            of: outlined, matching: find.byType(CupertinoButton)));
        expect(outlinedControl.padding, primaryControl.padding);
        expect(primaryControl.padding,
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24));
        expect(outlinedControl.borderRadius, primaryControl.borderRadius);
        expect(primaryControl.borderRadius, BorderRadius.circular(16));
        final outlineDecoration = tester
            .widgetList<DecoratedBox>(find.descendant(
                of: outlined, matching: find.byType(DecoratedBox)))
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .singleWhere((decoration) => decoration.border != null);
        expect(outlineDecoration.borderRadius, primaryControl.borderRadius);
        expect((outlineDecoration.border! as Border).top.width, 1);
        expect(outlinedControl.pressedOpacity, primaryControl.pressedOpacity);
        expect(tester.getSize(outlined), tester.getSize(primary));
        expect(tester.getSize(outlined).width, 760);

        final texts = find.text('Copy previous month');
        final primaryText = tester.widget<RichText>(
            find.descendant(of: texts.at(0), matching: find.byType(RichText)));
        final outlinedText = tester.widget<RichText>(
            find.descendant(of: texts.at(1), matching: find.byType(RichText)));
        expect(outlinedText.text.style?.fontSize,
            primaryText.text.style?.fontSize);
        expect(outlinedText.text.style?.fontWeight,
            primaryText.text.style?.fontWeight);
        expect(outlinedText.text.style?.letterSpacing,
            primaryText.text.style?.letterSpacing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('outlined button handles taps and disables the shared control',
      (tester) async {
    var taps = 0;
    Future<void> render({required bool enabled}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PrimaryAdaptiveButton.outlined(
              onPressed: enabled ? () => taps++ : null,
              child: const Text('Copy'),
            ),
          ),
        ));
    await render(enabled: true);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await render(enabled: false);
    expect(
        tester.widget<CupertinoButton>(find.byType(CupertinoButton)).onPressed,
        isNull);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
