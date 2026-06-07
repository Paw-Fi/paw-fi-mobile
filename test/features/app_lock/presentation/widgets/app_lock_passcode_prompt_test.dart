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
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }
    expect(completedPasscode, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, '6'));
    await tester.pump();

    expect(completedPasscode, '123456');
  });
}
