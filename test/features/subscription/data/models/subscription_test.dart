import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';

void main() {
  group('Subscription - Model Creation', () {
    test('creates subscription with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        createdAt: now,
      );

      expect(subscription.id, 'sub_1');
      expect(subscription.userId, 'user_1');
      expect(subscription.createdAt, now);
      expect(subscription.stripeSubscriptionId, null);
      expect(subscription.plan, null);
      expect(subscription.status, null);
    });

    test('creates subscription with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 2, 1);
      final nextPayment = DateTime(2024, 2, 1);

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        stripeSubscriptionId: 'stripe_sub_123',
        stripeCustomerId: 'cus_123',
        plan: 'premium',
        status: 'active',
        currentPeriodEnd: periodEnd,
        nextPaymentDate: nextPayment,
        cancelAtPeriodEnd: false,
        boundToUserId: 'user_2',
        boundToHouseholdId: 'hh_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(subscription.stripeSubscriptionId, 'stripe_sub_123');
      expect(subscription.stripeCustomerId, 'cus_123');
      expect(subscription.plan, 'premium');
      expect(subscription.status, 'active');
      expect(subscription.currentPeriodEnd, periodEnd);
      expect(subscription.nextPaymentDate, nextPayment);
      expect(subscription.cancelAtPeriodEnd, false);
      expect(subscription.boundToUserId, 'user_2');
      expect(subscription.boundToHouseholdId, 'hh_1');
    });
  });

  group('Subscription - JSON Serialization', () {
    test('fromJson parses subscription correctly', () {
      final json = {
        'id': 'sub_1',
        'user_id': 'user_1',
        'stripe_subscription_id': 'stripe_sub_123',
        'stripe_customer_id': 'cus_123',
        'plan': 'premium',
        'status': 'active',
        'current_period_end': '2024-02-01T00:00:00.000Z',
        'next_payment_date': '2024-02-01T00:00:00.000Z',
        'cancel_at_period_end': false,
        'bound_to_user_id': 'user_2',
        'bound_to_household_id': 'hh_1',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final subscription = Subscription.fromJson(json);

      expect(subscription.id, 'sub_1');
      expect(subscription.userId, 'user_1');
      expect(subscription.stripeSubscriptionId, 'stripe_sub_123');
      expect(subscription.plan, 'premium');
      expect(subscription.status, 'active');
      expect(subscription.currentPeriodEnd, DateTime.utc(2024, 2, 1));
      expect(subscription.nextPaymentDate, DateTime.utc(2024, 2, 1));
      expect(subscription.cancelAtPeriodEnd, false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'sub_1',
        'user_id': 'user_1',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final subscription = Subscription.fromJson(json);

      expect(subscription.stripeSubscriptionId, null);
      expect(subscription.plan, null);
      expect(subscription.status, null);
      expect(subscription.currentPeriodEnd, null);
      expect(subscription.nextPaymentDate, null);
      expect(subscription.cancelAtPeriodEnd, null);
      expect(subscription.updatedAt, null);
    });

    test('fromJson handles invalid date strings gracefully', () {
      final json = {
        'id': 'sub_1',
        'user_id': 'user_1',
        'current_period_end': 'invalid-date',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final subscription = Subscription.fromJson(json);

      expect(subscription.currentPeriodEnd, null);
    });

    test('fromJson defaults createdAt to now if invalid', () {
      final json = {
        'id': 'sub_1',
        'user_id': 'user_1',
        'created_at': 'invalid-date',
      };

      final subscription = Subscription.fromJson(json);

      expect(subscription.createdAt, isNotNull);
      expect(
          subscription.createdAt
              .isBefore(DateTime.now().add(const Duration(seconds: 1))),
          true);
    });

    test('toJson serializes subscription correctly', () {
      final now = DateTime(2024, 1, 1);
      final periodEnd = DateTime(2024, 2, 1);

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        stripeSubscriptionId: 'stripe_sub_123',
        stripeCustomerId: 'cus_123',
        plan: 'premium',
        status: 'active',
        currentPeriodEnd: periodEnd,
        nextPaymentDate: periodEnd,
        cancelAtPeriodEnd: false,
        boundToUserId: 'user_2',
        boundToHouseholdId: 'hh_1',
        createdAt: now,
        updatedAt: now,
      );

      final json = subscription.toJson();

      expect(json['id'], 'sub_1');
      expect(json['user_id'], 'user_1');
      expect(json['stripe_subscription_id'], 'stripe_sub_123');
      expect(json['plan'], 'premium');
      expect(json['status'], 'active');
      expect(json['current_period_end'], '2024-02-01T00:00:00.000');
      expect(json['cancel_at_period_end'], false);
    });
  });

  group('Subscription - isSubscribed Logic', () {
    test('returns false for canceled status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'canceled',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('returns true for lifetime plan with active status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'lifetime',
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, true);
    });

    test('returns false for lifetime plan without active status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'lifetime',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('returns true for trialing status', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'trialing',
        currentPeriodEnd: now.add(const Duration(days: 14)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
    });

    test('returns true for active status with household binding', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'family',
        status: 'active',
        boundToUserId: 'user_2',
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
    });

    test('returns true for active status with stripe subscription', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
    });

    test('returns false for active status with free plan', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'free',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test(
        'returns false for active status without stripe subscription or binding',
        () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('returns false for null status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('returns false for pending status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'pending',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('returns false for incomplete status', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'incomplete',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });
  });

  group('Subscription - isFreePlan', () {
    test('returns true for free plan', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'free',
        createdAt: DateTime.now(),
      );

      expect(subscription.isFreePlan, true);
    });

    test('returns true for null plan', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        createdAt: DateTime.now(),
      );

      expect(subscription.isFreePlan, true);
    });

    test('returns false for premium plan', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        createdAt: DateTime.now(),
      );

      expect(subscription.isFreePlan, false);
    });

    test('returns false for lifetime plan', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'lifetime',
        createdAt: DateTime.now(),
      );

      expect(subscription.isFreePlan, false);
    });
  });

  group('Subscription - Edge Cases', () {
    test('handles subscription with expired period', () {
      final pastDate = DateTime(2023, 1, 1);
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        currentPeriodEnd: pastDate,
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
      expect(subscription.currentPeriodEnd!.isBefore(DateTime.now()), true);
    });

    test('handles subscription with future period', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 365));
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        currentPeriodEnd: futureDate,
        nextPaymentDate: futureDate,
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.currentPeriodEnd!.isAfter(now), true);
    });

    test('handles subscription with cancelAtPeriodEnd true', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        cancelAtPeriodEnd: true,
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.cancelAtPeriodEnd, true);
    });

    test('handles household-bound subscription', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'family',
        status: 'active',
        boundToUserId: 'owner_user',
        boundToHouseholdId: 'hh_1',
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.boundToHouseholdId, 'hh_1');
    });

    test('handles subscription with all null optional fields', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
      expect(subscription.isFreePlan, true);
      expect(subscription.stripeSubscriptionId, null);
      expect(subscription.status, null);
    });
  });

  group('Subscription - Subscription Logic Scenarios', () {
    test('Case 1: No subscription (free user)', () {
      // This would be represented by null in the provider
      // but if a row exists with no stripe_subscription_id
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'free',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
      expect(subscription.isFreePlan, true);
    });

    test('Case 2: Active paid subscription', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isFreePlan, false);
    });

    test('Case 3: Lifetime subscription', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'lifetime',
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isFreePlan, false);
    });

    test('Case 4: Trial period', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'trialing',
        stripeSubscriptionId: 'stripe_sub_123',
        currentPeriodEnd: now.add(const Duration(days: 14)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isFreePlan, false);
    });

    test('Case 5: Household member with shared access', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'family',
        status: 'active',
        boundToUserId: 'owner_user',
        boundToHouseholdId: 'hh_1',
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
    });

    test('Case 6: Cancelled subscription', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'canceled',
        stripeSubscriptionId: 'stripe_sub_123',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('Case 7: Subscription set to cancel at period end', () {
      final now = DateTime.now();
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        plan: 'premium',
        status: 'active',
        stripeSubscriptionId: 'stripe_sub_123',
        cancelAtPeriodEnd: true,
        currentPeriodEnd: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      // Still subscribed until period ends
      expect(subscription.isSubscribed, true);
      expect(subscription.cancelAtPeriodEnd, true);
    });
  });

  group('Subscription - IAP (In-App Purchase) Logic', () {
    test(
        'App Store subscription with active status and valid expiry returns true',
        () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'monthly',
        status: 'active',
        currentPeriodEnd: futureDate,
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isIap, true);
    });

    test(
        'Play Store subscription with active status and valid expiry returns true',
        () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 365));

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'play_store',
        plan: 'yearly',
        status: 'active',
        currentPeriodEnd: futureDate,
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isIap, true);
    });

    test('App Store subscription with expired date returns false', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 1));

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'monthly',
        status: 'active',
        currentPeriodEnd: pastDate,
        createdAt: now,
      );

      expect(subscription.isSubscribed, false);
    });

    test('App Store lifetime subscription with active status returns true', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'lifetime',
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, true);
      expect(subscription.isIap, true);
    });

    test(
        'App Store subscription without currentPeriodEnd (non-lifetime) returns false (fail-safe)',
        () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'monthly',
        status: 'active',
        currentPeriodEnd:
            null, // Missing expiry date - should fail-safe to false
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test(
        'Play Store subscription without currentPeriodEnd (non-lifetime) returns false (fail-safe)',
        () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'play_store',
        plan: 'yearly',
        status: 'active',
        currentPeriodEnd:
            null, // Missing expiry date - should fail-safe to false
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test('App Store subscription with canceled status returns false', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'monthly',
        status: 'canceled',
        currentPeriodEnd: futureDate,
        createdAt: DateTime.now(),
      );

      expect(subscription.isSubscribed, false);
    });

    test(
        'App Store subscription in billing grace period returns true until grace expiry',
        () {
      final now = DateTime.now();
      final graceExpiry = now.add(const Duration(days: 3));

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'yearly',
        status: 'past_due',
        currentPeriodEnd: graceExpiry,
        createdAt: now,
      );

      expect(subscription.isSubscribed, true);
    });

    test('isIap returns true for app_store provider', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        createdAt: DateTime.now(),
      );

      expect(subscription.isIap, true);
    });

    test('isIap returns true for play_store provider', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'play_store',
        createdAt: DateTime.now(),
      );

      expect(subscription.isIap, true);
    });

    test('isIap returns false for stripe provider', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'stripe',
        createdAt: DateTime.now(),
      );

      expect(subscription.isIap, false);
    });

    test('isIap returns false for null provider', () {
      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        createdAt: DateTime.now(),
      );

      expect(subscription.isIap, false);
    });

    test('App Store subscription edge case: expiry exactly now', () {
      final now = DateTime.now();

      final subscription = Subscription(
        id: 'sub_1',
        userId: 'user_1',
        provider: 'app_store',
        plan: 'monthly',
        status: 'active',
        currentPeriodEnd: now,
        createdAt: now,
      );

      // Should return false because isAfter(now) is false when times are equal
      expect(subscription.isSubscribed, false);
    });
  });
}
