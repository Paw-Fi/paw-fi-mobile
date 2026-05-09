import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A fake progress bar used to indicate background activity during app resume.
///
/// It animates smoothly from 0 to ~98% over the specified duration,
/// slowing down near the end to simulate a task that is finishing up.
class ReconcileProgressBar extends StatefulWidget {
  final Duration duration;
  final double height;
  final BorderRadius borderRadius;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? waveColor;
  final VoidCallback? onComplete;

  const ReconcileProgressBar({
    super.key,
    this.duration = const Duration(seconds: 3),
    this.height = 3.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
    this.activeColor,
    this.inactiveColor,
    this.waveColor,
    this.onComplete,
  });

  @override
  State<ReconcileProgressBar> createState() => _ReconcileProgressBarState();
}

class _ReconcileProgressBarState extends State<ReconcileProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration + const Duration(milliseconds: 500),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Simulation of a realistic "fake" progress:
    // 0-85% happens in the first 60% of time (fast start)
    // 85-95% happens in the next 30% of time (slowing down)
    // 95-100% happens in the last 10% of time (crawling to finish)
    _progressAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 10,
      ),
    ]).animate(_progressController);

    _progressController.forward().then((_) async {
      if (mounted) {
        await _fadeController.forward();
        if (mounted && widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final active = widget.activeColor ?? colorScheme.primary;
    final inactive = widget.inactiveColor ?? colorScheme.skeletonBase;
    final wave = widget.waveColor ?? colorScheme.skeletonHighlight;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: inactive,
              borderRadius: widget.borderRadius,
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: widget.borderRadius,
                    ),
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _ShimmerPainter(
                              progress: _shimmerController.value,
                              color: wave,
                            ),
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(
          (progress * size.width * 2) - size.width,
          0,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
