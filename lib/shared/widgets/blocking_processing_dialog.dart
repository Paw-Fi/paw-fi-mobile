import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Controller for updating the blocking processing dialog.
class BlockingProcessingController extends ChangeNotifier {
  String _message;
  String? _subMessage;
  bool _allowCancel;
  bool _isCancelled = false;
  DateTime? _startTime;

  BlockingProcessingController({
    required String message,
    String? subMessage,
    bool allowCancel = false,
  })  : _message = message,
        _subMessage = subMessage,
        _allowCancel = allowCancel;

  String get message => _message;
  String? get subMessage => _subMessage;
  bool get allowCancel => _allowCancel;
  bool get isCancelled => _isCancelled;
  DateTime? get startTime => _startTime;

  void updateMessage(String message, {String? subMessage}) {
    _message = message;
    if (subMessage != null) _subMessage = subMessage;
    notifyListeners();
  }

  void updateSubMessage(String? subMessage) {
    _subMessage = subMessage;
    notifyListeners();
  }

  void enableCancel() {
    _allowCancel = true;
    notifyListeners();
  }

  void cancel() {
    _isCancelled = true;
    notifyListeners();
  }

  void markStarted() {
    _startTime = DateTime.now();
  }

  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }
}

/// The outcome shown after a non-blocking processing task settles.
enum ProcessingOverlayOutcome { success, info, error }

/// Owns a non-blocking processing banner shown above the application's routes.
///
/// Unlike [BlockingProcessingDialog], this presentation intentionally does not
/// add a modal barrier. Callers retain the same controller-driven progress
/// updates, while people can continue browsing the app.
class NonBlockingProcessingOverlay {
  NonBlockingProcessingOverlay._({
    required this.controller,
    OverlayEntry? entry,
    required GlobalKey<_NonBlockingProcessingBannerState> bannerKey,
  })  : _entry = entry,
        _bannerKey = bannerKey;

  final BlockingProcessingController controller;
  final GlobalKey<_NonBlockingProcessingBannerState> _bannerKey;
  OverlayEntry? _entry;

  bool get isVisible => _entry != null;

  void complete({
    required String message,
    String? subMessage,
    ProcessingOverlayOutcome outcome = ProcessingOverlayOutcome.success,
  }) {
    if (_entry == null) return;
    _bannerKey.currentState?.complete(
      message: message,
      subMessage: subMessage,
      outcome: outcome,
    );
  }

  void dismiss() {
    if (_entry == null) return;
    final state = _bannerKey.currentState;
    if (state != null) {
      state.dismiss();
      return;
    }
    _remove();
  }

  void _remove() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }
}

/// Shows a compact, non-modal activity banner in the root overlay.
///
/// The banner is intentionally limited to its own visual bounds, so it never
/// prevents navigation or interaction with the rest of the app.
NonBlockingProcessingOverlay showNonBlockingProcessingOverlay({
  required BuildContext context,
  required String message,
  String? subMessage,
  bool showElapsedTime = true,
}) {
  final controller = BlockingProcessingController(
    message: message,
    subMessage: subMessage,
  )..markStarted();
  final entryKey = GlobalKey<_NonBlockingProcessingBannerState>();
  final overlayState = Overlay.maybeOf(context, rootOverlay: true);
  if (overlayState == null) {
    return NonBlockingProcessingOverlay._(
      controller: controller,
      bannerKey: entryKey,
    );
  }
  late final NonBlockingProcessingOverlay overlay;
  final entry = OverlayEntry(
    builder: (_) => _NonBlockingProcessingBanner(
      key: entryKey,
      controller: controller,
      showElapsedTime: showElapsedTime,
      onDismissed: overlay._remove,
    ),
  );
  overlay = NonBlockingProcessingOverlay._(
    controller: controller,
    entry: entry,
    bannerKey: entryKey,
  );
  overlayState.insert(entry);
  return overlay;
}

class _NonBlockingProcessingBanner extends StatefulWidget {
  const _NonBlockingProcessingBanner({
    super.key,
    required this.controller,
    required this.showElapsedTime,
    required this.onDismissed,
  });

  final BlockingProcessingController controller;
  final bool showElapsedTime;
  final VoidCallback onDismissed;

  @override
  State<_NonBlockingProcessingBanner> createState() =>
      _NonBlockingProcessingBannerState();
}

