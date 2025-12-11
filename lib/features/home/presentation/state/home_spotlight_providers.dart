import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';

/// Shared spotlight controller for the Home page tour (FAB + header).
/// This ensures both steps belong to the same tour and advance using
/// the same overlay.
final homeSpotlightControllerProvider =
    Provider<SpotlightTourController>((ref) {
  return SpotlightTourController(tourId: 'home_unified_fab_v1');
});
