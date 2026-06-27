import 'package:moneko/features/subscription/data/models/subscription.dart';

bool isSubscriptionPlanPubliclySelectable(String planId) {
  return planId.toLowerCase().trim() != 'premium';
}

/// Access gate for paid plan features currently sold through Plus, Premium, or Lifetime.
bool hasPremiumPlanAccess(Subscription? subscription) {
  if (subscription == null || subscription.isFreePlan) return false;
  return subscription.isSubscribed;
}

bool isTrialingPlan(Subscription? subscription) {
  return subscription?.status?.toLowerCase().trim() == 'trialing' &&
      (subscription?.isSubscribed ?? false);
}

bool isPlusPlan(Subscription? subscription) {
  return subscription?.plan?.toLowerCase().trim() == 'plus' &&
      (subscription?.isSubscribed ?? false) &&
      !isTrialingPlan(subscription);
}

bool isPremiumTierPlan(Subscription? subscription) {
  final plan = subscription?.plan?.toLowerCase().trim();
  return plan == 'premium' || plan == 'lifetime';
}

/// Access gate for advanced paid features. Trial/free users stay blocked.
bool hasPremiumFeatureAccess(Subscription? subscription) {
  if (subscription == null || !(subscription.isSubscribed)) return false;
  return !isTrialingPlan(subscription);
}
