import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/profile/presentation/providers/notification_repair_provider.dart';

void main() {
  test('pending is immediate and overlapping actions share one attempt',
      () async {
    final completion = Completer<DeviceRegistrationResult>();
    var calls = 0;
    final controller = NotificationRepairController(() {
      calls++;
      return completion.future;
    });
    addTearDown(controller.dispose);
    expect(controller.state, isFalse);
    final first = controller.repair();
    final second = controller.repair();
    expect(controller.state, isTrue);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    completion.complete(DeviceRegistrationResult.registered);
    expect(await first, DeviceRegistrationResult.registered);
    expect(controller.state, isFalse);
  });

  test('failure clears pending and allows another repair', () async {
    var calls = 0;
    final controller = NotificationRepairController(() async {
      if (++calls == 1) throw StateError('Platform unavailable');
      return DeviceRegistrationResult.registered;
    });
    addTearDown(controller.dispose);
    await expectLater(controller.repair(), throwsStateError);
    expect(controller.state, isFalse);
    expect(await controller.repair(), DeviceRegistrationResult.registered);
  });

  test('finishing after provider disposal does not publish stale state',
      () async {
    final completion = Completer<DeviceRegistrationResult>();
    final controller = NotificationRepairController(() => completion.future);
    final repair = controller.repair();
    controller.dispose();
    completion.complete(DeviceRegistrationResult.registered);
    expect(await repair, DeviceRegistrationResult.registered);
  });
}
