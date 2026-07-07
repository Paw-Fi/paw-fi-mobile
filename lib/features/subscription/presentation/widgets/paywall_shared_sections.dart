import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/data/models/app_store_reviews.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/shared/widgets/app_store_review_card.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/theme/app_theme.dart';

bool paywallPlanHasTrial(PlanOption option) => option.serverPlanId == 'premium';

String paywallPeriodLabel(BuildContext context, PlanOption option) {
  return option.billingInterval == 'monthly'
      ? context.l10n.paywallPeriodMonth
      : context.l10n.paywallPeriodYear;
}

String paywallAutoRenewTerms(
  BuildContext context, {
  required PlanOption option,
  required bool trialMode,
}) {
  final period = paywallPeriodLabel(context, option);
  if (trialMode && paywallPlanHasTrial(option)) {
    return context.l10n.paywallTrialTerms(period, option.priceDisplay);
  }
  return context.l10n.paywallSubTerms(period, option.priceDisplay);
}

String paywallPrimaryActionLabel(
  BuildContext context, {
  required PlanOption option,
  required bool isProcessing,
  required bool isStoreReady,
  required bool isCurrentPlan,
  required bool trialMode,
  bool includePrice = false,
}) {
  if (isProcessing) return context.l10n.paywallProcessing;
  if (!isStoreReady) return context.l10n.paywallErrorStoreUnavailableShort;
  if (isCurrentPlan) return context.l10n.alreadyOnThisPlan;
  if (trialMode && paywallPlanHasTrial(option)) {
    return context.l10n.start7DayPremiumFreeTrial;
  }
  if (option.serverPlanId == 'lifetime') return context.l10n.paywallGetLifetime;
  if (includePrice) {
    return context.l10n.subscribeForPricePeriod(
      paywallPeriodLabel(context, option),
      option.priceDisplay,
    );
  }
  return context.l10n.paywallSubscribe;
}

class PaywallAutoRenewCheckbox extends StatelessWidget {
  const PaywallAutoRenewCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isProcessing,
    required this.option,
    required this.trialMode,
    this.bottomPadding = 24,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isProcessing;
  final PlanOption option;
  final bool trialMode;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isProcessing ? null : () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: isProcessing
                    ? null
                    : (nextValue) => onChanged(nextValue ?? false),
                activeColor: colorScheme.primary,
                checkColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                paywallAutoRenewTerms(
                  context,
                  option: option,
                  trialMode: trialMode,
                ),
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaywallCheckoutActionButton extends StatelessWidget {
  const PaywallCheckoutActionButton({
    super.key,
    required this.option,
    required this.isProcessing,
    required this.isStoreReady,
    required this.canConfirmAutoRenew,
    required this.isCurrentPlan,
    required this.trialMode,
    required this.onPressed,
    this.includePrice = false,
    this.centerText = false,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
  });

  final PlanOption option;
  final bool isProcessing;
  final bool isStoreReady;
  final bool canConfirmAutoRenew;
  final bool isCurrentPlan;
  final bool trialMode;
  final VoidCallback onPressed;
  final bool includePrice;
  final bool centerText;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final label = paywallPrimaryActionLabel(
      context,
      option: option,
      isProcessing: isProcessing,
      isStoreReady: isStoreReady,
      isCurrentPlan: isCurrentPlan,
      trialMode: trialMode,
      includePrice: includePrice,
    );

    final text = Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );

    return PrimaryAdaptiveButton(
      onPressed:
          isProcessing || !canConfirmAutoRenew || !isStoreReady || isCurrentPlan
              ? null
              : onPressed,
      child: centerText ? Center(child: text) : text,
    );
  }
}

class PaywallFooterLinks extends StatelessWidget {
  const PaywallFooterLinks({
    super.key,
    required this.isProcessing,
    required this.onRestorePurchases,
    this.centered = false,
  });

  final bool isProcessing;
  final VoidCallback onRestorePurchases;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final linkStyle = TextStyle(
      color: colorScheme.mutedForeground.withValues(alpha: 0.8),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    final restoreLink = GestureDetector(
      onTap: isProcessing ? null : onRestorePurchases,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          context.l10n.paywallRestorePurchase,
          style: linkStyle,
        ),
      ),
    );

    if (centered) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          restoreLink,
          Text('|', style: linkStyle),
          const PaywallLegalLinks(),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        restoreLink,
        const PaywallLegalLinks(),
      ],
    );
  }
}

class PaywallLegalLinks extends StatelessWidget {
  const PaywallLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://moneko.io/terms-of-service');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          context.l10n.paywallTermsPrivacy,
          style: TextStyle(
            color: colorScheme.mutedForeground.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

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
      context.l10n.paywallBenefit0,
      context.l10n.paywallBenefit1,
      context.l10n.paywallBenefit2,
      context.l10n.paywallBenefit5,
      context.l10n.paywallBenefit3,
      context.l10n.paywallBenefit4,
      context.l10n.multipleCurrencies,
      context.l10n.currencyConverter,
      context.l10n.plusLockedBankSync,
      context.l10n.plusLockedLiveExchangeRates,
      context.l10n.appLock,
      context.l10n.prioritySupport,
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
