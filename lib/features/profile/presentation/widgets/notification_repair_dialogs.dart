import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

Future<DeviceRegistrationResult> runNotificationRepairWithDialogs({
  required BuildContext context,
  required Future<DeviceRegistrationResult> Function() repair,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: BlockingProcessingDialog(
        message: context.l10n.notificationRepairProcessing,
        showElapsedTime: true,
      ),
    ),
  );
  navigator.push(route);
  // Attach failure handling immediately, including synchronous plugin failures.
  final task = Future.sync(repair).then(
    (result) => result,
    onError: (Object error) => DeviceRegistrationResult.failed,
  );
  late final DeviceRegistrationResult result;
  try {
    await WidgetsBinding.instance.endOfFrame;
    result = await task;
  } finally {
    if (navigator.mounted && route.isActive) {
      if (route.isCurrent) {
        navigator.pop();
      } else {
        // Never dismiss a different route pushed while the repair was pending.
        navigator.removeRoute(route);
      }
    }
    await route.completed;
  }

  return result;
}
