import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_profile.dart';

void main() {
  test('derives starter budget and shared profile from 8-question answers', () {
    final draft = OnboardingPreauthDraft.initial().copyWith(
      housingType: 'rent',
      livingSituation: 'renting',
      billSplitFrequency: 'often',
      subscriptionsLevel: 'many',
      eatingOutFrequency: 'often',
      lifestyleFocus: 'freelancer',
      primaryGoal: 'travel',
      savingsMode: 'percent',
      savingsPercent: 0,
      selectedCurrency: 'USD',
      monthlyBudget: 0,
    );

    final derived = derivePreauthBudgetProfile(draft);

    expect(derived.monthlyBudget, greaterThan(0));
    expect(derived.householdProfile, 'mates');
    expect(derived.onboardingFocus, 'keep_shared_expenses');
    expect(derived.bufferPreference, 'extra');
    expect(derived.transportMode, 'mixed');
    expect(derived.savingsPercent, greaterThan(0));
    expect(derived.planAheadSelections, contains('travel'));
    expect(derived.planAheadSelections, contains('taxes'));
  });

  test('does not overwrite an existing monthly budget', () {
    final draft = OnboardingPreauthDraft.initial().copyWith(
      monthlyBudget: 4100,
      selectedCurrency: 'USD',
      housingType: 'paid_off',
      livingSituation: 'owning',
    );

    final derived = derivePreauthBudgetProfile(draft);

    expect(derived.monthlyBudget, 4100);
  });

  test('student profile estimates a smaller budget than foodie profile', () {
    final student = estimateStarterMonthlyBudget(
      OnboardingPreauthDraft.initial().copyWith(
        selectedCurrency: 'USD',
        housingType: 'rent',
        livingSituation: 'renting',
        lifestyleFocus: 'student',
      ),
    );
    final foodie = estimateStarterMonthlyBudget(
      OnboardingPreauthDraft.initial().copyWith(
        selectedCurrency: 'USD',
        housingType: 'rent',
        livingSituation: 'renting',
        lifestyleFocus: 'foodies',
      ),
    );

    expect(foodie, greaterThan(student));
  });
}
