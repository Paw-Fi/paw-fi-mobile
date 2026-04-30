import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/home_page_command_provider.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';

void main() {
  group('homePageCommandFromWidgetLaunch', () {
    test('maps widget text launch to the AI text input drawer command', () {
      final command = homePageCommandFromWidgetLaunch(
        const WidgetLaunchEvent(type: WidgetLaunchActionType.textInput),
      );

      expect(command?.type, HomePageCommandType.showAiTextInputDrawer);
    });

    test('maps widget camera launch to the AI receipt capture command', () {
      final command = homePageCommandFromWidgetLaunch(
        const WidgetLaunchEvent(type: WidgetLaunchActionType.cameraInput),
      );

      expect(command?.type, HomePageCommandType.captureAiReceipt);
    });

    test('ignores widget launch actions handled outside the home page', () {
      final command = homePageCommandFromWidgetLaunch(
        const WidgetLaunchEvent(type: WidgetLaunchActionType.openPockets),
      );

      expect(command, isNull);
    });
  });
}
