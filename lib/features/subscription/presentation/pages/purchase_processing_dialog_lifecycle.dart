import 'package:flutter/material.dart';

typedef ProcessingDialogLogger = void Function(Object? message);

void runAfterBuildIfMounted(BuildContext context, VoidCallback callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    callback();
  });
}

void dismissProcessingDialogSafely<T>({
  required BuildContext context,
  required ValueNotifier<bool> dialogOpen,
  required ValueNotifier<T?> dialogKind,
  String? reason,
  ProcessingDialogLogger? logger,
}) {
  logger?.call(
    '🧹 Dismissing processing dialog${reason != null ? " - $reason" : ""} | open=${dialogOpen.value} mounted=${context.mounted}',
  );

  if (!dialogOpen.value) return;

  dialogOpen.value = false;
  dialogKind.value = null;

  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  final canPop = navigator.canPop();
  logger?.call('🧭 root nav canPop=$canPop');

  if (canPop) {
    navigator.pop();
  } else {
    logger?.call('⚠️ No route to pop for processing dialog');
  }
}
