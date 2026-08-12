import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';

void main() {
  Widget buildSubject(String? selectedHex) {
    return MaterialApp(
      home: Scaffold(
        body: ColorSelectionSwatchRow(
          selectedHex: selectedHex,
          onChanged: (_) {},
          presetColors: const [Color(0xFF112233)],
          sweepColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
          fallbackColor: const Color(0xFF445566),
        ),
      ),
    );
  }

  testWidgets('custom color replaces the leading gradient swatch',
      (tester) async {
    await tester.pumpWidget(buildSubject('#123456'));

    expect(find.byKey(const ValueKey('custom-color-selected')), findsOneWidget);
    final swatch = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.byKey(const ValueKey('custom-color-selected')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
        (swatch.decoration! as BoxDecoration).color, const Color(0xFF123456));
    expect((swatch.decoration! as BoxDecoration).gradient, isNull);
  });

  testWidgets('preset and unset colors retain the leading picker gradient',
      (tester) async {
    await tester.pumpWidget(buildSubject(null));
    expect(find.byKey(const ValueKey('custom-color-picker')), findsOneWidget);

    await tester.pumpWidget(buildSubject('#112233'));
    expect(find.byKey(const ValueKey('custom-color-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('preset-color-selected')), findsOneWidget);
  });
}
