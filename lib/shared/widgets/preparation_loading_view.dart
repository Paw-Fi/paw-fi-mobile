import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/animated_pulsing_icon.dart';
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
  });

  final String title;
  final String body;
  final List<String> steps;
  final Duration stepInterval;
  final List<Duration>? stepDurations;
  final double initialProgress;
  final double progressCap;
  final Widget? pulsingIcon;

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
              child: pulsingIcon ??
                  AnimatedPulsingIcon(
                    key: const ValueKey('preparation_pulsing_icon'),
                    color: colorScheme.primary,
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
            Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progressValue),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: colorScheme.surfaceBorder,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                if (currentLabel.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                ],
              ],
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
