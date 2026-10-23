import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';

const double holdRecordingSilenceFloorDb = -52;
const double holdRecordingLoudCeilingDb = -12;
const double holdRecordingMinimumLevel = 0.06;
const Duration _indicatorTransition = Duration(milliseconds: 200);

/// Maps a dBFS amplitude sample to a 0..1 display level, with a perceptual
/// curve so quiet room noise stays low while normal speech fills the bar.
double normalizeHoldRecordingLevel(double db) {
  if (db.isNaN) return holdRecordingMinimumLevel;
  final linear = ((db - holdRecordingSilenceFloorDb) /
          (holdRecordingLoudCeilingDb - holdRecordingSilenceFloorDb))
      .clamp(0.0, 1.0);
  final shaped = math.pow(linear, 1.35).toDouble();
  return holdRecordingMinimumLevel + shaped * (1 - holdRecordingMinimumLevel);
}

/// Fast attack, slower release so bars feel responsive without flicker.
double smoothHoldRecordingLevel(double previous, double next) {
  final factor = next > previous ? 0.8 : 0.45;
  return previous + (next - previous) * factor;
}

/// Progress toward cancelling for a horizontal drag; only leftward drags
/// (toward the screen centre, away from the FAB) count.
double holdCancelProgress(double deltaX, double threshold) {
  if (threshold <= 0) return 0;
  return (-deltaX / threshold).clamp(0.0, 1.0).toDouble();
}

/// Rolling buffer of live microphone levels, newest last.
class HoldRecordingLevels extends ChangeNotifier {
  HoldRecordingLevels({this.capacity = 64});

  final int capacity;
  final List<double> _levels = <double>[];

  List<double> get levels => List<double>.unmodifiable(_levels);

  double get latest => _levels.isEmpty ? 0 : _levels.last;

  void addDecibels(double db) {
    final raw = normalizeHoldRecordingLevel(db);
    final previous = _levels.isEmpty ? holdRecordingMinimumLevel : _levels.last;
    _levels.add(smoothHoldRecordingLevel(previous, raw));
    if (_levels.length > capacity) _levels.removeAt(0);
    notifyListeners();
  }

  void clear() {
    if (_levels.isEmpty) return;
    _levels.clear();
    notifyListeners();
  }
}

class HoldRecordingIndicator extends StatelessWidget {
  const HoldRecordingIndicator({
    super.key,
    required this.isVisible,
    required this.isRecording,
    required this.isCancelled,
    required this.cancelProgress,
    required this.levels,
    required this.startedAt,
    required this.width,
  });

