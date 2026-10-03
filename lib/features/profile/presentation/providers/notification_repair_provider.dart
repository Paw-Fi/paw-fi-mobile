import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

final notificationRepairProvider =
    StateNotifierProvider.autoDispose<NotificationRepairController, bool>(
        (ref) {
  return NotificationRepairController(
    () =>
        ref.read(deviceRegistrationServiceProvider).repairDeviceRegistration(),
  );
});

class NotificationRepairController extends StateNotifier<bool> {
  NotificationRepairController(this._repair) : super(false);

  final Future<DeviceRegistrationResult> Function() _repair;
  Future<DeviceRegistrationResult>? _inFlight;

  Future<DeviceRegistrationResult> repair() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    state = true;
    final future = Future.sync(_repair).whenComplete(() {
      _inFlight = null;
      if (mounted) state = false;
    });
    _inFlight = future;
    return future;
  }
}
