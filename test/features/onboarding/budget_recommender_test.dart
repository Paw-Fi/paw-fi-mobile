import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';

double _weightOf(OnboardingBudgetRecommendation recommendation, String name) {
  return recommendation.pockets
      .firstWhere((pocket) => pocket.name == name)
      .weight;
}

void main() {
  test('weights sum to 1 and rounded cents match monthly total', () {
    final draft = OnboardingPreauthDraft.initial().copyWith(
      monthlyBudget: 3200,
      housingType: 'rent',
      housingPayment: 1200,
      utilitiesKnown: true,
      utilitiesAmount: 260,
      debtMinimumPayments: 350,
      savingsMode: 'amount',
      savingsAmount: 400,
    );

    final recommendation = BudgetRecommender.recommend(draft);
    expect(recommendation.hasBlockingError, false);

    final weightSum = recommendation.pockets
        .fold<double>(0, (sum, pocket) => sum + pocket.weight);
    expect(weightSum, closeTo(1.0, 0.0001));

    final centsTotal = recommendation.pockets.fold<int>(
      0,
      (sum, pocket) =>
          sum + (pocket.weight * draft.monthlyBudget * 100).round(),
    );
    expect((centsTotal / 100.0), closeTo(draft.monthlyBudget, 1.0));
  });

  test('fixed amounts are honored for housing debt and savings', () {
    final draft = OnboardingPreauthDraft.initial().copyWith(
      monthlyBudget: 3000,
      housingType: 'rent',
      housingPayment: 1300,
      debtMinimumPayments: 200,
      savingsMode: 'amount',
      savingsAmount: 300,
    );

    final recommendation = BudgetRecommender.recommend(draft);

    expect(_weightOf(recommendation, 'Housing') * draft.monthlyBudget,
        closeTo(1300, 0.01));
    expect(_weightOf(recommendation, 'Debt payments') * draft.monthlyBudget,
        closeTo(200, 0.01));
    expect(_weightOf(recommendation, 'Savings / future') * draft.monthlyBudget,
        closeTo(300, 0.01));
  });

  test('fixed costs greater than budget creates blocking error', () {
    final draft = OnboardingPreauthDraft.initial().copyWith(
      monthlyBudget: 1500,
      housingType: 'rent',
      housingPayment: 1200,
      debtMinimumPayments: 500,
      savingsMode: 'amount',
      savingsAmount: 200,
    );

    final recommendation = BudgetRecommender.recommend(draft);

    expect(recommendation.fixedCostsExceedBudget, true);
    expect(recommendation.hasBlockingError, true);
  });

  test('pets pocket appears only when hasPets is true', () {
    final withPets = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2400,
        hasPets: true,
        petSpendLevel: 'medium',
      ),
    );
    final withoutPets = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2400,
        hasPets: false,
      ),
    );

    expect(withPets.pockets.any((p) => p.name == 'Pets'), true);
    expect(withoutPets.pockets.any((p) => p.name == 'Pets'), false);
  });

  test('subscriptions many allocates more than subscriptions few', () {
    final many = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2500,
        subscriptionsLevel: 'many',
      ),
    );
    final few = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2500,
        subscriptionsLevel: 'few',
      ),
    );

    expect(_weightOf(many, 'Subscriptions'),
        greaterThan(_weightOf(few, 'Subscriptions')));
  });

  test('eat out often increases dining out allocation', () {
    final often = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2500,
        eatingOutFrequency: 'often',
      ),
    );
    final sometimes = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2500,
        eatingOutFrequency: 'sometimes',
      ),
    );

    expect(_weightOf(often, 'Dining out'),
        greaterThan(_weightOf(sometimes, 'Dining out')));
  });

  test('travel goal adds travel fund pocket', () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2600,
        primaryGoal: 'travel',
      ),
    );

    expect(recommendation.pockets.any((p) => p.name == 'Travel / event fund'),
        true);
  });

  test('shared bill intent adds shared bills pocket', () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2600,
        householdProfile: 'mates',
        billSplitFrequency: 'often',
      ),
    );

    expect(recommendation.pockets.any((p) => p.name == 'Shared bills'), true);
  });

  test('utilities unknown still includes utilities pocket', () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 2600,
        utilitiesKnown: false,
      ),
    );

    expect(recommendation.pockets.any((p) => p.name == 'Utilities'), true);
  });

  test('suggested categories are canonical and exclusive per recommendation',
      () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 4200,
        householdProfile: 'family',
        billSplitFrequency: 'often',
        hasPets: true,
        subscriptionsLevel: 'many',
        housingType: 'rent',
        housingPayment: 1400,
        utilitiesKnown: true,
        utilitiesAmount: 250,
      ),
    );

    final allowed = getExpenseCategories().toSet();
    final seen = <String>{};

    for (final pocket in recommendation.pockets) {
      for (final category in pocket.suggestedCategories) {
        expect(
          allowed.contains(category),
          true,
          reason: 'Unknown category: $category',
        );
        expect(
          seen.contains(category),
          false,
          reason: 'Category duplicated across pockets: $category',
        );
        seen.add(category);
      }
    }
  });

  test('housing not sure gets an estimated housing allocation', () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 3000,
        housingType: 'not_sure',
        livingSituation: 'renting',
      ),
    );

    final housingWeight = _weightOf(recommendation, 'Housing');
    expect(housingWeight, greaterThan(0));
    expect(
      recommendation.warnings.any((w) => w.toLowerCase().contains('housing')),
      true,
    );
  });

  test('shared bills owns essentials and removes housing/utilities overlap',
      () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 4200,
        householdProfile: 'couple',
        billSplitFrequency: 'often',
        onboardingFocus: 'split_bills',
      ),
    );

    final shared = recommendation.pockets
        .firstWhere((pocket) => pocket.name == 'Shared bills');
    final housing = recommendation.pockets
        .where((pocket) => pocket.name == 'Housing')
        .toList();
    final utilities = recommendation.pockets
        .where((pocket) => pocket.name == 'Utilities')
        .toList();
    final groceries = recommendation.pockets
        .where((pocket) => pocket.name == 'Groceries')
        .toList();

    expect(shared.suggestedCategories, contains('rent'));
    expect(shared.suggestedCategories, contains('internet'));
    expect(shared.suggestedCategories, isNot(contains('groceries')));
    if (housing.isNotEmpty) {
      expect(housing.first.suggestedCategories, isEmpty);
    }
    if (utilities.isNotEmpty) {
      expect(utilities.first.suggestedCategories, isEmpty);
    }
    if (groceries.isNotEmpty) {
      expect(groceries.first.suggestedCategories, contains('groceries'));
    }
  });

  test('keep shared expenses moves groceries into shared bills', () {
    final recommendation = BudgetRecommender.recommend(
      OnboardingPreauthDraft.initial().copyWith(
        monthlyBudget: 4200,
        householdProfile: 'mates',
        billSplitFrequency: 'often',
        onboardingFocus: 'keep_shared_expenses',
      ),
    );

    final shared = recommendation.pockets
        .firstWhere((pocket) => pocket.name == 'Shared bills');
    final groceries = recommendation.pockets
        .where((pocket) => pocket.name == 'Groceries')
        .toList();

    expect(shared.suggestedCategories, contains('groceries'));
    if (groceries.isNotEmpty) {
      expect(groceries.first.suggestedCategories, isEmpty);
    }
  });
}
