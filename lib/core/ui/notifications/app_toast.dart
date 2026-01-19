import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'dart:async';

enum AppToastType { info, success, warning, error }

/// AppToast
///
/// Unified toast/notification utility using Overlay for guaranteed top-level display.
///
/// - Uses Overlay to ensure toasts appear above ALL content including bottom sheets
/// - Appears at the top of the screen with slide-in animation
/// - Automatically dismisses after duration
/// - Prefer `AppToast.info/success/warning/error()` over manual implementations
class AppToast {
  static OverlayEntry? _currentToast;
  static Timer? _dismissTimer;
  static ScaffoldMessengerState? _currentMessengerBanner;

  static Color _getColorForType(AppToastType type, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case AppToastType.success:
        return colorScheme.success;
      case AppToastType.warning:
        return colorScheme.warning;
      case AppToastType.error:
        return colorScheme.destructive;
      case AppToastType.info:
        return colorScheme.info;
    }
  }

  static IconData _getIconForType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.warning:
        return Icons.warning_rounded;
      case AppToastType.error:
        return Icons.error_rounded;
      case AppToastType.info:
        return Icons.info_rounded;
    }
  }

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing toast
    _dismissCurrentToast();

    final effectiveContext = _findUsableContext(context);
    if (effectiveContext == null) {
      debugPrint('AppToast: No mounted context available; toast dropped.');
      return;
    }

    // Try to resolve an overlay for the provided context. Using maybeOf avoids
    // a crash when the context does not have an Overlay ancestor (e.g. using a
    // navigatorKey context).
    final overlay = _resolveOverlayState(effectiveContext);
    if (overlay == null) {
      // Fallback to a MaterialBanner at the top of the Scaffold when no overlay
      // is available. This keeps user-visible feedback instead of silently
      // dropping the toast (common during cold start/deep links).
      _showMaterialBannerFallback(effectiveContext, message, type, duration);
      return;
    }

    // Create overlay entry with animation
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
      ),
    );

    _currentToast = entry;

    overlay.insert(entry);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, _dismissCurrentToast);
  }

  static void _dismissCurrentToast() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentToast?.remove();
    _currentToast = null;
    _currentMessengerBanner?.hideCurrentMaterialBanner();
    _currentMessengerBanner = null;
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
    // Dismiss any existing toast
    _dismissCurrentToast();

    final effectiveContext = _findUsableContext(context);
    if (effectiveContext == null) {
      debugPrint(
          'AppToast: No mounted context available; action toast dropped.');
      return;
    }

    final overlay = _resolveOverlayState(effectiveContext);
    if (overlay == null) {
      _showMaterialBannerFallback(effectiveContext, message, type, duration);
      return;
    }

    // Create overlay entry with animation and action button
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        actionLabel: actionLabel,
        onActionPressed: () {
          onPressed();
          _dismissCurrentToast();
        },
      ),
    );

    _currentToast = entry;

    overlay.insert(entry);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, _dismissCurrentToast);
  }

  static void info(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.info, duration: duration);

  static void success(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.success, duration: duration);

  static void warning(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 3)}) =>
      show(context, message, type: AppToastType.warning, duration: duration);

  static void error(BuildContext context, String message,
          {Duration duration = const Duration(seconds: 4)}) =>
      show(context, message, type: AppToastType.error, duration: duration);

  /// Safely resolve an [OverlayState] for the provided [context].
  ///
  /// - Uses [Overlay.maybeOf] to avoid throwing when there is no ancestor
  ///   overlay.
  /// - Falls back to the nearest navigator overlay (covers navigatorKey
  ///   contexts used by deep links and background callbacks).
  static OverlayState? _resolveOverlayState(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) return overlay;

    return Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  }

  static BuildContext? _findUsableContext(BuildContext context) {
    if (context.mounted) return context;

    final rootContext = WidgetsBinding.instance.rootElement;
    if (rootContext != null && rootContext.mounted) return rootContext;

    return null;
  }

  static bool _hasMaterialLocalizations(BuildContext context) {
    // Use `Localizations.of` for backwards compatibility with Flutter SDKs
    // where `maybeOf` is not available.
    return Localizations.of<MaterialLocalizations>(
            context, MaterialLocalizations) !=
        null;
  }

  /// Fallback to a MaterialBanner at the top of the screen when no overlay is
  /// available (e.g. navigatorKey context during app cold start/deep link).
  static void _showMaterialBannerFallback(
    BuildContext context,
    String message,
    AppToastType type,
    Duration duration,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !_hasMaterialLocalizations(context)) {
      debugPrint(
          'AppToast: No Overlay/ScaffoldMessenger or missing MaterialLocalizations; toast dropped.');
      return;
    }

    final color = _getColorForType(type, context);
    final foreground = Theme.of(context).colorScheme.primaryForeground;
    final icon = _getIconForType(type);

    _currentMessengerBanner = messenger;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        elevation: 0,
        backgroundColor: color,
        leading: Icon(icon, color: foreground),
        content: Text(
          message,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: _dismissCurrentToast,
            child: Text('Dismiss', style: TextStyle(color: foreground)),
          ),
        ],
        forceActionsBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    _dismissTimer = Timer(duration, () {
      _dismissCurrentToast();
    });
  }
}

/// Internal widget for toast display with animation
class _ToastWidget extends StatefulWidget {
  final String message;
  final AppToastType type;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    AppToast._dismissCurrentToast();
  }

  (Color bg, Color border, Color icon, IconData iconData) _getThemeProps(
      ColorScheme scheme) {
    switch (widget.type) {
      case AppToastType.success:
        return (
          scheme.successSurface,
          scheme.successBorder,
          scheme.success,
          Icons.check_circle_rounded
        );
      case AppToastType.warning:
        return (
          scheme.warningSurface,
          scheme.warningBorder,
          scheme.warning,
          Icons.warning_rounded
        );
      case AppToastType.error:
        return (
          scheme.errorSurface,
          scheme.errorBorder,
          scheme.destructive,
          Icons.error_rounded
        );
      case AppToastType.info:
        return (
          scheme.infoSurface,
          scheme.infoBorder,
          scheme.info,
          Icons.info_rounded
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bgColor, borderColor, iconColor, iconData) = _getThemeProps(scheme);

    // Determine shadow opacity based on brightness
    final shadowOpacity = scheme.brightness == Brightness.dark ? 0.3 : 0.08;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: const Key('toast_dismissible'),
            direction: DismissDirection.up,
            onDismissed: (direction) {
              _handleDismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow
                                  .withValues(alpha: shadowOpacity),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                iconData,
                                color: iconColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: scheme.foreground,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (widget.actionLabel != null &&
                                  widget.onActionPressed != null) ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: widget.onActionPressed,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.actionLabel!,
                                      style: TextStyle(
                                        color: iconColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
