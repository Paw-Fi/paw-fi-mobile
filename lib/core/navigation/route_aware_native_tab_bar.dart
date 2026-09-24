import 'package:flutter/widgets.dart';

/// Keeps a native tab bar mounted without compositing it above popup routes.
class RouteAwareNativeTabBar extends StatelessWidget {
  const RouteAwareNativeTabBar({super.key, required this.builder});

  final Widget Function(bool isTopRoute) builder;

  @override
  Widget build(BuildContext context) {
    final isTopRoute = ModalRoute.isCurrentOf(context) ?? true;
    return Offstage(
      key: const ValueKey('route-aware-native-tab-bar-offstage'),
      offstage: !isTopRoute,
      child: builder(isTopRoute),
    );
  }
}
