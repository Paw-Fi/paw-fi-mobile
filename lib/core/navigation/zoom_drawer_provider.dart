import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/navigation/custom_drawer.dart';

/// Global Drawer controller provider so any widget (e.g. header)
/// can toggle the drawer without tight coupling to MainShell.
final zoomDrawerControllerProvider = Provider<AppDrawerController>((ref) {
  return AppDrawerController();
});
