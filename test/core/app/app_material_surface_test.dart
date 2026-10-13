import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/app_material_surface.dart';
import 'package:moneko/core/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Cupertino route supports ink tap and hover dark=$dark',
        (tester) async {
      var taps = 0;
      final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
      final inheritedStyle = theme.textTheme.titleLarge!;
      await tester.pumpWidget(CupertinoApp(
        builder: (context, child) => Theme(
          data: theme,
          child: DefaultTextStyle(
            style: inheritedStyle,
            child: AppMaterialSurface(child: child!),
          ),
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: InkWell(
              onTap: () => taps++,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Receipt'),
              ),
            ),
          ),
        ),
      ));
      final target = find.byType(InkWell);
      final textContext = tester.element(find.text('Receipt'));
      expect(DefaultTextStyle.of(textContext).style, inheritedStyle);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a nearer Material keeps ownership of ink', (tester) async {
    MaterialInkController? nearest;
    MaterialInkController? outer;
    await tester.pumpWidget(MaterialApp(
      home: AppMaterialSurface(
        child: Builder(builder: (context) {
          outer = Material.of(context);
          return Material(
            child: Builder(builder: (context) {
              nearest = Material.of(context);
              return InkWell(onTap: () {}, child: const Text('Tap'));
            }),
          );
        }),
      ),
    ));
    expect(nearest, isNot(same(outer)));
    await tester.tap(find.text('Tap'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
