import 'package:moneko/features/subscription/data/models/subscription.dart';

bool isSubscriptionPlanPubliclySelectable(String planId) {
  return planId.toLowerCase().trim() != 'premium';
}

bool isTrialingPlan(Subscription? subscription) {
  return subscription?.status?.toLowerCase().trim() == 'trialing' &&
      (subscription?.isSubscribed ?? false);
}

/// Simple status check for trialing subscription (without isSubscribed requirement)
bool isSubscriptionStatusTrialing(Subscription? subscription) {
  return subscription?.status?.toLowerCase().trim() == 'trialing';
}

bool isPlusPlan(Subscription? subscription) {
  return subscription?.plan?.toLowerCase().trim() == 'plus' &&
      (subscription?.isSubscribed ?? false) &&
      !isTrialingPlan(subscription);
}

bool hasExpiredSubscriptionAccess(Subscription? subscription) {
  if (subscription == null || subscription.isFreePlan) return false;

  final plan = subscription.plan?.toLowerCase().trim();
  final status = subscription.status?.toLowerCase().trim();
  if (plan == 'lifetime' && status == 'active') return false;
  if (status != 'trialing' && status != 'active' && status != 'past_due') {
    return false;
  }

  final currentPeriodEnd = subscription.currentPeriodEnd;
  return currentPeriodEnd == null || !currentPeriodEnd.isAfter(DateTime.now());
}

/// Access gate for Plus features. Valid trialing users are included; free or expired users are blocked.
bool hasPremiumFeatureAccess(Subscription? subscription) {
  if (subscription == null || !(subscription.isSubscribed)) return false;
  return true;
}
