import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/profile/presentation/widgets/notification_repair_dialogs.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

Widget _app(Future<DeviceRegistrationResult> Function() repair) => MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    child: const Text('Repair'),
                    onPressed: () => runNotificationRepairWithDialogs(
                        context: context, repair: repair),
                  ))),
    );

void main() {
  testWidgets('blocks dismissal while pending then returns to the page',
      (tester) async {
    final completion = Completer<DeviceRegistrationResult>();
    await tester.pumpWidget(_app(() => completion.future));
    await tester.tap(find.text('Repair'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BlockingProcessingDialog), findsOneWidget);
    expect(find.text('Notification repair diagnostics'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.byType(BlockingProcessingDialog), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(await navigator.maybePop(), isTrue);
    await tester.pump();
    expect(find.byType(BlockingProcessingDialog), findsOneWidget);

    completion.complete(DeviceRegistrationResult.tokenUnavailable);
    await tester.pumpAndSettle();
    expect(find.byType(BlockingProcessingDialog), findsNothing);
    expect(find.text('Notification repair diagnostics'), findsNothing);
    expect(find.text('Repair'), findsOneWidget);
  });

  testWidgets('a synchronous failure dismisses processing and returns failure',
      (tester) async {
    DeviceRegistrationResult? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                  child: const Text('Repair'),
                  onPressed: () async {
                    result = await runNotificationRepairWithDialogs(
                        context: context,
                        repair: () =>
                            throw PlatformException(code: 'native_failure'));
                  },
                ))));
    await tester.tap(find.text('Repair'));
    await tester.pumpAndSettle();
    expect(find.byType(BlockingProcessingDialog), findsNothing);
    expect(result, DeviceRegistrationResult.failed);
  });

  testWidgets('does not pop another route that opens while processing',
      (tester) async {
    final completion = Completer<DeviceRegistrationResult>();
    await tester.pumpWidget(_app(() => completion.future));
    await tester.tap(find.text('Repair'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Another route'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    completion.complete(DeviceRegistrationResult.tokenUnavailable);
    await tester.pumpAndSettle();
    expect(find.text('Another route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Repair'), findsOneWidget);
    expect(find.byType(BlockingProcessingDialog), findsNothing);
  });
}
