import 'package:hooks_riverpod/hooks_riverpod.dart';

enum HomePageCommandType {
  showLogExpenseDrawer,
}

class HomePageCommand {
  const HomePageCommand(this.type, {this.requestId = 0});

  final HomePageCommandType type;
  final int requestId;
}

final homePageCommandProvider = StateProvider<HomePageCommand?>((ref) => null);
