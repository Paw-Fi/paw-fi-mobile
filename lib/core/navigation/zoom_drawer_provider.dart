import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Global ZoomDrawer controller provider so any widget (e.g. header)
/// can toggle the drawer without tight coupling to MainShell.
final zoomDrawerControllerProvider = Provider<ZoomDrawerController>((ref) {
  return ZoomDrawerController();
});
