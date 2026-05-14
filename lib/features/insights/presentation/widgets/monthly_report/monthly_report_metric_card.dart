part of '../../pages/monthly_report_page.dart';

class _MonthlyReportMetricCard extends StatelessWidget {
  const _MonthlyReportMetricCard({
    required this.colorScheme,
    required this.spec,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final _MonthlyMetricSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MonthlyReportTappableSurface(
      colorScheme: colorScheme,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 154),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MonthlyReportEyebrow(
                    colorScheme: colorScheme,
                    label: spec.label,
                    accent: spec.accent,
                    icon: spec.icon,
                  ),
                ),
                const SizedBox(width: 8),
                _MonthlyReportChevron(colorScheme: colorScheme),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          spec.value,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            height: 1.02,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec.caption,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    width: 82,
                    height: 58,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: SizedBox(width: 82, child: spec.visual),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
