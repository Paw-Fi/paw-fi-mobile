import 'package:flutter/material.dart';

import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
import 'package:moneko/features/pockets/presentation/widgets/liquid_pocket.dart';
import 'package:moneko/features/utils/currency.dart';

class PocketCard extends StatelessWidget {
  const PocketCard({
    super.key,
    required this.pocket,
    required this.colorScheme,
    required this.totalBudget,
    required this.envelopeMode,
    required this.onPercentageChanged,
    this.onTap,
  });

  final PocketEnvelope pocket;
  final ColorScheme colorScheme;
  final double totalBudget;
  final bool envelopeMode;
  final ValueChanged<double> onPercentageChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final limit = pocket.getLimit(totalBudget);
    final progress = limit > 0 ? (pocket.spent / limit) : 0.0;
    final isOverBudget = pocket.isOverBudget(totalBudget);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine base color
    Color baseColor = getPocketColor(pocket.color, colorScheme.primary);
    if (isDarkMode && pocket.color != null) {
      final hsl = HSLColor.fromColor(baseColor);
      baseColor =
          hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    }

    final Color fillColor;
    if (isOverBudget) {
      fillColor = colorScheme.error;
    } else if (progress > 0.9) {
      fillColor = Colors.orange;
    } else {
      fillColor = baseColor;
    }

    final iconData = getPocketIconData(pocket.icon);

    // Calculate text color based on fill level for contrast
    // Since we are using a liquid fill, the text might be over the liquid or the background.
    // For simplicity and readability in this premium design, we'll use a glassmorphism card
    // with the liquid in the background, and text on top with a slight shadow or background.

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Liquid Animation
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return LiquidPocket(
                    fillLevel: value,
                    color: fillColor,
                  );
                },
              ),
            ),

            // Content Overlay
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              iconData,
                              size: 18,
                              color: baseColor,
                            ),
                          ),
                          if (isOverBudget)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pocket.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  formatCurrency(pocket.spent, pocket.currency),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isOverBudget
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  ' / ${formatCurrency(limit, pocket.currency)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 4,
                                width: double.infinity,
                                color:
                                    Colors.black.withValues(alpha: 0.1),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: getProgressGradient(
                                          baseColor,
                                          progress,
                                          isOverBudget,
                                          isDarkMode,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
