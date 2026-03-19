import 'package:flutter/material.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
import 'package:moneko/features/pockets/presentation/widgets/liquid_pocket.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

class PocketCard extends StatelessWidget {
  const PocketCard({
    super.key,
    required this.pocket,
    required this.currency,
    required this.colorScheme,
    required this.totalBudget,
    required this.envelopeMode,
    this.onTap,
    this.isSkeleton = false,
  });

  final PocketEnvelope pocket;
  final String currency;
  final ColorScheme colorScheme;
  final double totalBudget;
  final bool envelopeMode;
  final VoidCallback? onTap;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) {
    final limit = pocket.getLimit(totalBudget);
    final progress = limit > 0 ? (pocket.spent / limit) : 0.0;
    final isOverBudget = !isSkeleton && pocket.isOverBudget(totalBudget);

    // Determine base color
    Color baseColor;
    if (isSkeleton) {
      // Neutral light grey when showing skeletons, avoid pocket accent colors
      baseColor = colorScheme.surfaceContainerHighest;
    } else {
      baseColor = getPocketColor(pocket.color, colorScheme.primary);
      baseColor = AppTheme.tunedPocketBaseColor(
        baseColor,
        colorScheme,
        hasCustomColor: pocket.color != null,
      );
    }

    final Color fillColor;
    if (isSkeleton) {
      fillColor = baseColor;
    } else if (isOverBudget) {
      fillColor = colorScheme.error;
    } else if (progress > 0.9) {
      fillColor = colorScheme.warning;
    } else {
      fillColor = baseColor;
    }

    final iconData = getPocketIconData(pocket.icon);

    final currencySymbol = resolveCurrencySymbol(currency);
    final spentNormalized = double.parse(formatAmount(pocket.spent));
    final spentLocalized = formatLocalizedNumber(context, spentNormalized);
    final spentDisplay = '$currencySymbol$spentLocalized';

    final limitNormalized = double.parse(formatAmount(limit));
    final limitLocalized = formatLocalizedNumber(context, limitNormalized);
    final limitDisplay = '$currencySymbol$limitLocalized';

    // Calculate text color based on fill level for contrast
    // Since we are using a liquid fill, the text might be over the liquid or the background.
    // For simplicity and readability in this premium design, we'll use a glassmorphism card
    // with the liquid in the background, and text on top with a slight shadow or background.

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.pocketCardBorder,
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
              color: colorScheme.surface.withValues(alpha: 0.0),
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
                              color: colorScheme.pocketGlassSurface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.pocketIconShadow,
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
                              child: Icon(
                                Icons.priority_high_rounded,
                                color: colorScheme.primaryForeground,
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
                          color: colorScheme.pocketGlassSurfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.pocketGlassShadow,
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.pocketTitle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: spentDisplay,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isOverBudget
                                            ? colorScheme.error
                                            : colorScheme.pocketTitle,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / $limitDisplay',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.pocketSubtitle,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 4,
                                width: double.infinity,
                                color: colorScheme.pocketProgressTrack,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: getProgressGradient(
                                          colorScheme,
                                          baseColor,
                                          progress,
                                          isOverBudget,
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
