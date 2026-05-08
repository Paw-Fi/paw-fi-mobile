import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';

Future<void> showTextInputDrawer(
  BuildContext parentContext,
  Future<void> Function(String text) onSubmit, {
  Future<void> Function(Uint8List audioBytes, String contentType)?
      onSubmitAudio,
}) {
  final colorScheme = Theme.of(parentContext).colorScheme;

  return showModalBottomSheet<void>(
    context: parentContext,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: false,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: colorScheme.sheetBackground,
    builder: (modalContext) => _TextInputContent(
      parentContext: parentContext,
      colorScheme: colorScheme,
      onSubmit: onSubmit,
      onSubmitAudio: onSubmitAudio,
    ),
  );
}

class _TextInputContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final ColorScheme colorScheme;
  final Future<void> Function(String text) onSubmit;
  final Future<void> Function(Uint8List audioBytes, String contentType)?
      onSubmitAudio;

  const _TextInputContent({
    required this.parentContext,
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
  final FocusNode _textFocusNode = FocusNode();
  late final TextEditingController _textController;
  double? _keyboardInsetOnRecordStart;

  // Animation for the mic button scale
  late AnimationController _micScaleController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _micScaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _micScaleController.dispose();
    _mockTranscribingTimer?.cancel();
    _recorder.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _processExpense() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppToast.info(widget.parentContext,
          widget.parentContext.l10n.pleaseEnterExpenseDetails);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    if (mounted) {
      await widget.onSubmit(text);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _onRecordStart() async {
    HapticFeedback.heavyImpact();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (widget.parentContext.mounted) {
        AppToast.error(
          widget.parentContext,
          widget.parentContext.l10n.failedToAnalyze,
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      final currentInset = MediaQuery.of(context).viewInsets.bottom;
      _keyboardInsetOnRecordStart =
          currentInset > 0 ? currentInset : _keyboardInsetOnRecordStart;
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
    debugPrint(
        '🎙️ Recording finished. Duration: ${duration.inMilliseconds} ms');

    if (duration.inMilliseconds < 1000) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _isRecording = false;
    });

    final path = await _recorder.stop();
    if (path == null) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingFailed);
      }
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      if (widget.parentContext.mounted) {
        AppToast.error(widget.parentContext,
            widget.parentContext.l10n.recordingFileMissing);
      }
      return;
    }

    final bytes = await file.readAsBytes();
    debugPrint('🎙️ Recording file path: $path');
    debugPrint('🎙️ Recording byte length: ${bytes.length}');
    if (bytes.isEmpty) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingIsEmpty);
      }
      return;
    }

    if (widget.onSubmitAudio != null) {
      await widget.onSubmitAudio!(bytes, 'audio/aac');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
    final rawBottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomInset = MediaQuery.of(context).viewPadding.bottom;
    final minimumBottomPadding = max(20.0, safeBottomInset + 12);
    final effectiveBottomInset = _isRecording
        ? (_keyboardInsetOnRecordStart ?? rawBottomInset)
        : rawBottomInset;

    final String dynamicTitle = context.l10n.addEntry;
    final String placeholder = context.l10n.enterExpenseDetails;

    return Container(
      decoration: BoxDecoration(
        color: scheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
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
          bottom: effectiveBottomInset > 0
              ? effectiveBottomInset
              : minimumBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Sheet Drag Handle
            const ModalSheetHandle(),

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

            // Content Area (Stack to maintain TextField focus/keyboard stability)
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  // TextField always in tree to prevent keyboard dismissal
                  TextField(
                    key: const ValueKey('textField'),
                    controller: _textController,
                    focusNode: _textFocusNode,
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
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.primary),
                      ),
                      filled: true,
                      fillColor: scheme.sheetElementBackground,
                    ),
                  ),

                  // Visualizer Overlay
                  if (_isRecording)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.sheetElementBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _RecordingVisualizer(
                          colorScheme: scheme,
                          recorder: _recorder,
                        ),
                      ),
                    ),
                ],
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
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.onPrimary),
                            ),
                          )
                        : Text(dynamicTitle),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapDown: (_) => _onRecordStart(),
                  onTapUp: (_) => _onRecordEnd(),
                  onTapCancel: () => _onRecordEnd(),
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
  final List<double> _history = List.filled(15, 0.0);
  double _phase = 0;

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

      // Normalize dBFS (-160 to 0)
      // Lower noise floor to -60dB to catch quieter input
      double normalized;

      // Map a practical voice range (around -60dB..-20dB) into 0..1
      const double minDb = -60.0;
      const double maxDb = -20.0;
      final double clampedDb = currentDb.clamp(minDb, maxDb);
      normalized = (clampedDb - minDb) / (maxDb - minDb);

      if (normalized < 0) normalized = 0;
      if (normalized > 1.0) normalized = 1.0;

      debugPrint('🎙️ Amplitude current: $currentDb, normalized: $normalized');

      if (mounted) {
        setState(() {
          _phase += 0.7;
          for (var i = 0; i < _history.length; i++) {
            final angle = ((_phase + i) / _history.length) * 2 * pi;
            final wave = sin(angle).abs(); // 0..1

            // Silence → almost flat, loud voice → tall moving wave
            final double value = 0.005 + (normalized * wave);
            _history[i] = value.clamp(0.005, 1.0);
          }
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
        color: widget.colorScheme.sheetElementBackground,
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
              width: 5,
              // Further lower baseline when silent, still within visual bounds
              height: 16 + (_history[index] * 72),
              decoration: BoxDecoration(
                color: widget.colorScheme.primary
                    .withValues(alpha: 0.8 + (_history[index] * 0.2)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }
}
