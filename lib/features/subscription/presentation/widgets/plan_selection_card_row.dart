import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/widgets/unified_plan_card.dart';

const _planDisplayOrder = {'yearly': 0, 'monthly': 1};

int _planSortRank(PlanOption plan) {
  final interval = plan.billingInterval?.toLowerCase().trim();
  if (interval != null) return _planDisplayOrder[interval] ?? 2;
  return plan.serverPlanId == 'lifetime' ? 3 : 2;
}

List<PlanOption> sortPlanOptions(List<PlanOption> plans) {
  return plans.toList()..sort((a, b) => _planSortRank(a).compareTo(_planSortRank(b)));
}

class PlanSelectionCardRow extends StatelessWidget {
  const PlanSelectionCardRow({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
    this.isCurrentPlan,
    this.isNewUser = false,
  });

  final List<PlanOption> plans;
  final String selectedPlanId;
  final ValueChanged<String> onPlanSelected;
  final bool Function(PlanOption)? isCurrentPlan;
  final bool isNewUser;

  @override
  Widget build(BuildContext context) {
    final sortedPlans = sortPlanOptions(plans);

    if (sortedPlans.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Text(
            context.l10n.paywallErrorLoadOptions,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return UnifiedPlanCard(
      plans: sortedPlans,
      selectedPlanId: selectedPlanId,
      onPlanSelected: onPlanSelected,
      isCurrentPlan: isCurrentPlan,
      isNewUser: isNewUser,
    );
  }
}
