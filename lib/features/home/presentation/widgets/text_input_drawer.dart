import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

void showTextInputDrawer(
  BuildContext parentContext,
  TextEditingController textController,
  Future<void> Function(String text) onSubmit, {
  Future<void> Function(Uint8List audioBytes, String contentType)?
      onSubmitAudio,
}) {
  final colorScheme = Theme.of(parentContext).colorScheme;

  showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => _TextInputContent(
      parentContext: parentContext,
      textController: textController,
      colorScheme: colorScheme,
      onSubmit: onSubmit,
      onSubmitAudio: onSubmitAudio,
    ),
  );
}

class _TextInputContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final TextEditingController textController;
  final ColorScheme colorScheme;
  final Future<void> Function(String text) onSubmit;
  final Future<void> Function(Uint8List audioBytes, String contentType)?
      onSubmitAudio;

  const _TextInputContent({
    required this.parentContext,
    required this.textController,
    required this.colorScheme,
    required this.onSubmit,
    this.onSubmitAudio,
  });

  @override
  ConsumerState<_TextInputContent> createState() => _TextInputContentState();
}

class _TextInputContentState extends ConsumerState<_TextInputContent>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _mockTranscribingTimer;
  final AudioRecorder _recorder = AudioRecorder();

  // Animation for the mic button scale
  late AnimationController _micScaleController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _micScaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _micScaleController.dispose();
    _mockTranscribingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _processExpense() async {
    final text = widget.textController.text.trim();
    if (text.isEmpty) {
      AppToast.info(widget.parentContext,
          widget.parentContext.l10n.pleaseEnterExpenseDetails);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    if (mounted) {
      Navigator.pop(context);
      await widget.onSubmit(text);
      widget.textController.clear();
    }
  }

  Future<void> _onRecordStart() async {
    HapticFeedback.heavyImpact();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      AppToast.error(
        widget.parentContext,
        widget.parentContext.l10n.failedToAnalyze,
      );
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
    });
    _micScaleController.forward();

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/moneko_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );
  }

  void _onRecordEnd() async {
    _micScaleController.reverse();
    final startedAt = _recordingStartTime;
    if (startedAt == null) {
      return;
    }

    final duration = DateTime.now().difference(startedAt);

    if (duration.inMilliseconds < 1000) {
      HapticFeedback.heavyImpact(); // Simulate error feedback
      // Short recording error
      setState(() {
        _isRecording = false;
      });
      await _recorder.cancel();
      AppToast.error(context, "Hold longer to record");
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = false;
    });

    final path = await _recorder.stop();
    if (path == null) {
      AppToast.error(widget.parentContext, "Recording failed");
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      AppToast.error(widget.parentContext, "Recording file missing");
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      AppToast.error(widget.parentContext, "Recording is empty");
      return;
    }

    if (widget.onSubmitAudio != null) {
      if (mounted) {
        Navigator.pop(context);
      }
      await widget.onSubmitAudio!(bytes, 'audio/aac');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final String dynamicTitle = context.l10n.addEntry;
    final String placeholder = context.l10n.enterExpenseDetails;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: bottomInset > 0 ? bottomInset : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    dynamicTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Guidance text
            Text(
              context.l10n.describeYourExpense,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

            // Content Area (Swaps between TextField and Audio Visualizer)
            SizedBox(
              height: 120, // Check height consistency
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _isRecording
                    ? _RecordingVisualizer(
                        colorScheme: scheme,
                        recorder: _recorder,
                      )
                    : TextField(
                        key: const ValueKey('textField'),
                        controller: widget.textController,
                        autofocus: true,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: TextStyle(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: scheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: scheme.primary),
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerLow,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Row
            Row(
              children: [
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: _isProcessing ? null : _processExpense,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(dynamicTitle),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onLongPressStart: (_) => _onRecordStart(),
                  onLongPressEnd: (_) => _onRecordEnd(),
                  child: ScaleTransition(
                    scale: _micScaleAnimation,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: _isRecording
                              ? scheme.error // Red when recording
                              : scheme.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (_isRecording)
                              BoxShadow(
                                color: scheme.error.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                          ]),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _isRecording
                            ? scheme.onError
                            : scheme.onPrimaryContainer,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RecordingVisualizer extends StatefulWidget {
  final ColorScheme colorScheme;
  final AudioRecorder recorder;

  const _RecordingVisualizer({
    required this.colorScheme,
    required this.recorder,
  });

  @override
  State<_RecordingVisualizer> createState() => _RecordingVisualizerState();
}

class _RecordingVisualizerState extends State<_RecordingVisualizer> {
  Timer? _timer;
  // Initialize with small values for a "ready" state
  final List<double> _history = List.filled(10, 0.05);

  @override
  void initState() {
    super.initState();
    // Update frequency: 50ms for smoother animation (20fps)
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateAmplitude();
    });
  }

  Future<void> _updateAmplitude() async {
    try {
      final amp = await widget.recorder.getAmplitude();
      final currentDb = amp.current;

      // Normalize dBFS (-160 to 0) to 0.0 - 1.0 range
      // -50dB as noise floor, 0dB as max
      double normalized = (currentDb + 50) / 50;

      // Clamp
      if (normalized < 0) normalized = 0;
      if (normalized > 1.0) normalized = 1.0;

      if (mounted) {
        setState(() {
          _history.removeAt(0);
          _history.add(normalized);
        });
      }
    } catch (e) {
      // Ignore errors when recorder is not ready or disposed
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_history.length, (index) {
            // Visualize history from left to right
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutQuad,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 4 +
                  (_history[index] *
                      96), // Scale height dynamically, min 4, max 100
              decoration: BoxDecoration(
                color: widget.colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }
}
