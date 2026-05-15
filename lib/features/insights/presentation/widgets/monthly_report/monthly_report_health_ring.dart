part of '../../pages/monthly_report_page.dart';

class _MonthlyReportHealthRing extends StatelessWidget {
  const _MonthlyReportHealthRing({
    required this.colorScheme,
    required this.metrics,
    required this.score,
    required this.status,
    required this.size,
  });

  final ColorScheme colorScheme;
  final List<_HealthRingMetric> metrics;
  final int score;
  final String status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: context.l10n.financialHealthSemanticsLabel(score, status),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 920),
        curve: Curves.easeOutCubic,
        builder: (context, animationValue, _) {
          final centerDiameter = (size * 0.42).clamp(68.0, 86.0);
          final animatedScore = (score * animationValue).round();

          return CustomPaint(
            painter: _MonthlyReportHealthRingPainter(
              colorScheme: colorScheme,
              metrics: metrics,
              animationValue: animationValue,
            ),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: SizedBox.square(
                  dimension: centerDiameter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          colorScheme.homeCardSurface.withValues(alpha: 0.86),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$animatedScore',
                          style: TextStyle(
                            fontSize: animatedScore > 99 ? 19 : 25,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthlyReportHealthRingLegend extends StatelessWidget {
  const _MonthlyReportHealthRingLegend({
    required this.colorScheme,
    required this.metrics,
  });

  final ColorScheme colorScheme;
  final List<_HealthRingMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final metric in metrics)
            _MonthlyReportHealthRingLegendRow(
              colorScheme: colorScheme,
              metric: metric,
            ),
        ],
      ),
    );
  }
}

class _MonthlyReportHealthRingLegendRow extends StatelessWidget {
  const _MonthlyReportHealthRingLegendRow({
    required this.colorScheme,
    required this.metric,
  });

  final ColorScheme colorScheme;
  final _HealthRingMetric metric;

  @override
  Widget build(BuildContext context) {
    final progressLabel = '${(metric.progress.clamp(0.0, 1.0) * 100).round()}%';

    return Padding(
      padding: _monthlyReportRowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthlyReportIconChip(
            colorScheme: colorScheme,
            accent: metric.color,
            icon: metric.icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  metric.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  progressLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: metric.color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                _MonthlyReportProgressBar(
                  colorScheme: colorScheme,
                  progress: metric.progress.clamp(0.0, 1.0),
                  accent: metric.color,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReportHealthRingPainter extends CustomPainter {
  const _MonthlyReportHealthRingPainter({
    required this.colorScheme,
    required this.metrics,
    required this.animationValue,
  });

  final ColorScheme colorScheme;
  final List<_HealthRingMetric> metrics;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = (side * 0.054).clamp(8.0, 11.5);
    final gap = strokeWidth * 0.72;
    final outerRadius = side / 2 - strokeWidth / 2;
    final trackPaint = Paint()
      ..color = colorScheme.border.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final radius = outerRadius - index * (strokeWidth + gap);
      if (radius <= strokeWidth) continue;

      final rect = Rect.fromCircle(center: center, radius: radius);
      final progress = math.max(0, metric.progress) * animationValue;
      final sweep = math.pi * 2 * progress;
      final overflowSweep = sweep % (math.pi * 2);

      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);
      progressPaint.color = metric.color.withValues(alpha: 0.95);

      if (progress <= 1) {
        canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
      } else {
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, progressPaint);
        if (overflowSweep > 0.001) {
          canvas.drawArc(
            rect,
            -math.pi / 2,
            overflowSweep,
            false,
            progressPaint,
          );
        }
      }

      if (progress > 0.02) {
        _drawRingEndpointMarker(
          canvas,
          center,
          radius,
          -math.pi / 2 + sweep,
          strokeWidth,
          metric,
        );
      }
    }
  }

  void _drawRingEndpointMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double strokeWidth,
    _HealthRingMetric metric,
  ) {
    final markerRadius = (strokeWidth * 0.72).clamp(6.0, 8.0);
    final markerCenter = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final markerFillPaint = Paint()
      ..color = metric.color
      ..style = PaintingStyle.fill;
    final markerBorderPaint = Paint()
      ..color = colorScheme.homeCardSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = markerRadius * 0.34;

    canvas.drawCircle(markerCenter, markerRadius, markerFillPaint);
    canvas.drawCircle(markerCenter, markerRadius, markerBorderPaint);

    final iconSize = markerRadius * 1.08;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(metric.icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: iconSize,
          fontFamily: metric.icon.fontFamily,
          package: metric.icon.fontPackage,
          color: colorScheme.homeCardSurface,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        markerCenter.dx - iconPainter.width / 2,
        markerCenter.dy - iconPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MonthlyReportHealthRingPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.metrics != metrics ||
        oldDelegate.animationValue != animationValue;
  }
}
