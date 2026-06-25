import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/paywall_plan_selection.dart';

void main() {
  group('selectPaywallPlanId', () {
    test('selects the matching premium interval for a premium subscriber', () {
      final plans = [
        _plan('plus_yearly', 'plus', 'yearly'),
        _plan('premium_monthly', 'premium', 'monthly'),
        _plan('premium_yearly', 'premium', 'yearly'),
      ];

      final selected = selectPaywallPlanId(
        currentPlanId: 'premium',
        currentInterval: 'monthly',
        plans: plans,
        currentSelection: 'plus_yearly',
      );

      expect(selected, 'premium_monthly');
    });

    test('keeps Plus yearly as the default for free users', () {
      final plans = [
        _plan('premium_yearly', 'premium', 'yearly'),
        _plan('plus_yearly', 'plus', 'yearly'),
      ];

      final selected = selectPaywallPlanId(
        currentPlanId: 'free',
        currentInterval: null,
        plans: plans,
        currentSelection: null,
      );

      expect(selected, 'plus_yearly');
    });

    test('honors a preferred Premium yearly route selection', () {
      final plans = [
        _plan('premium_monthly', 'premium', 'monthly'),
        _plan('premium_yearly', 'premium', 'yearly'),
      ];

      final selected = selectPaywallPlanId(
        currentPlanId: 'free',
        currentInterval: null,
        plans: plans,
        currentSelection: null,
        preferredPlanId: 'premium',
        preferredBillingInterval: 'yearly',
      );

      expect(selected, 'premium_yearly');
    });

    test('falls back to Plus yearly when a stale selection disappears', () {
      final plans = [
        _plan('premium_yearly', 'premium', 'yearly'),
        _plan('plus_yearly', 'plus', 'yearly'),
      ];

      final selected = selectPaywallPlanId(
        currentPlanId: 'free',
        currentInterval: null,
        plans: plans,
        currentSelection: 'plus_monthly',
      );

      expect(selected, 'plus_yearly');
    });

    test('keeps a valid user selection for free users', () {
      final plans = [
        _plan('plus_monthly', 'plus', 'monthly'),
        _plan('plus_yearly', 'plus', 'yearly'),
      ];

      final selected = selectPaywallPlanId(
        currentPlanId: 'free',
        currentInterval: null,
        plans: plans,
        currentSelection: 'plus_monthly',
      );

      expect(selected, 'plus_monthly');
    });
  });
}

PlanOption _plan(String id, String serverPlanId, String? billingInterval) {
  return PlanOption(
    id: id,
    serverPlanId: serverPlanId,
    billingInterval: billingInterval,
    name: id,
    storePrice: null,
    tagline: '',
  );
}
