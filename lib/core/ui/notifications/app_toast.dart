import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

enum AppToastType { info, success, warning, error }

/// AppToast
///
/// Unified toast/notification utility backed by `AdaptiveSnackBar`.
///
/// - Uses `rootNavigatorKey.currentContext` so messages appear above nested
///   navigators.
/// - Prefer `AppToast.info/success/warning/error()` over manual snack bars.
/// - For actions (e.g., Retry), use `AppToast.action(message, actionLabel, onPressed)`.
class AppToast {
  static AdaptiveSnackBarType _mapType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return AdaptiveSnackBarType.success;
      case AppToastType.warning:
        return AdaptiveSnackBarType.warning;
      case AppToastType.error:
        return AdaptiveSnackBarType.error;
      case AppToastType.info:
        return AdaptiveSnackBarType.info;
    }
  }

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) { 
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: _mapType(type),
      duration: duration,
    );
  }

  /// Show a toast with an action button (e.g., Retry)
  static void action(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onPressed,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: _mapType(type),
      duration: duration,
      action: actionLabel,
      onActionPressed: onPressed,
    );
  }

  static void info(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.info, duration: duration);

  static void success(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.success, duration: duration);

  static void warning(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.warning, duration: duration);

  static void error(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) =>
      show(context, message, type: AppToastType.error, duration: duration);
}
