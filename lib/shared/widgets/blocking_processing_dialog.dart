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
  bool _canCancel = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.controller?.message ?? widget.message;
    _subMessage = widget.controller?.subMessage;
    _canCancel = widget.controller?.allowCancel ?? false;

    widget.controller?.addListener(_onControllerUpdate);
    widget.controller?.markStarted();

    if (widget.showElapsedTime || widget.enableCancelAfterSeconds > 0) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds >= widget.enableCancelAfterSeconds &&
              !_canCancel) {
            _canCancel = true;
            _subMessage ??= 'Taking longer than expected...';
          }
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
      _canCancel = widget.controller!.allowCancel;
    });
  }

  void _handleCancel() {
    widget.controller?.cancel();
    widget.onCancel?.call();
    Navigator.of(context, rootNavigator: true).pop();
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
            if (_canCancel) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: _handleCancel,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: colorScheme.destructive,
                    fontSize: 14,
                  ),
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
      child: BlockingProcessingDialog(message: message),
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
