import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/shimmering_text.dart';

class PreparationLoadingView extends HookWidget {
  const PreparationLoadingView({
    super.key,
    required this.title,
    required this.body,
    this.steps = const [],
    this.stepInterval = const Duration(milliseconds: 1800),
    this.stepDurations,
    this.initialProgress = 0.15,
    this.progressCap = 0.88,
    this.pulsingIcon,
    this.iconSize = 180,
    this.progressRingSize = 180,
  });

  final String title;
  final String body;
  final List<String> steps;
  final Duration stepInterval;
  final List<Duration>? stepDurations;
  final double initialProgress;
  final double progressCap;
  final Widget? pulsingIcon;
  final double iconSize;
  final double progressRingSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentStepIndex = useState(0);

    useEffect(() {
      if (steps.isEmpty) return null;

      Timer? timer;
      void scheduleNextStep() {
        final duration = stepDurations != null &&
                currentStepIndex.value < stepDurations!.length
            ? stepDurations![currentStepIndex.value]
            : stepInterval;
        timer = Timer(duration, () {
          if (currentStepIndex.value < steps.length - 1) {
            currentStepIndex.value++;
            scheduleNextStep();
          }
        });
      }

      scheduleNextStep();
      return () {
        timer?.cancel();
      };
    }, [steps, stepInterval, stepDurations]);

    final progressValue = steps.isEmpty
        ? initialProgress
        : initialProgress +
            (currentStepIndex.value / (steps.length - 1).clamp(1, 999)) *
                (progressCap - initialProgress);

    final currentLabel = steps.isNotEmpty ? steps[currentStepIndex.value] : '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        curve: Curves.easeOutBack,
                        parent: animation,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: progressRingSize,
                height: progressRingSize,
                child: PreparationProgressRing(
                  progress: progressValue,
                  color: colorScheme.primary,
                  size: progressRingSize,
                  child: pulsingIcon ??
                      Image.asset(
                        'lib/assets/gifs/moneko-curious.gif',
                        key: const ValueKey('preparation_pulsing_icon'),
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                title,
                key: ValueKey(title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                body,
                key: ValueKey(body),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.mutedForeground,
                  height: 1.45,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (currentLabel.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ShimmeringText(
                  text: currentLabel,
                  key: ValueKey(currentLabel),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: colorScheme.mutedForeground,
                  ),
                  shimmering: true,
                ),
              ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class PreparationProgressRing extends StatelessWidget {
  const PreparationProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    this.child,
  });

  final double progress;
  final Color color;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _PreparationProgressRingPainter(
          progress: value,
          color: color,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _PreparationProgressRingPainter extends CustomPainter {
  const _PreparationProgressRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, 0, 2 * math.pi, false, trackPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * progress;
    const startAngle = -math.pi / 2;
    if (sweep > 0) {
      canvas.drawArc(bounds, startAngle, sweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(_PreparationProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
