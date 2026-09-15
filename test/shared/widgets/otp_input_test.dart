import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/otp_input.dart';

void main() {
  Future<void> pumpOtpInput(
    WidgetTester tester, {
    FocusNode? alternateFocusNode,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OtpInput(onChanged: (_) {}),
              if (alternateFocusNode != null)
                TextField(focusNode: alternateFocusNode),
            ],
          ),
        ),
      ),
    );
  }

  FocusNode otpFocusNode(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField).first).focusNode!;
  }

  Future<void> sendLifecycleState(AppLifecycleState state) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      null,
    );
  }

  testWidgets('restores OTP focus after the app resumes', (tester) async {
    await pumpOtpInput(tester);

    await tester.tap(find.byType(OtpInput));
    await tester.pump();
    expect(otpFocusNode(tester).hasFocus, isTrue);

    await sendLifecycleState(AppLifecycleState.inactive);
    otpFocusNode(tester).unfocus();
    await tester.pump();

    await sendLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(otpFocusNode(tester).hasFocus, isTrue);
  });

  testWidgets('does not focus an untouched OTP field after the app resumes',
      (tester) async {
    await pumpOtpInput(tester);

    await sendLifecycleState(AppLifecycleState.inactive);
    await sendLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(otpFocusNode(tester).hasFocus, isFalse);
  });

  testWidgets('does not override a newer focus target after resuming',
      (tester) async {
    final alternateFocusNode = FocusNode();
    addTearDown(alternateFocusNode.dispose);
    await pumpOtpInput(tester, alternateFocusNode: alternateFocusNode);

    await tester.tap(find.byType(OtpInput));
    await tester.pump();
    await sendLifecycleState(AppLifecycleState.inactive);
    otpFocusNode(tester).unfocus();
    await tester.pump();

    await sendLifecycleState(AppLifecycleState.resumed);
    alternateFocusNode.requestFocus();
    await tester.pump();

    expect(alternateFocusNode.hasFocus, isTrue);
    expect(otpFocusNode(tester).hasFocus, isFalse);
  });

  testWidgets('does not restore OTP focus after another interruption',
      (tester) async {
    await pumpOtpInput(tester);

    await tester.tap(find.byType(OtpInput));
    await tester.pump();
    await sendLifecycleState(AppLifecycleState.inactive);
    otpFocusNode(tester).unfocus();
    await tester.pump();

    await sendLifecycleState(AppLifecycleState.resumed);
    await sendLifecycleState(AppLifecycleState.inactive);
    await tester.pump();

    expect(otpFocusNode(tester).hasFocus, isFalse);
  });
}
