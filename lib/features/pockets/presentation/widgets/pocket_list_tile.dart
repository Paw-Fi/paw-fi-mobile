import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/mesh_gradient_painter.dart';

class PocketListTile extends StatelessWidget {
  const PocketListTile({
    super.key,
    required this.pocket,
    required this.currency,
    required this.colorScheme,
    required this.totalBudget,
    required this.onTap,
  });

  final PocketEnvelope pocket;
  final String currency;
  final ColorScheme colorScheme;
  final double totalBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limit = pocket.getLimit(totalBudget);
    final progress = limit > 0 ? (pocket.spent / limit) : 0.0;
    final isOverBudget = pocket.isOverBudget(totalBudget);

    final palette = colorScheme.pocketPalette(
      getPocketColor(pocket.color, colorScheme.primary),
    );
    final fillPalette = isOverBudget
        ? colorScheme.pocketPalette(colorScheme.error)
        : progress > 0.9
            ? colorScheme.pocketPalette(colorScheme.warning)
            : palette;

    final iconData = getPocketIconData(pocket.icon);

    // Derive text colors for readability based on theme and background
    final titleColor = palette.title;
    final subtitleColor = palette.subtitle;

    final currencySymbol = resolveCurrencySymbol(currency);
    final spentNormalized = double.parse(formatAmount(pocket.spent));
    final spentLocalized = formatLocalizedNumber(context, spentNormalized);
    final spentDisplay = '$currencySymbol$spentLocalized';

    final limitNormalized = double.parse(formatAmount(limit));
    final limitLocalized = formatLocalizedNumber(context, limitNormalized);
    final limitDisplay = '$currencySymbol$limitLocalized';
    final rolloverAdjustmentCents =
        pocket.rolloverFromPreviousCents + pocket.openingRolloverCents;
    final rolloverBadgeText = pocket.hasRolloverBreakdown
        ? context.l10n.pocketRolloverCarryOverBadge(
            _formatSignedCurrencyCents(
              context,
              rolloverAdjustmentCents,
              currency,
            ),
          )
        : null;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // The mesh's soft sources extend past the tile; clip them to its
        // rounded shape so they cannot read as a misaligned shadow.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fillPalette.surface.base,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: fillPalette.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: fillPalette.shadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: MeshGradientPainter(
            surface: fillPalette.surface,
            shape: const RoundedRectClipper(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon chip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: palette.iconSurfaceGradient,
                    border: Border.all(color: palette.iconRim, width: 0.75),
                    shape: BoxShape.circle,
                    boxShadow: palette.iconShadows,
                  ),
                  child: Icon(
                    iconData,
                    size: 20,
                    color: palette.iconForeground,
                  ),
                ),
                const SizedBox(width: 14),
                // Main content card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: palette.panelBorder,
                        width: 0.75,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isLargeText
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PocketTitleAndProgress(
                                pocket: pocket,
                                isOverBudget: isOverBudget,
                                progress: progress,
                                rolloverBadgeText: rolloverBadgeText,
                                titleColor: titleColor,
                                trackColor: palette.progressTrack,
                                progressGradient: fillPalette.progressGradient,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: _PocketAmounts(
                                  spentDisplay: spentDisplay,
                                  limitDisplay: limitDisplay,
                                  isOverBudget: isOverBudget,
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  colorScheme: colorScheme,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _PocketTitleAndProgress(
                                  pocket: pocket,
                                  isOverBudget: isOverBudget,
                                  progress: progress,
                                  rolloverBadgeText: rolloverBadgeText,
                                  titleColor: titleColor,
                                  trackColor: palette.progressTrack,
                                  progressGradient:
                                      fillPalette.progressGradient,
                                  colorScheme: colorScheme,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _PocketAmounts(
                                spentDisplay: spentDisplay,
                                limitDisplay: limitDisplay,
                                isOverBudget: isOverBudget,
                                titleColor: titleColor,
                                subtitleColor: subtitleColor,
                                colorScheme: colorScheme,
                              ),
                            ],
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

class _PocketTitleAndProgress extends StatelessWidget {
  const _PocketTitleAndProgress({
    required this.pocket,
    required this.isOverBudget,
    required this.progress,
    required this.rolloverBadgeText,
    required this.titleColor,
    required this.trackColor,
    required this.progressGradient,
    required this.colorScheme,
  });

  final PocketEnvelope pocket;
  final bool isOverBudget;
  final double progress;
  final String? rolloverBadgeText;
  final Color titleColor;
  final Color trackColor;
  final Gradient progressGradient;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pocket.name,
                maxLines: MonekoTextScale.isAtLeast(context, 1.5) ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
            if (isOverBudget) ...[
              const SizedBox(width: 6),
              Icon(Icons.priority_high_rounded,
                  color: colorScheme.error, size: 16),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 4,
            width: double.infinity,
            color: trackColor,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: progressGradient),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: rolloverBadgeText == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      rolloverBadgeText!,
                      maxLines: MonekoTextScale.isAtLeast(context, 1.5) ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PocketAmounts extends StatelessWidget {
  const _PocketAmounts({
    required this.spentDisplay,
    required this.limitDisplay,
    required this.isOverBudget,
    required this.titleColor,
    required this.subtitleColor,
    required this.colorScheme,
  });

  final String spentDisplay;
  final String limitDisplay;
  final bool isOverBudget;
  final Color titleColor;
  final Color subtitleColor;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          spentDisplay,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isOverBudget ? colorScheme.error : titleColor,
          ),
        ),
        Text('/ $limitDisplay',
            style: TextStyle(fontSize: 11, color: subtitleColor)),
      ],
    );
  }
}

String _formatSignedCurrencyCents(
  BuildContext context,
  int cents,
  String currency,
) {
  final sign = cents < 0 ? '-' : '+';
  final amount = double.parse(formatAmount(cents.abs() / 100.0));
  final localized = formatLocalizedNumber(context, amount);
  return '$sign${resolveCurrencySymbol(currency)}$localized';
}
