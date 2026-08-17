import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

void main() {
  testWidgets('non-blocking overlay tolerates a context without an Overlay',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox();
          },
        ),
      ),
    );

    final overlay = showNonBlockingProcessingOverlay(
      context: context,
      message: 'Working',
    );

    expect(overlay.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-blocking overlay uses a navigator-key context',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox(),
      ),
    );

    final overlay = showNonBlockingProcessingOverlay(
      context: navigatorKey.currentContext!,
      message: 'Working',
    );
    await tester.pump();

    expect(overlay.isVisible, isTrue);
    expect(find.text('Working'), findsOneWidget);
    overlay.dismiss();
    await tester.pump(const Duration(milliseconds: 220));
  });
}
