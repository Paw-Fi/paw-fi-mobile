import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_passcode_prompt.dart';

void main() {
  testWidgets('shows six passcode slots and completes after six digits',
      (tester) async {
    var completedPasscode = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppLockPasscodePrompt(
            title: 'Create passcode',
            subtitle: 'Enter six digits',
            onComplete: (passcode) {
              completedPasscode = passcode;
            },
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('app-lock-passcode-dot-'),
      ),
      findsNWidgets(6),
    );
    expect(find.byType(TextField), findsNothing);

    for (final digit in ['1', '2', '3', '4', '5']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    expect(completedPasscode, isEmpty);

    await tester.tap(find.text('6'));
    await tester.pump();

    expect(completedPasscode, '123456');
  });

  testWidgets('anchors keypad near the bottom of the available height',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: AppLockPasscodePrompt(
              title: 'Unlock Moneko',
              subtitle: 'Enter your passcode',
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );

    final keypadFinder = find.byKey(const ValueKey('app-lock-keypad'));
    final keypadTop = tester.getTopLeft(keypadFinder).dy;
    final keypadBottom = tester.getBottomLeft(keypadFinder).dy;
    final dotsTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('app-lock-passcode-dot-0')),
        )
        .dy;

    expect(keypadBottom, greaterThan(590));
    expect(dotsTop, lessThan(keypadTop));
  });

  testWidgets('fits a compact viewport without scrolling or overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: AppLockPasscodePrompt(
              title: 'Confirm passcode',
              subtitle: 'Enter the same six digits again.',
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byKey(const ValueKey('app-lock-keypad')), findsOneWidget);
  });
}
