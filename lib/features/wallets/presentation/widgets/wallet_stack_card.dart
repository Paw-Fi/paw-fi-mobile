import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';

class WalletStackCard extends StatelessWidget {
  const WalletStackCard({
    super.key,
    required this.wallet,
    required this.currencyCode,
    required this.displayBalanceCents,
    required this.isExpanded,
    this.subtitle,
    this.headerAction,
    this.metadataChips = const <Widget>[],
    this.showBalanceChevron = true,
    this.showGoalProgress = true,
  });

  final WalletEntity wallet;
  final String currencyCode;
  final int displayBalanceCents;
  final bool isExpanded;
  final String? subtitle;
  final Widget? headerAction;
  final List<Widget> metadataChips;
  final bool showBalanceChevron;
  final bool showGoalProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = displayBalanceCents / 100.0;
    final isNegative = amount < 0;

    final goal = (wallet.goalAmountCents ?? 0) / 100.0;
    final currentProgressAmount = amount < 0 ? 0.0 : amount;

    double progress = 0.0;
    if (goal > 0) {
      progress = (currentProgressAmount / goal).clamp(0.0, 1.0);
    } else if (goal == 0) {
      progress = 1.0;
    }

    final walletColorRaw = wallet.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseWalletColor(wallet.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      walletColorRaw,
      colorScheme,
      hasCustomColor: wallet.color.toUpperCase() != '#6B7280',
    );

    final backgroundTint = colorScheme.pocketTileFill(baseColor);
    final opaqueBackground =
        Color.alphaBlend(backgroundTint, colorScheme.surface);

    final collapsedHeader = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(
            resolveWalletIcon(wallet.icon),
            color: baseColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (wallet.isDefault) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: baseColor.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
          style: TextStyle(
            color:
                isNegative ? colorScheme.destructive : colorScheme.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );

    final expandedHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (headerAction != null) ...[
              const SizedBox(width: 12),
              headerAction!,
            ],
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (wallet.isDefault)
              Container(
                height: 36,
                padding: const EdgeInsets.only(left: 4, right: 12),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        resolveWalletIcon(wallet.icon),
                        color: baseColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.primary,
                      style: TextStyle(
                        color: baseColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolveWalletIcon(wallet.icon),
                  color: baseColor,
                  size: 18,
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.balance,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (showBalanceChevron) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                  style: TextStyle(
                    color: isNegative
                        ? colorScheme.destructive
                        : colorScheme.foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return PhysicalShape(
      clipper: const _OrganicWalletCardClipper(),
      color: opaqueBackground,
      elevation: isExpanded ? 8.0 : 4.0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.5),
      child: Stack(
        children: [
          Positioned(
            top: 28,
            left: 20,
            right: 20,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: collapsedHeader,
              secondChild: expandedHeader,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isExpanded ? 1.0 : 0.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (metadataChips.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: metadataChips,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (showGoalProgress) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(currentProgressAmount)))}',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(goal)))}',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: progress,
                        backgroundColor: baseColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganicWalletCardClipper extends CustomClipper<Path> {
  const _OrganicWalletCardClipper();

  @override
  Path getClip(Size size) {
    const radius = 24.0;
    const dipDepth = 16.0;
    final path = Path();

    final holeCenter = size.width * 0.50;
    final holeHalfWidth = size.width * 0.13;
    final flatBottomHalfWidth = size.width * 0.02;

    final startX = holeCenter - holeHalfWidth;
    final flatStartX = holeCenter - flatBottomHalfWidth;
    final flatEndX = holeCenter + flatBottomHalfWidth;
    final endX = holeCenter + holeHalfWidth;

    final curveWidth = flatStartX - startX;
    final cpOffset = curveWidth * 0.45;

    path.moveTo(radius, 0);
    path.lineTo(startX, 0);

    path.cubicTo(
      startX + cpOffset,
      0,
      flatStartX - cpOffset,
      dipDepth,
      flatStartX,
      dipDepth,
    );

    path.lineTo(flatEndX, dipDepth);

    path.cubicTo(
      flatEndX + cpOffset,
      dipDepth,
      endX - cpOffset,
      0,
      endX,
      0,
    );

    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius,
      size.height,
    );
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
