import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';

void main() {
  Subscription subscription({
    String? plan,
    String? status,
    DateTime? currentPeriodEnd,
  }) {
    return Subscription(
      id: 'sub-id',
      userId: 'user-id',
      plan: plan,
      status: status,
      currentPeriodEnd: currentPeriodEnd,
      createdAt: DateTime(2026),
    );
  }

  test('allows Plus feature access during a valid trial', () {
    final trialingSubscription = subscription(
      plan: 'plus',
      status: 'trialing',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 7)),
    );

    expect(trialingSubscription.isSubscribed, isTrue);
    expect(hasPremiumFeatureAccess(trialingSubscription), isTrue);
  });

  test('allows Plus feature access during a valid past_due entitlement window',
      () {
    final pastDueSubscription = subscription(
      plan: 'plus',
      status: 'past_due',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 3)),
    );

    expect(pastDueSubscription.isSubscribed, isTrue);
    expect(hasPremiumFeatureAccess(pastDueSubscription), isTrue);
  });

  test('denies access for expired trialing subscriptions', () {
    final expiredTrialingSubscription = subscription(
      plan: 'plus',
      status: 'trialing',
      currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(expiredTrialingSubscription.isSubscribed, isFalse);
    expect(hasExpiredSubscriptionAccess(expiredTrialingSubscription), isTrue);
  });

  test('detects expired active subscriptions by period end', () {
    final expiredActiveSubscription = subscription(
      plan: 'plus',
      status: 'active',
      currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(expiredActiveSubscription.isSubscribed, isFalse);
    expect(hasExpiredSubscriptionAccess(expiredActiveSubscription), isTrue);
  });

  test('does not treat free or valid subscriptions as expired', () {
    final freeSubscription = subscription(
      plan: 'free',
      status: 'active',
      currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );
    final activeSubscription = subscription(
      plan: 'plus',
      status: 'active',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
    );

    expect(hasExpiredSubscriptionAccess(null), isFalse);
    expect(hasExpiredSubscriptionAccess(freeSubscription), isFalse);
    expect(hasExpiredSubscriptionAccess(activeSubscription), isFalse);
  });
}
