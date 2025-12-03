import 'package:flutter/material.dart';
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
        return Colors.green.shade600;
      case AppToastType.warning:
        return Colors.orange.shade600;
      case AppToastType.error:
        return colorScheme.error;
      case AppToastType.info:
        return colorScheme.primary;
    }
  }

  static IconData _getIconForType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle;
      case AppToastType.warning:
        return Icons.warning;
      case AppToastType.error:
        return Icons.error;
      case AppToastType.info:
        return Icons.info;
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
    final color = _getColorForType(type, effectiveContext);
    final icon = _getIconForType(type);

    // Create overlay entry with animation
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        color: color,
        icon: icon,
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
      debugPrint('AppToast: No mounted context available; action toast dropped.');
      return;
    }

    final overlay = _resolveOverlayState(effectiveContext);
    if (overlay == null) {
      _showMaterialBannerFallback(effectiveContext, message, type, duration);
      return;
    }
    final color = _getColorForType(type, effectiveContext);
    final icon = _getIconForType(type);

    // Create overlay entry with animation and action button
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        color: color,
        icon: icon,
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

    final rootContext = WidgetsBinding.instance.renderViewElement;
    if (rootContext != null && rootContext.mounted) return rootContext;

    return null;
  }

  static bool _hasMaterialLocalizations(BuildContext context) {
    // Use `Localizations.of` for backwards compatibility with Flutter SDKs
    // where `maybeOf` is not available.
    return Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) != null;
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
      debugPrint('AppToast: No Overlay/ScaffoldMessenger or missing MaterialLocalizations; toast dropped.');
      return;
    }

    final color = _getColorForType(type, context);
    final icon = _getIconForType(type);

    _currentMessengerBanner = messenger;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        elevation: 0,
        backgroundColor: color,
        leading: Icon(icon, color: Colors.white),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: _dismissCurrentToast,
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
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
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const _ToastWidget({
    required this.message,
    required this.color,
    required this.icon,
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
      curve: Curves.easeOut,
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

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null &&
                              widget.onActionPressed != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: widget.onActionPressed,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
    );
  }
}
