import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class OnboardingFinishPage extends StatefulWidget {
  const OnboardingFinishPage({super.key});

  @override
  State<OnboardingFinishPage> createState() => _OnboardingFinishPageState();
}

class _OnboardingFinishPageState extends State<OnboardingFinishPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlights = <_HighlightItemData>[
      _HighlightItemData(
        icon: Icons.mic_rounded,
        title: context.l10n.onboardingFinishHighlightLogExpenses,
      ),
      _HighlightItemData(
        icon: Icons.chat_rounded,
        title: context.l10n.onboardingFinishHighlightWhatsApp,
      ),
      _HighlightItemData(
        icon: Icons.account_balance_wallet_rounded,
        title: context.l10n.onboardingFinishHighlightSharedBudgets,
      ),
      _HighlightItemData(
        icon: Icons.family_restroom_rounded,
        title: context.l10n.onboardingFinishHighlightOnePlan,
      ),
      _HighlightItemData(
        icon: Icons.dashboard_rounded,
        title: context.l10n.onboardingFinishHighlightEnvelopeBudgeting,
      ),
    ];

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kDebugMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Debug back',
                    ),
                  ),
                Text(
                  context.l10n.onboardingFinishHighlightSharedExpenses,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.onboardingFinishHighlightFreeTrial,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: _OrbitShowcase(),
                ),
                const SizedBox(height: 12),
                _HighlightsSection(
                  highlights: highlights,
                  header: context.l10n.onboardingFinishNextUp,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: PrimaryAdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      context.l10n.start,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitShowcase extends StatefulWidget {
  const _OrbitShowcase();

  @override
  State<_OrbitShowcase> createState() => _OrbitShowcaseState();
}

class _OrbitShowcaseState extends State<_OrbitShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 50),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final innerBubbles = <_OrbitBubbleData>[
      _OrbitBubbleData(
        text: l10n.orbitBubbleExpense1,
        icon: Icons.restaurant_rounded,
        baseAngle: 0,
      ),
      _OrbitBubbleData(
        text: l10n.orbitBubbleExpense2,
        icon: Icons.shopping_cart_rounded,
        baseAngle: 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: l10n.orbitBubbleExpense3,
        icon: Icons.coffee_rounded,
        baseAngle: 4 * math.pi / 3,
      ),
    ];

    final outerBubbles = <_OrbitBubbleData>[
      _OrbitBubbleData(
        text: l10n.orbitBubbleInsight1,
        icon: Icons.flight_rounded,
        baseAngle: math.pi / 6,
      ),
      _OrbitBubbleData(
        text: l10n.orbitBubbleInsight2,
        icon: Icons.savings_rounded,
        baseAngle: math.pi / 6 + 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: l10n.orbitBubbleInsight3,
        icon: Icons.dining_rounded,
        baseAngle: math.pi / 6 + 4 * math.pi / 3,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size / 2, size / 2);
        final innerRadius = size * 0.22;
        final outerRadius = size * 0.38;
        const avatarSize = 56.0;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final innerAngleOffset = t * 2 * math.pi;
                final outerAngleOffset = -t * 2 * math.pi;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Orbit rings
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _OrbitRingsPainter(
                          innerRadius: innerRadius,
                          outerRadius: outerRadius,
                          ringColor: colorScheme.border.withValues(alpha: 0.15),
                        ),
                      ),
                    ),

                    // Decorative dots on inner orbit
                    ..._buildDots(
                      center: center,
                      radius: innerRadius,
                      count: 4,
                      angleOffset: innerAngleOffset * 0.3,
                      dotSize: 5,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),

                    // Decorative dots on outer orbit
                    ..._buildDots(
                      center: center,
                      radius: outerRadius,
                      count: 5,
                      angleOffset: outerAngleOffset * 0.3,
                      dotSize: 6,
                      color: colorScheme.primary.withValues(alpha: 0.35),
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
                        isCompact: true,
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
                        isCompact: false,
                        colorScheme: colorScheme,
                      );
                    }),

                    // Center avatar
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
                              color: colorScheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 16,
                              spreadRadius: 2,
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
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDots({
    required Offset center,
    required double radius,
    required int count,
    required double angleOffset,
    required double dotSize,
    required Color color,
  }) {
    return List.generate(count, (i) {
      final angle = (i * 2 * math.pi / count) + angleOffset;
      final x = center.dx + radius * math.cos(angle) - dotSize / 2;
      final y = center.dy + radius * math.sin(angle) - dotSize / 2;
      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      );
    });
  }

  Positioned _buildBubble({
    required double x,
    required double y,
    required _OrbitBubbleData bubble,
    required bool isCompact,
    required ColorScheme colorScheme,
  }) {
    final maxWidth = isCompact ? 100.0 : 130.0;
    return Positioned(
      left: x - maxWidth / 2,
      top: y - 18,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              bubble.icon,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                bubble.text,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({
    required this.innerRadius,
    required this.outerRadius,
    required this.ringColor,
  });

  final double innerRadius;
  final double outerRadius;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, innerRadius, paint);
    canvas.drawCircle(center, outerRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.innerRadius != innerRadius ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.ringColor != ringColor;
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

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.highlights, required this.header});

  final List<_HighlightItemData> highlights;
  final String header;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tiles = List<Widget>.generate(highlights.length * 2 - 1, (index) {
      if (index.isOdd) {
        return Padding(
          padding: const EdgeInsets.only(left: 76),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.border.withValues(alpha: 0.2),
          ),
        );
      }
      final item = highlights[index ~/ 2];
      return _HighlightTile(item: item);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: colorScheme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.item});

  final _HighlightItemData item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightItemData {
  const _HighlightItemData({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;
}
