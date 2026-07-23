import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

const _commitmentMonths = 12;

class UnifiedPlanCard extends StatelessWidget {
  final List<PlanOption> plans;
  final String selectedPlanId;
  final ValueChanged<String> onPlanSelected;
  final bool Function(PlanOption)? isCurrentPlan;
  final bool isNewUser;

  const UnifiedPlanCard({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
    this.isCurrentPlan,
    this.isNewUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: plans.asMap().entries.map((entry) {
          final idx = entry.key;
          final plan = entry.value;

          final isDisabled = isCurrentPlan?.call(plan) ?? false;
          final isSelected = selectedPlanId == plan.id;

          final trialText = plan.serverPlanId == 'premium'
              ? context.l10n.paywallMonthlyTrial
              : null;
          final supportingText = _resolveSupportingText(
            context,
            plan,
            isDisabled,
          );
          final mainPriceText = _resolveMainPriceText(plan);
          final periodText = switch (plan.billingInterval) {
            'yearly' => context.l10n.perMonth,
            'monthly' => context.l10n.perMonth,
            _ => '',
          };

          return Padding(
            padding: EdgeInsets.only(
              left: idx == 0 ? 0 : 6,
              right: idx == plans.length - 1 ? 24 : 6,
            ),
            child: GestureDetector(
              onTap: isDisabled ? null : () => onPlanSelected(plan.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                constraints: BoxConstraints.tightFor(
                  width: 188,
                  height: plan.isCommitment ? 164 : 130,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? scheme.onSurface.withValues(alpha: 0.03)
                      : (isDark ? const Color(0xFF17181D) : scheme.card),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDisabled
                        ? Colors.transparent
                        : (isSelected
                            ? const Color(0xFF7458FF)
                            : scheme.outlineVariant.withValues(alpha: 0.3)),
                    width: isSelected && !isDisabled ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDisabled
                                  ? scheme.onSurface.withValues(alpha: 0.5)
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (isDisabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.current,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        else if (plan.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7458FF), Color(0xFFA855F7)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              plan.badgeText!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (trialText != null && !isDisabled && isNewUser) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trialText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (plan.isCommitment && !isDisabled) ...[
                      Text(
                        context.l10n.paywallCommitmentSavings,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      supportingText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDisabled
                            ? scheme.onSurface.withValues(alpha: 0.4)
                            : scheme.mutedForeground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.isCommitment)
                      Semantics(
                        button: true,
                        label:
                            context.l10n.paywallCommitmentHowItWorksSemantics,
                        child: GestureDetector(
                          onTap: () => _showCommitmentDetails(context, plan),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              context.l10n.paywallCommitmentHowItWorks,
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: mainPriceText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDisabled
                                ? scheme.onSurface.withValues(alpha: 0.5)
                                : const Color(0xFF8B5CF6),
                            letterSpacing: -0.5,
                          ),
                          children: [
                            if (periodText.isNotEmpty)
                              TextSpan(
                                text: periodText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDisabled
                                      ? scheme.onSurface.withValues(alpha: 0.4)
                                      : const Color(0xFF8B5CF6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _resolveSupportingText(
  BuildContext context,
  PlanOption plan,
  bool isDisabled,
) {
  if (plan.serverPlanId == 'lifetime') {
    return isDisabled
        ? context.l10n.currentPlan
        : context.l10n.paywallLifetimeSupport;
  }

  if (plan.billingInterval == 'yearly') {
    if (plan.isCommitment) {
      final total = plan.totalCommitmentPrice;
      return total == null
          ? context.l10n.paywallCommitmentBilledMonthly(_commitmentMonths)
          : context.l10n.paywallCommitmentBilledMonthlyWithTotal(
              total,
              _commitmentMonths,
            );
    }
    final total = plan.upfrontYearlyPrice;
    return total == null
        ? context.l10n.paywallCommitmentPaidUpfront(_commitmentMonths)
        : context.l10n.paywallCommitmentPaidUpfrontWithTotal(
            total,
            _commitmentMonths,
          );
  }

  return context.l10n.paywallFamilySharing;
}

String _resolveMainPriceText(PlanOption plan) {
  if (plan.billingInterval != 'yearly' || plan.isCommitment) {
    return plan.priceDisplay;
  }
  return plan.priceDisplay;
}

void _showCommitmentDetails(BuildContext context, PlanOption plan) {
  final colorScheme = Theme.of(context).colorScheme;
  final monthlyPrice = plan.priceDisplay;
  final totalPrice = plan.totalCommitmentPrice ?? '12 monthly payments';

  MonekoBottomSheet.show<void>(
    context: context,
    title: context.l10n.paywallCommitmentDetailsTitle,
    onClose: () => Navigator.of(context).pop(),
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.paywallCommitmentDetailsIntro(
              monthlyPrice,
              totalPrice,
              _commitmentMonths,
            ),
            style: TextStyle(
              color: colorScheme.mutedForeground,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          _CommitmentDetailSection(
            title: context.l10n.paywallCommitmentBillingTitle,
            body: context.l10n.paywallCommitmentBillingBody(
              monthlyPrice,
              totalPrice,
              _commitmentMonths,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: _CommitmentDetailSection(
              title: context.l10n.paywallCommitmentCancellationTitle,
              body: context.l10n
                  .paywallCommitmentCancellationBody(_commitmentMonths),
            ),
          ),
          const SizedBox(height: 18),
          _CommitmentDetailSection(
            title:
                context.l10n.paywallCommitmentRenewalTitle(_commitmentMonths),
            body: context.l10n.paywallCommitmentRenewalBody(_commitmentMonths),
          ),
        ],
      ),
    ),
  );
}

class _CommitmentDetailSection extends StatelessWidget {
  const _CommitmentDetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: TextStyle(
            color: colorScheme.mutedForeground,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
