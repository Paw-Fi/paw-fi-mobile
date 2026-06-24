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

  test('denies access when subscription is null', () {
    expect(hasPremiumPlanAccess(null), isFalse);
  });

  test('denies access for free subscriptions', () {
    expect(
      hasPremiumPlanAccess(
        subscription(
          plan: 'free',
          status: 'active',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
      isFalse,
    );
  });

  test('denies access for canceled subscriptions', () {
    expect(
      hasPremiumPlanAccess(
        subscription(
          plan: 'plus',
          status: 'canceled',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
      isFalse,
    );
  });

  test('denies access for expired active subscriptions', () {
    final expiredSubscription = subscription(
      plan: 'plus',
      status: 'active',
      currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(expiredSubscription.isSubscribed, isFalse);
    expect(hasPremiumPlanAccess(expiredSubscription), isFalse);
  });

  test('allows access for active Plus subscriptions', () {
    final activeSubscription = subscription(
      plan: 'plus',
      status: 'active',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
    );

    expect(activeSubscription.isSubscribed, isTrue);
    expect(hasPremiumPlanAccess(activeSubscription), isTrue);
  });

  test('allows access for active Premium subscriptions', () {
    final activeSubscription = subscription(
      plan: 'premium',
      status: 'active',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
    );

    expect(activeSubscription.isSubscribed, isTrue);
    expect(hasPremiumPlanAccess(activeSubscription), isTrue);
  });

  test('allows access for active Lifetime subscriptions', () {
    final activeSubscription = subscription(
      plan: 'lifetime',
      status: 'active',
    );

    expect(activeSubscription.isSubscribed, isTrue);
    expect(hasPremiumPlanAccess(activeSubscription), isTrue);
  });

  test('allows access for valid trialing subscriptions', () {
    final trialingSubscription = subscription(
      plan: 'plus',
      status: 'trialing',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 7)),
    );

    expect(trialingSubscription.isSubscribed, isTrue);
    expect(hasPremiumPlanAccess(trialingSubscription), isTrue);
  });

  test('denies access for expired trialing subscriptions', () {
    final expiredTrialingSubscription = subscription(
      plan: 'plus',
      status: 'trialing',
      currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(expiredTrialingSubscription.isSubscribed, isFalse);
    expect(hasPremiumPlanAccess(expiredTrialingSubscription), isFalse);
  });
}
