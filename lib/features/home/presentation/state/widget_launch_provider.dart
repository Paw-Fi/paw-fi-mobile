import 'package:hooks_riverpod/hooks_riverpod.dart';

enum WidgetLaunchAction {
  none,
  textInput,
  cameraInput,
}

final widgetLaunchProvider =
    StateProvider<WidgetLaunchAction>((ref) => WidgetLaunchAction.none);
