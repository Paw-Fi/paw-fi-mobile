import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => MonekoAlertDialog.show(
                context: context,
                title: 'A very long localized title',
                description: 'A very long localized description ' * 12,
                confirmLabel: 'Confirm the long action',
                cancelLabel: 'Cancel the long action',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android dialog remains usable at large text', (tester) async {
    await _pumpDialog(tester, platform: TargetPlatform.android);

    expect(tester.takeException(), isNull);
    expect(find.text('Confirm the long action'), findsOneWidget);
  });

  testWidgets('iOS dialog remains usable at large text', (tester) async {
    await _pumpDialog(tester, platform: TargetPlatform.iOS);

    expect(tester.takeException(), isNull);
    expect(find.text('Confirm the long action'), findsOneWidget);
  });
}
