import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
import 'package:moneko/features/pockets/presentation/widgets/liquid_pocket.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/mesh_gradient_painter.dart';

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

    // Neutral light grey when showing skeletons, avoid pocket accent colors
    final palette = colorScheme.pocketPalette(
      isSkeleton
          ? colorScheme.surfaceContainerHighest
          : getPocketColor(pocket.color, colorScheme.primary),
    );
    final fillPalette = isSkeleton
        ? palette
        : isOverBudget
            ? colorScheme.pocketPalette(colorScheme.error)
            : progress > 0.9
                ? colorScheme.pocketPalette(colorScheme.warning)
                : palette;

    final iconData = getPocketIconData(pocket.icon);

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

    // Calculate text color based on fill level for contrast
    // Since we are using a liquid fill, the text might be over the liquid or the background.
    // For simplicity and readability in this premium design, we'll use a glassmorphism card
    // with the liquid in the background, and text on top with a slight shadow or background.

    return MonekoTextScale(
      mode: MonekoTextScaling.constrained,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface.base,
          borderRadius: BorderRadius.circular(32),
          boxShadow: palette.cardShadows,
          border: Border.all(
            color: palette.border,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MeshGradientPainter(
                      surface: palette.surface,
                      shape: const RoundedRectClipper(32),
                    ),
                  ),
                ),
              ),
              // Liquid Animation
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return LiquidPocket(
                      fillLevel: value,
                      palette: fillPalette,
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
                            _PocketLogoAvatar(
                              logoUrl: pocket.logoUrl,
                              iconData: iconData,
                              palette: palette,
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
                            color: palette.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: palette.panelBorder,
                              width: 0.75,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: palette.shadow,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                  color: palette.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: Text.rich(
                                    key: ValueKey('${pocket.spent}_$limit'),
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: spentDisplay,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isOverBudget
                                                ? colorScheme.error
                                                : palette.title,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' / $limitDisplay',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: palette.subtitle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeInOut,
                                child: rolloverBadgeText == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.18),
                                            ),
                                          ),
                                          child: Text(
                                            rolloverBadgeText,
                                            maxLines: 1,
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
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 4,
                                  width: double.infinity,
                                  color: palette.progressTrack,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 1000),
                                            curve: Curves.easeOutQuart,
                                            width: constraints.maxWidth *
                                                progress.clamp(0.0, 1.0),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  fillPalette.progressGradient,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
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
      ),
    );
  }
}

class _PocketLogoAvatar extends StatelessWidget {
  const _PocketLogoAvatar({
    required this.logoUrl,
    required this.iconData,
    required this.palette,
  });

  final String? logoUrl;
  final IconData iconData;
  final PocketColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final trimmedLogoUrl = logoUrl?.trim();
    final cacheSize = (38 * MediaQuery.of(context).devicePixelRatio).round();
    final hasLogo = trimmedLogoUrl != null && trimmedLogoUrl.isNotEmpty;

    if (hasLogo) {
      return SizedBox(
        width: 33,
        height: 33,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: trimmedLogoUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheSize,
            memCacheHeight: cacheSize,
            cacheKey: trimmedLogoUrl,
            placeholder: (_, __) {
              return _PocketFallbackIcon(
                iconData: iconData,
                baseColor: palette.iconForeground,
              );
            },
            errorWidget: (_, __, ___) => _PocketFallbackIcon(
              iconData: iconData,
              baseColor: palette.iconForeground,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: palette.iconSurfaceGradient,
        border: Border.all(color: palette.iconRim, width: 0.75),
        shape: BoxShape.circle,
        boxShadow: palette.iconShadows,
      ),
      child: ClipOval(
        child: _PocketFallbackIcon(
          iconData: iconData,
          baseColor: palette.iconForeground,
        ),
      ),
    );
  }
}

class _PocketFallbackIcon extends StatelessWidget {
  const _PocketFallbackIcon({
    required this.iconData,
    required this.baseColor,
  });

  final IconData iconData;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        iconData,
        size: 18,
        color: baseColor,
      ),
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
