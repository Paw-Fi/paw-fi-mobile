import 'package:flutter/material.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

enum AppToastType { info, success, warning, error }

/// AppToast
///
/// Unified toast/notification utility built on shadcn_flutter's `showToast`.
///
/// Why this exists
/// - SnackBar often gets covered by modal bottom sheets or nested scaffolds.
/// - This uses `rootNavigatorKey.currentContext` and the root overlay so toasts
///   always render above everything (like a high z-index), and default to the top.
///
/// Guidelines
/// - Prefer `AppToast.info/success/warning/error()` over `ScaffoldMessenger.showSnackBar`.
/// - When you need an action (Retry), use `AppToast.action(message, actionLabel, onPressed)`.
/// - Keep messages short. Long-running actions should consider a blocking UI instead.
///
/// Examples
///   AppToast.success('Saved!');
///   AppToast.error('Something went wrong');
///   AppToast.action('Failed to sync', actionLabel: 'Retry', onPressed: retryFn);
///
class AppToast {
  static void show(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    shadcnui.showToast(
      context: ctx,
      location: shadcnui.ToastLocation.topCenter,
      builder: (context, overlay) {
        Future.delayed(duration, overlay.close);
        return _buildToast(context, overlay, message, type);
      },
    );
  }

  /// Show a toast with an action button (e.g., Retry)
  static void action(
    String message, {
    required String actionLabel,
    required VoidCallback onPressed,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    shadcnui.showToast(
      context: ctx,
      location: shadcnui.ToastLocation.topCenter,
      builder: (context, overlay) {
        Future.delayed(duration, overlay.close);
        final style = _ToastStyle.of(context, type);
        final card = _ToastCard(
          message: message,
          style: style,
          overlay: overlay,
          trailing: TextButton(
            onPressed: () { try { onPressed(); } finally { overlay.close(); } },
            style: TextButton.styleFrom(
              foregroundColor: style.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            ),
            child: Text(actionLabel),
          ),
        );

        // Subtle motion from top with fade for a crisp, modern feel.
        return _ToastMotion(child: card);
      },
    );
  }

  static Widget _buildToast(
    BuildContext context,
    shadcnui.ToastOverlay overlay,
    String message,
    AppToastType type,
  ) {
    final style = _ToastStyle.of(context, type);
    final card = _ToastCard(
      message: message,
      style: style,
      overlay: overlay,
    );

    return _ToastMotion(child: card);
  }

  static void info(String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(message, type: AppToastType.info, duration: duration);
  static void success(String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(message, type: AppToastType.success, duration: duration);
  static void warning(String message, {Duration duration = const Duration(seconds: 3)}) =>
      show(message, type: AppToastType.warning, duration: duration);
  static void error(String message, {Duration duration = const Duration(seconds: 4)}) =>
      show(message, type: AppToastType.error, duration: duration);
}

/// Internal: cohesive style tokens for a toast instance
class _ToastStyle {
  final Color background;
  final Color border;
  final Color iconColor;
  final Color textColor;
  final Color accent;
  final IconData icon;

  const _ToastStyle({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.textColor,
    required this.accent,
    required this.icon,
  });

  static _ToastStyle of(BuildContext context, AppToastType type) {
    final scheme = shadcnui.Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final status = switch (type) {
      AppToastType.info => AppSurfaceStatus.info,
      AppToastType.success => AppSurfaceStatus.success,
      AppToastType.warning => AppSurfaceStatus.warning,
      AppToastType.error => AppSurfaceStatus.error,
    };

    final base = AppSurface.statusBase(status);
    return _ToastStyle(
      background: AppSurface.tintedBackground(scheme: scheme, base: base, isDark: isDark),
      border: AppSurface.tintedBorder(scheme: scheme, base: base, isDark: isDark),
      iconColor: base,
      textColor: scheme.foreground,
      accent: AppSurface.accent(base),
      icon: switch (type) {
        AppToastType.success => Icons.check_circle,
        AppToastType.warning => Icons.warning_amber_rounded,
        AppToastType.error => Icons.error_outline,
        AppToastType.info => Icons.info_outline,
      },
    );
  }
}

/// Internal: animation wrapper (fade + slight slide from top)
class _ToastMotion extends StatelessWidget {
  final Widget child;
  const _ToastMotion({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 120, end: 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, dx, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, opacity, __) => Opacity(
            opacity: opacity,
            child: Transform.translate(offset: Offset(dx, 0), child: child),
          ),
        );
      },
    );
  }
}

/// Internal: the actual toasty card UI
class _ToastCard extends StatelessWidget {
  final String message;
  final _ToastStyle style;
  final shadcnui.ToastOverlay overlay;
  final Widget? trailing;

  const _ToastCard({
    required this.message,
    required this.style,
    required this.overlay,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 18,
      offset: const Offset(0, 10),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.border, width: 1),
          boxShadow: [shadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon chip
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: style.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(style.icon, color: style.iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            // Message
            Flexible(
              child: Text(
                message,
                style: TextStyle(color: style.textColor, fontSize: 14, height: 1.2),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