  final bool isVisible;
  final bool isRecording;
  final bool isCancelled;
  final double cancelProgress;
  final HoldRecordingLevels levels;
  final DateTime? startedAt;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : _indicatorTransition;
    final progress = isCancelled ? 1.0 : cancelProgress;

    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: !isVisible
            ? null
            : isCancelled
                ? context.l10n.canceled
                : context.l10n.slideToCancel,
        child: AnimatedSlide(
          duration: duration,
          curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
          offset: isVisible ? Offset.zero : const Offset(0.12, 0),
          child: AnimatedScale(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerRight,
            scale: isVisible ? 1 : 0.94,
            child: AnimatedOpacity(
              duration: duration,
              opacity: isVisible ? 1 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: width,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    colorScheme.surfaceContainerHigh,
                    colorScheme.errorContainer,
                    isCancelled ? 1 : progress * 0.4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Color.lerp(
                      colorScheme.outlineVariant,
                      colorScheme.error,
                      isCancelled ? 1 : progress * 0.7,
                    )!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isCancelled
                      ? _CancelledContent(
                          key: const ValueKey('cancelled'),
                          reduceMotion: reduceMotion,
                        )
                      : _RecordingContent(
                          key: const ValueKey('recording'),
                          isRecording: isRecording,
                          cancelProgress: progress,
                          levels: levels,
                          startedAt: startedAt,
                          maxHintWidth: width * 0.42,
                          reduceMotion: reduceMotion,
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

class _RecordingContent extends StatelessWidget {
  const _RecordingContent({
    super.key,
    required this.isRecording,
    required this.cancelProgress,
    required this.levels,
    required this.startedAt,
    required this.maxHintWidth,
    required this.reduceMotion,
  });

  final bool isRecording;
  final double cancelProgress;
  final HoldRecordingLevels levels;
  final DateTime? startedAt;
  final double maxHintWidth;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hintOpacity = (1 - cancelProgress * 1.6).clamp(0.0, 1.0).toDouble();

    // The FAB is always pinned to the physical right edge, so cancel always
    // travels leftward regardless of locale direction.
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        _CancelTarget(
          progress: cancelProgress,
          isRecording: isRecording,
          reduceMotion: reduceMotion,
        ),
        const SizedBox(width: 6),
        _ElapsedLabel(startedAt: startedAt, isRunning: isRecording),
        const SizedBox(width: 10),
        Expanded(
          child: Opacity(
            opacity: 1 - cancelProgress * 0.5,
            child: SizedBox(
              height: 24,
              child: CustomPaint(
                painter: _LiveWaveformPainter(
                  levels: levels,
                  color: colorScheme.primary,
                  idleColor: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Transform.translate(
          offset: Offset(-cancelProgress * 48, 0),
          child: Opacity(
            opacity: hintOpacity,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxHintWidth),
              child: _SlideToCancelHint(
                isAnimating: isRecording && !reduceMotion,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulsing record dot that morphs into a growing trash target as the user
/// drags toward cancel.
class _CancelTarget extends StatelessWidget {
  const _CancelTarget({
    required this.progress,
    required this.isRecording,
    required this.reduceMotion,
  });

  final double progress;
  final bool isRecording;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isArming = progress > 0.05;

    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedSwitcher(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: isArming
            ? Transform.scale(
                key: const ValueKey('trash'),
                scale: 0.8 + progress * 0.35,
                child: Transform.rotate(
                  angle: progress > 0.85 ? -0.18 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.error.withValues(
                        alpha: 0.08 + progress * 0.22,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colorScheme.error.withValues(
                          alpha: 0.55 + progress * 0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : _PulsingDot(
                key: const ValueKey('dot'),
                color: colorScheme.error,
                isAnimating: isRecording && !reduceMotion,
              ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({
    super.key,
    required this.color,
    required this.isAnimating,
  });

  final Color color;
  final bool isAnimating;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnimating != widget.isAnimating) _sync();
  }

  void _sync() {
    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: DecoratedBox(
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: widget.color),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
  }
}

/// "‹ Slide to cancel" with a leftward chevron nudge and a light sweep across
/// the label (the classic slide-to-unlock cue) pointing toward the gesture.
class _SlideToCancelHint extends StatefulWidget {
  const _SlideToCancelHint({required this.isAnimating});

  final bool isAnimating;

  @override
  State<_SlideToCancelHint> createState() => _SlideToCancelHintState();
}

class _SlideToCancelHintState extends State<_SlideToCancelHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _SlideToCancelHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnimating != widget.isAnimating) _sync();
  }

  void _sync() {
    if (widget.isAnimating) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.onSurfaceVariant;
    final highlightColor = colorScheme.onSurface;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chevron_left_rounded,
          size: 18,
          color: baseColor,
          textDirection: TextDirection.ltr,
        ),
        Flexible(
          child: Text(
            context.l10n.slideToCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: baseColor,
                ),
          ),
        ),
      ],
    );
    if (!widget.isAnimating) return content;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Chevron-led nudge in the first half, then the sweep catches up.
        final nudge = t < 0.5 ? math.sin(t * 2 * math.pi) : 0.0;
        final sweepX = 1.6 - t * 3.2;
        return Transform.translate(
          offset: Offset(-4 * nudge, 0),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(sweepX - 0.7, 0),
              end: Alignment(sweepX + 0.7, 0),
              colors: [baseColor, highlightColor, baseColor],
            ).createShader(bounds),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

class _ElapsedLabel extends StatefulWidget {
  const _ElapsedLabel({required this.startedAt, required this.isRunning});

  final DateTime? startedAt;
  final bool isRunning;

  @override
  State<_ElapsedLabel> createState() => _ElapsedLabelState();
}

class _ElapsedLabelState extends State<_ElapsedLabel> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ElapsedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning ||
        oldWidget.startedAt != widget.startedAt) {
      _sync();
    }
  }

  void _sync() {
    _ticker?.cancel();
    _tick();
    if (!widget.isRunning) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(_tick);
    });
  }

  void _tick() {
    final startedAt = widget.startedAt;
    _elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.inSeconds;
    final label =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

/// Mic drops into the bin, then the bin gives a short shake.
class _CancelledContent extends StatelessWidget {
  const _CancelledContent({super.key, required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 650),
            builder: (context, t, _) {
              final drop = (t / 0.55).clamp(0.0, 1.0);
              final shake = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
              final dropCurve = Curves.easeInCubic.transform(drop);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: math.sin(shake * math.pi * 4) * 0.22 * (1 - shake),
                    child: Icon(
                      Icons.delete_rounded,
                      size: 20,
                      color: colorScheme.error,
                    ),
                  ),
                  if (drop < 1)
                    Transform.translate(
                      offset: Offset(0, -16 + dropCurve * 16),
                      child: Opacity(
                        opacity: 1 - dropCurve,
                        child: Transform.scale(
                          scale: 1 - dropCurve * 0.6,
                          child: Icon(
                            Icons.mic_rounded,
                            size: 16,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            context.l10n.canceled,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
          ),
        ),
      ],
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({
    required this.levels,
    required this.color,
    required this.idleColor,
  }) : super(repaint: levels);

  static const double _barWidth = 2.6;
  static const double _barGap = 2.2;

  final HoldRecordingLevels levels;
  final Color color;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / (_barWidth + _barGap)).floor();
    if (barCount <= 0) return;
    final samples = levels.levels;
    final visible = samples.length > barCount
        ? samples.sublist(samples.length - barCount)
        : samples;
    final idleCount = barCount - visible.length;
    final activePaint = Paint()..color = color;
    final idlePaint = Paint()..color = idleColor;
    final centerY = size.height / 2;
    const radius = Radius.circular(_barWidth / 2);

    for (var i = 0; i < barCount; i++) {
      final isIdle = i < idleCount;
      final level = isIdle ? holdRecordingMinimumLevel : visible[i - idleCount];
      final height = math.max(3.0, level * size.height);
      final left = i * (_barWidth + _barGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, centerY - height / 2, _barWidth, height),
          radius,
        ),
        isIdle ? idlePaint : activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.color != color ||
      oldDelegate.idleColor != idleColor;
}

/// Two soft rings behind the FAB that swell with the live voice level, so the
/// button under the finger confirms the mic is hearing the user.
class HoldRecordingVoiceHalo extends StatelessWidget {
  const HoldRecordingVoiceHalo({
    super.key,
    required this.levels,
    required this.isActive,
    required this.cancelProgress,
    this.diameter = 56,
  });

  final HoldRecordingLevels levels;
  final bool isActive;
  final double cancelProgress;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final tint = Color.lerp(
      colorScheme.primary,
      colorScheme.error,
      cancelProgress,
    )!;

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isActive ? 1 : 0,
        child: ListenableBuilder(
          listenable: levels,
          builder: (context, _) {
            final level = isActive && !reduceMotion ? levels.latest : 0.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                _HaloRing(
                  diameter: diameter,
                  scale: 1.12 + level * 0.75,
                  color: tint.withValues(alpha: 0.1),
                ),
                _HaloRing(
                  diameter: diameter,
                  scale: 1.04 + level * 0.4,
                  color: tint.withValues(alpha: 0.18),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HaloRing extends StatelessWidget {
  const _HaloRing({
    required this.diameter,
    required this.scale,
    required this.color,
  });

  final double diameter;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

/// Visual FAB offset for a hold drag: tracks the finger 1:1 toward cancel and
/// rubber-bands (max ~10px) when pushed the wrong way.
double holdDragVisualOffset(double deltaX, double threshold) {
  if (deltaX <= 0) return math.max(deltaX, -threshold);
  return 10 * (1 - math.exp(-deltaX / 40));
}
