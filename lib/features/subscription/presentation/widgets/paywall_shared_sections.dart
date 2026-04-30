import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/data/models/app_store_reviews.dart';
import 'package:moneko/shared/widgets/app_store_review_card.dart';

class PaywallBackgroundDecoration extends StatelessWidget {
  const PaywallBackgroundDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'lib/assets/images/paywall/background-gradient.svg',
        width: MediaQuery.of(context).size.width,
        fit: BoxFit.cover,
      ),
    );
  }
}

class PaywallHeroIcon extends StatelessWidget {
  const PaywallHeroIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'lib/assets/mascots/moneko-gradient.svg',
      width: 87,
      height: 87,
      fit: BoxFit.contain,
    );
  }
}

class PaywallAppRatingBadge extends StatelessWidget {
  const PaywallAppRatingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contentColor = scheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'lib/assets/images/paywall/laurel-wreath.png',
              width: 170,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '4.8',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: contentColor,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${PlatformInfo.isIOS ? context.l10n.paywallStoreLabelApple : context.l10n.paywallStoreLabelPlay} ${context.l10n.paywallRatingSuffix}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: contentColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 4; i++)
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFCB860), size: 16),
                    Stack(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                          size: 16,
                        ),
                        ClipRect(
                          clipper: _FractionalClipper(0.8),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFCB860),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class PaywallBenefitsChecklist extends StatelessWidget {
  const PaywallBenefitsChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final items = [
      context.l10n.paywallBenefit1,
      context.l10n.paywallBenefit2,
      context.l10n.paywallBenefit5,
      context.l10n.paywallBenefit3,
      context.l10n.paywallBenefit4,
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF8ED4),
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class PaywallReviewsSection extends StatelessWidget {
  const PaywallReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedReviews = [
      appStoreReviews.firstWhere((r) => r.id == 'review-004'),
      appStoreReviews.firstWhere((r) => r.id == 'review-019'),
      appStoreReviews.firstWhere((r) => r.id == 'review-010'),
    ];

    return Column(
      children: [
        Text(
          context.l10n.paywallLovedBy,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...selectedReviews
            .map(
              (review) => AppStoreReviewCard(
                review: review,
                margin: const EdgeInsets.only(bottom: 16),
              ),
            )
            .toList(),
      ],
    );
  }
}

class _FractionalClipper extends CustomClipper<Rect> {
  _FractionalClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _FractionalClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
