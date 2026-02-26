import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class OnboardingPreviewPage extends HookConsumerWidget {
  const OnboardingPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    void startPreview() {
      ref.read(previewModeProvider.notifier).enable();
      if (context.mounted) {
        context.go('/dashboard');
      }
    }

    void goToRegister() {
      ref.read(previewModeProvider.notifier).disable();
      if (context.mounted) {
        context.go('/register');
      }
    }

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              flex: 5,
              child: _PreviewOrbitHero(),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Experience Moneko',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jump into a live preview with curated mock data. Test features without touching real accounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _FeatureItem(
                      icon: Icons.auto_awesome_rounded,
                      text: 'Test AI logging in a safe sandbox',
                    ),
                    const SizedBox(height: 16),
                    const _FeatureItem(
                      icon: Icons.dashboard_customize_rounded,
                      text: 'Explore Pockets, Insights & Recurring',
                    ),
                    const SizedBox(height: 16),
                    const _FeatureItem(
                      icon: Icons.cloud_done_rounded,
                      text: 'Create an account later to save progress',
                    ),
                    const Spacer(),
                    PrimaryAdaptiveButton(
                      onPressed: startPreview,
                      child: const Text(
                        'Take the tour',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PlainAdaptiveButton(
                      onPressed: goToRegister,
                      child: Text(
                        'Create an account instead',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.foreground.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewOrbitHero extends HookWidget {
  const _PreviewOrbitHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useAnimationController(
      duration: const Duration(seconds: 40),
    )..repeat();

    const innerBubbles = [
      _OrbitBubbleData(
        text: 'AI Logging',
        icon: Icons.mic_rounded,
        baseAngle: 0,
      ),
      _OrbitBubbleData(
        text: 'Smart Pockets',
        icon: Icons.account_balance_wallet_rounded,
        baseAngle: 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: 'Shared Spaces',
        icon: Icons.family_restroom_rounded,
        baseAngle: 4 * math.pi / 3,
      ),
    ];

    const outerBubbles = [
      _OrbitBubbleData(
        text: 'Insightful Charts',
        icon: Icons.pie_chart_rounded,
        baseAngle: math.pi / 6,
      ),
      _OrbitBubbleData(
        text: 'WhatsApp Sync',
        icon: Icons.chat_rounded,
        baseAngle: math.pi / 6 + 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: 'Recurring Bills',
        icon: Icons.event_repeat_rounded,
        baseAngle: math.pi / 6 + 4 * math.pi / 3,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(constraints.maxWidth / 2, size / 2 + 20);
        final innerRadius = size * 0.28;
        final outerRadius = size * 0.45;
        const avatarSize = 64.0;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final innerAngleOffset = t * 2 * math.pi;
            final outerAngleOffset = -t * 2 * math.pi;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Inner rings
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PreviewOrbitRingsPainter(
                      innerRadius: innerRadius,
                      outerRadius: outerRadius,
                      ringColor: colorScheme.border.withValues(alpha: 0.2),
                      centerOffset: center,
                    ),
                  ),
                ),

                // Inner orbit bubbles
                ...innerBubbles.map((bubble) {
                  final angle = bubble.baseAngle + innerAngleOffset;
                  final x = center.dx + innerRadius * math.cos(angle);
                  final y = center.dy + innerRadius * math.sin(angle);
                  return _buildBubble(
                    x: x,
                    y: y,
                    bubble: bubble,
                    colorScheme: colorScheme,
                  );
                }),

                // Outer orbit bubbles
                ...outerBubbles.map((bubble) {
                  final angle = bubble.baseAngle + outerAngleOffset;
                  final x = center.dx + outerRadius * math.cos(angle);
                  final y = center.dy + outerRadius * math.sin(angle);
                  return _buildBubble(
                    x: x,
                    y: y,
                    bubble: bubble,
                    colorScheme: colorScheme,
                  );
                }),

                // Center avatar/icon
                Positioned(
                  left: center.dx - avatarSize / 2,
                  top: center.dy - avatarSize / 2,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.card,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'lib/assets/mascots/moneko-avatar.gif',
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Positioned _buildBubble({
    required double x,
    required double y,
    required _OrbitBubbleData bubble,
    required ColorScheme colorScheme,
  }) {
    return Positioned(
      left: x - 65,
      top: y - 20,
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bubble.icon,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                bubble.text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewOrbitRingsPainter extends CustomPainter {
  const _PreviewOrbitRingsPainter({
    required this.innerRadius,
    required this.outerRadius,
    required this.ringColor,
    required this.centerOffset,
  });

  final double innerRadius;
  final double outerRadius;
  final Color ringColor;
  final Offset centerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(centerOffset, innerRadius, paint);
    canvas.drawCircle(centerOffset, outerRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _PreviewOrbitRingsPainter oldDelegate) =>
      oldDelegate.innerRadius != innerRadius ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.centerOffset != centerOffset;
}

class _OrbitBubbleData {
  const _OrbitBubbleData({
    required this.text,
    required this.icon,
    required this.baseAngle,
  });

  final String text;
  final IconData icon;
  final double baseAngle;
}
