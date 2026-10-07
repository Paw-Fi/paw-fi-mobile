import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
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
  final bool vertical;

  const UnifiedPlanCard({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
    this.isCurrentPlan,
    this.isNewUser = false,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < plans.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _VerticalPlanOption(
              plan: plans[index],
              selected: selectedPlanId == plans[index].id,
              disabled: isCurrentPlan?.call(plans[index]) ?? false,
              onSelected: () => onPlanSelected(plans[index].id),
            ),
          ],
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

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
                  height: isLargeText ? 170 : 130,
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
                    if (plan.isCommitment)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              supportingText,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDisabled
                                    ? scheme.onSurface.withValues(alpha: 0.4)
                                    : scheme.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: context
                                .l10n.paywallCommitmentHowItWorksSemantics,
                            onPressed: () =>
                                _showCommitmentDetails(context, plan),
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(28),
                              maximumSize: const Size.square(28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ],
                      )
                    else
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

class _VerticalPlanOption extends StatelessWidget {
  const _VerticalPlanOption({
    required this.plan,
    required this.selected,
    required this.disabled,
    required this.onSelected,
  });

  final PlanOption plan;
  final bool selected;
  final bool disabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final largeText = MonekoTextScale.isAtLeast(context, 1.5);
    final annualUpfront =
        plan.billingInterval == 'yearly' && !plan.isCommitment;
    final price = annualUpfront
        ? plan.upfrontYearlyPrice ?? plan.priceDisplay
        : plan.priceDisplay;
    final period = annualUpfront
        ? context.l10n.perYear
        : plan.billingInterval != null
            ? context.l10n.perMonth
            : '';
    final priceLabel = Text(
      '$price$period',
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(plan.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            if (disabled || plan.badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: disabled ? scheme.muted : scheme.planSelectionAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(disabled ? context.l10n.current : plan.badgeText!,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? scheme.mutedForeground
                            : scheme.plusIntroForeground)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(context.l10n.paywallFamilySharing,
            style: TextStyle(fontSize: 11, color: scheme.mutedForeground)),
        if (plan.isCommitment)
          Row(children: [
            Expanded(
                child: Text(_resolveSupportingText(context, plan, disabled),
                    style: TextStyle(
                        fontSize: 11, color: scheme.mutedForeground))),
            IconButton(
              tooltip: context.l10n.paywallCommitmentHowItWorksSemantics,
              onPressed: () => _showCommitmentDetails(context, plan),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.info_outline,
                  size: 16, color: scheme.mutedForeground),
            ),
          ]),
        if (largeText) ...[const SizedBox(height: 8), priceLabel],
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: scheme.planSelectionCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected && !disabled
                ? scheme.planSelectionAccent
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: selected && !disabled ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: scheme.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: disabled ? null : onSelected,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: largeText
                  ? details
                  : Row(children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      Flexible(child: priceLabel),
                    ]),
            ),
          ),
        ),
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
      return context.l10n.paywallCommitmentBilledMonthlyShort;
    }
    final total = plan.upfrontYearlyPrice;
    return total == null
        ? context.l10n.paywallCommitmentPaidUpfront(_commitmentMonths)
        : context.l10n.paywallCommitmentPaidUpfrontWithTotal(
            _commitmentMonths,
            total,
          );
  }

  return context.l10n.paywallCancelAnytime;
}

String _resolveMainPriceText(PlanOption plan) {
  if (plan.billingInterval != 'yearly' || plan.isCommitment) {
    return plan.priceDisplay;
  }
  return plan.priceDisplay;
}

void _showCommitmentDetails(BuildContext context, PlanOption plan) {
  final monthlyPrice = plan.priceDisplay;
  final commitmentTermText = context.l10n.monthlyPayments(_commitmentMonths);

  MonekoBottomSheet.show<void>(
    context: context,
    title: context.l10n.paywallCommitmentDetailsTitle,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommitmentHeroCard(
            monthlyPrice: monthlyPrice,
            commitmentMonths: _commitmentMonths,
          ),
          const SizedBox(height: 12),
          _CommitmentDetailCard(
            title: context.l10n.paywallCommitmentBillingTitle,
            body: context.l10n.paywallCommitmentBillingBody(
              monthlyPrice,
              _commitmentMonths,
              commitmentTermText,
            ),
          ),
          const SizedBox(height: 12),
          _CommitmentDetailCard(
            title: context.l10n.paywallCommitmentCancellationTitle,
            body: context.l10n
                .paywallCommitmentCancellationBody(_commitmentMonths),
          ),
          const SizedBox(height: 12),
          _CommitmentDetailCard(
            title:
                context.l10n.paywallCommitmentRenewalTitle(_commitmentMonths),
            body: context.l10n.paywallCommitmentRenewalBody(_commitmentMonths),
          ),
        ],
      ),
    ),
  );
}

class _CommitmentHeroCard extends StatelessWidget {
  const _CommitmentHeroCard({
    required this.monthlyPrice,
    required this.commitmentMonths,
  });

  final String monthlyPrice;
  final int commitmentMonths;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '12-MONTH PLAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.monthlyRate,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.pricePerMo(monthlyPrice),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.duration,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.monthsCount(commitmentMonths),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommitmentDetailCard extends StatelessWidget {
  const _CommitmentDetailCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: colorScheme.mutedForeground,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
