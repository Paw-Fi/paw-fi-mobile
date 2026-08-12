import 'package:flutter/widgets.dart';
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
}
