import 'package:moneko/features/subscription/data/models/plan_option.dart';

String? selectPaywallPlanId({
  required String currentPlanId,
  required String? currentInterval,
  required List<PlanOption> plans,
  required String? currentSelection,
}) {
  if (plans.isEmpty) return currentSelection;

  final currentPlanMatch = _matchingPlan(
    plans,
    planId: currentPlanId,
    billingInterval: currentPlanId == 'lifetime' ? null : currentInterval,
  );
  if (currentPlanMatch != null) return currentPlanMatch.id;

  if (currentSelection != null && plans.any((p) => p.id == currentSelection)) {
    return currentSelection;
  }

  final defaultPlusYearly = _matchingPlan(
    plans,
    planId: 'plus',
    billingInterval: 'yearly',
  );
  for (final plan in plans) {
    if (plan.billingInterval == 'yearly') {
      return defaultPlusYearly?.id ?? plan.id;
    }
  }
  return defaultPlusYearly?.id ?? plans.first.id;
}

PlanOption? _matchingPlan(
  List<PlanOption> plans, {
  required String planId,
  required String? billingInterval,
}) {
  for (final plan in plans) {
    if (plan.serverPlanId == planId &&
        plan.billingInterval == billingInterval) {
      return plan;
    }
  }
  return null;
}
