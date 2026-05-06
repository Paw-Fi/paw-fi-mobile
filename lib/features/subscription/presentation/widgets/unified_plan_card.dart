import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';

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

          final trialText = switch (plan.billingInterval) {
            'yearly' => context.l10n.paywallYearlyTrial,
            'monthly' => context.l10n.paywallMonthlyTrial,
            _ => null,
          };
          final supportingText = plan.serverPlanId == 'lifetime'
              ? (isDisabled
                  ? 'Current Plan'
                  : context.l10n.paywallLifetimeSupport)
              : context.l10n.paywallFamilySharing;
          final periodText = switch (plan.billingInterval) {
            'yearly' => context.l10n.perYear,
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
                constraints: const BoxConstraints.tightFor(
                  width: 188,
                  height: 145,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? scheme.onSurface.withValues(alpha: 0.03)
                      : (isDark ? const Color(0xFF17181D) : scheme.card),
                  borderRadius: BorderRadius.circular(36),
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
                              'Current',
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
                    Text(
                      supportingText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDisabled
                            ? scheme.onSurface.withValues(alpha: 0.4)
                            : scheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        text: plan.priceDisplay,
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
