part of '../../pages/monthly_report_page.dart';

class _MonthlyReportAdviceCard extends StatelessWidget {
  const _MonthlyReportAdviceCard({
    required this.colorScheme,
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
    this.visual,
  });

  final ColorScheme colorScheme;
  final String label;
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(18),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthlyReportEyebrow(
              colorScheme: colorScheme,
              label: label,
              accent: accent,
              icon: icon,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                height: 1.2,
              ),
            ),
            if (body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body.trim(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                  height: 1.45,
                ),
              ),
            ],
            if (visual != null) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.border.withValues(alpha: 0.28),
              ),
              const SizedBox(height: 14),
              visual!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlyReportAboutCard extends StatelessWidget {
  const _MonthlyReportAboutCard({
    required this.colorScheme,
    required this.title,
    required this.body,
  });

  final ColorScheme colorScheme;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportSectionTitle(title: title, colorScheme: colorScheme),
        const SizedBox(height: 10),
        _ReportCard(
          colorScheme: colorScheme,
          padding: const EdgeInsets.all(18),
          child: Text(
            body,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.foreground,
              height: 1.48,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyReportPaceComparisonBar extends StatelessWidget {
  const _MonthlyReportPaceComparisonBar({
    required this.colorScheme,
    required this.accent,
    required this.spentProgress,
    required this.timeProgress,
  });

  final ColorScheme colorScheme;
  final Color accent;
  final double spentProgress;
  final double timeProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final markerLeft = (constraints.maxWidth * timeProgress.clamp(0.0, 1.0))
            .clamp(0.0, constraints.maxWidth);

        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                top: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.border.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: spentProgress.clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: markerLeft,
                child: Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.foreground.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyReportMerchantShareChart extends StatelessWidget {
  const _MonthlyReportMerchantShareChart({
    required this.colorScheme,
    required this.merchants,
    required this.currencyCode,
  });

  final ColorScheme colorScheme;
  final List<MonthlyMerchantSpendItem> merchants;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();

    final accents = [
      colorScheme.primary,
      colorScheme.info,
      colorScheme.success,
      colorScheme.warning,
      colorScheme.error,
    ];

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthlyReportEyebrow(
            colorScheme: colorScheme,
            label: 'Concentration',
            accent: colorScheme.info,
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var index = 0; index < merchants.length; index++)
                    Expanded(
                      flex: math.max(
                        1,
                        (merchants[index].spendingShare * 1000).round(),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        color: accents[index % accents.length],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 9,
            children: [
              for (var index = 0; index < merchants.length; index++)
                _MonthlyReportMerchantLegendItem(
                  colorScheme: colorScheme,
                  color: accents[index % accents.length],
                  merchant: merchants[index],
                  currencyCode: currencyCode,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyReportMerchantLegendItem extends StatelessWidget {
  const _MonthlyReportMerchantLegendItem({
    required this.colorScheme,
    required this.color,
    required this.merchant,
    required this.currencyCode,
  });

  final ColorScheme colorScheme;
  final Color color;
  final MonthlyMerchantSpendItem merchant;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          merchant.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${_detailPercent(merchant.spendingShare)} · ${formatCurrency(merchant.amount, currencyCode)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.mutedForeground,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
