import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/onboarding/domain/onboarding_account_sync_policy.dart';

void main() {
  group('hasMeaningfulOnboardingData', () {
    test('ignores placeholder budgets with no envelopes or amounts', () {
      expect(
        hasMeaningfulOnboardingData(
          hasExpenses: false,
          hasBudgetAmounts: false,
          hasBudgetEnvelopes: false,
          hasHouseholdMembership: false,
        ),
        false,
      );
    });

    test('treats starter envelopes as meaningful existing data', () {
      expect(
        hasMeaningfulOnboardingData(
          hasExpenses: false,
          hasBudgetAmounts: false,
          hasBudgetEnvelopes: true,
          hasHouseholdMembership: false,
        ),
        true,
      );
    });

    test('treats non-zero budget amounts as meaningful existing data', () {
      expect(
        hasMeaningfulOnboardingData(
          hasExpenses: false,
          hasBudgetAmounts: true,
          hasBudgetEnvelopes: false,
          hasHouseholdMembership: false,
        ),
        true,
      );
    });
  });

  group('shouldCreateStarterBudget', () {
    test('creates starter budget when budget row has no pockets yet', () {
      expect(
        shouldCreateStarterBudget(
          forceSync: false,
          hasExistingBudgetPockets: false,
        ),
        true,
      );
    });

    test('skips starter budget when pockets already exist', () {
      expect(
        shouldCreateStarterBudget(
          forceSync: false,
          hasExistingBudgetPockets: true,
        ),
        false,
      );
    });

    test('forces starter recreation while onboarding sync is incomplete', () {
      expect(
        shouldCreateStarterBudget(
          forceSync: true,
          hasExistingBudgetPockets: true,
        ),
        true,
      );
    });
  });
}
