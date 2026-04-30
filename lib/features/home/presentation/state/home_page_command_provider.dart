import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';

enum HomePageCommandType {
  showLogExpenseDrawer,
  showAiTextInputDrawer,
  captureAiReceipt,
}

class HomePageCommand {
  const HomePageCommand(this.type, {this.requestId = 0});

  final HomePageCommandType type;
  final int requestId;
}

final homePageCommandProvider = StateProvider<HomePageCommand?>((ref) => null);

HomePageCommand? homePageCommandFromWidgetLaunch(
  WidgetLaunchEvent event,
) {
  return switch (event.type) {
    WidgetLaunchActionType.textInput => const HomePageCommand(
        HomePageCommandType.showAiTextInputDrawer,
      ),
    WidgetLaunchActionType.cameraInput => const HomePageCommand(
        HomePageCommandType.captureAiReceipt,
      ),
    _ => null,
  };
}