class _NonBlockingProcessingBannerState
    extends State<_NonBlockingProcessingBanner> {
  static const _transitionDuration = Duration(milliseconds: 220);
  static const _completionVisibility = Duration(seconds: 6);

  Timer? _elapsedTimer;
  Timer? _dismissTimer;
  late String _message;
  String? _subMessage;
  int _elapsedSeconds = 0;
  ProcessingOverlayOutcome? _outcome;
  bool _isVisible = false;

  bool get _isProcessing => _outcome == null;

  @override
  void initState() {
    super.initState();
    _message = widget.controller.message;
    _subMessage = widget.controller.subMessage;
    widget.controller.addListener(_onControllerUpdate);
    if (widget.showElapsedTime) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isProcessing) setState(() => _elapsedSeconds++);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _dismissTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted || !_isProcessing) return;
    setState(() {
      _message = widget.controller.message;
      _subMessage = widget.controller.subMessage;
    });
  }

  void complete({
    required String message,
    String? subMessage,
    required ProcessingOverlayOutcome outcome,
  }) {
    if (!mounted || !_isProcessing) return;
    _elapsedTimer?.cancel();
    setState(() {
      _message = message;
      _subMessage = subMessage;
      _outcome = outcome;
    });
    _dismissTimer = Timer(_completionVisibility, dismiss);
  }

  void dismiss() {
    if (!mounted || !_isVisible) return;
    _dismissTimer?.cancel();
    setState(() => _isVisible = false);
    Timer(_transitionDuration, widget.onDismissed);
  }

  String get _elapsedLabel {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final (background, border, accent, icon) = switch (_outcome) {
      ProcessingOverlayOutcome.success => (
          scheme.successSurface,
          scheme.successBorder,
          scheme.success,
          Icons.check_rounded,
        ),
      ProcessingOverlayOutcome.info => (
          scheme.infoSurface,
          scheme.infoBorder,
          scheme.primary,
          Icons.schedule_rounded,
        ),
      ProcessingOverlayOutcome.error => (
          scheme.errorSurface,
          scheme.errorBorder,
          scheme.errorAccent,
          Icons.error_outline_rounded,
        ),
      null => (
          scheme.card,
          scheme.surfaceBorder,
          scheme.primary,
          Icons.auto_awesome_rounded,
        ),
    };
    final duration = reduceMotion ? Duration.zero : _transitionDuration;

    return Positioned(
      top: 0,
      left: 12,
      right: 12,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: _message,
          child: AnimatedSlide(
            duration: duration,
            curve: Curves.easeOutCubic,
            offset: _isVisible ? Offset.zero : const Offset(0, -0.35),
            child: AnimatedOpacity(
              duration: duration,
              curve: Curves.easeOutCubic,
              opacity: _isVisible ? 1 : 0,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _isProcessing
                            ? CircularProgressIndicator(
                                key: const ValueKey('processing-indicator'),
                                strokeWidth: 2.5,
                                color: accent,
                              )
                            : Icon(
                                icon,
                                key: ValueKey(_outcome),
                                color: accent,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Column(
                          key: ValueKey('${_outcome}_$_message$_subMessage'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.foreground,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (_subMessage != null ||
                                (_isProcessing && _elapsedSeconds > 5)) ...[
                              const SizedBox(height: 2),
                              Text(
                                _subMessage ?? 'Working for $_elapsedLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.mutedForeground,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!_isProcessing)
                      IconButton(
                        onPressed: widget.onDismissed,
                        icon: const Icon(Icons.close_rounded),
                        color: scheme.mutedForeground,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlockingProcessingDialog extends StatefulWidget {
  const BlockingProcessingDialog({
    super.key,
    required this.message,
    this.controller,
    this.onCancel,
    this.showElapsedTime = false,
    this.enableCancelAfterSeconds = 30,
  });

  final String message;
  final BlockingProcessingController? controller;
  final VoidCallback? onCancel;
  final bool showElapsedTime;
  final int enableCancelAfterSeconds;

  @override
  State<BlockingProcessingDialog> createState() =>
      _BlockingProcessingDialogState();
}

class _BlockingProcessingDialogState extends State<BlockingProcessingDialog> {
  Timer? _elapsedTimer;
  late String _currentMessage;
  String? _subMessage;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.controller?.message ?? widget.message;
    _subMessage = widget.controller?.subMessage;

    widget.controller?.addListener(_onControllerUpdate);
    widget.controller?.markStarted();

    if (widget.showElapsedTime || widget.enableCancelAfterSeconds > 0) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsedSeconds++;
        });
      });
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    widget.controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {
      _currentMessage = widget.controller!.message;
      _subMessage = widget.controller!.subMessage;
    });
  }

  String _formatElapsed() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: colorScheme.appBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/gifs/loading-anim.gif',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            Text(
              _currentMessage,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _subMessage!,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.showElapsedTime && _elapsedSeconds > 5) ...[
              const SizedBox(height: 8),
              Text(
                _formatElapsed(),
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a simple blocking dialog (legacy API for backward compatibility)
void showBlockingProcessingDialog({
  required BuildContext context,
  required String message,
}) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BlockingProcessingDialog(
        message: message,
      ),
    ),
  );
}

/// Shows an enhanced blocking dialog with progress updates and timeout handling.
/// Returns the controller for updating the dialog state.
BlockingProcessingController showEnhancedBlockingDialog({
  required BuildContext context,
  required String message,
  String? subMessage,
  VoidCallback? onCancel,
  bool showElapsedTime = true,
  int enableCancelAfterSeconds = 30,
}) {
  final controller = BlockingProcessingController(
    message: message,
    subMessage: subMessage,
  );

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BlockingProcessingDialog(
        message: message,
        controller: controller,
        onCancel: onCancel,
        showElapsedTime: showElapsedTime,
        enableCancelAfterSeconds: enableCancelAfterSeconds,
      ),
    ),
  );

  return controller;
}
