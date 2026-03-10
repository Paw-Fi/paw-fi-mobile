import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_profile.dart';
import 'package:moneko/l10n/app_localizations.dart';

Future<T> _withContext<T>(
  WidgetTester tester,
  T Function(BuildContext context) callback, {
  Locale locale = const Locale('en'),
}) async {
  late T result;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          result = callback(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  return result;
}

double _weightOf(OnboardingBudgetRecommendation recommendation, String name) {
  return recommendation.pockets
      .firstWhere((pocket) => pocket.name == name)
      .weight;
}

void main() {
  testWidgets('weights sum to 1 and rounded cents match monthly total',
      (tester) async {
    final recommendation = await _withContext(tester, (context) {
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

      return BudgetRecommender.recommend(context, draft);
    });

    expect(recommendation.hasBlockingError, false);

    final weightSum = recommendation.pockets
        .fold<double>(0, (sum, pocket) => sum + pocket.weight);
    expect(weightSum, closeTo(1.0, 0.0001));

    final centsTotal = recommendation.pockets.fold<int>(
      0,
      (sum, pocket) => sum + (pocket.weight * 3200 * 100).round(),
    );
    expect((centsTotal / 100.0), closeTo(3200, 1.0));
  });

  testWidgets('fixed amounts are honored for housing debt and savings',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String housingName;
    late String debtName;
    late String savingsName;

    await _withContext(tester, (context) {
      housingName = context.l10n.categoryHousing;
      debtName = context.l10n.categoryDebtPayments;
      savingsName = context.l10n.categorySavingsFuture;

      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 3000,
          housingType: 'rent',
          housingPayment: 1300,
          debtMinimumPayments: 200,
          savingsMode: 'amount',
          savingsAmount: 300,
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      _weightOf(recommendation, housingName) * 3000,
      closeTo(1300, 0.01),
    );
    expect(
      _weightOf(recommendation, debtName) * 3000,
      closeTo(200, 0.01),
    );
    expect(
      _weightOf(recommendation, savingsName) * 3000,
      closeTo(300, 0.01),
    );
  });

  testWidgets('fixed costs greater than budget creates blocking error',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String blockingMessage;

    await _withContext(tester, (context) {
      blockingMessage = context.l10n
          .yourFixedCostsAreHigherThanYourTotalIncreaseYourTotalOrLowerAFixedAmountToContinue;
      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 1500,
          housingType: 'rent',
          housingPayment: 1200,
          debtMinimumPayments: 500,
          savingsMode: 'amount',
          savingsAmount: 200,
        ),
      );
      return const SizedBox.shrink();
    });

    expect(recommendation.fixedCostsExceedBudget, true);
    expect(recommendation.hasBlockingError, true);
    expect(recommendation.blockingError, blockingMessage);
  });

  testWidgets('pocket names and categories are localized for persistence',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String housingName;
    late String groceriesName;
    late String rentLabel;
    late String groceriesLabel;

    await _withContext(
      tester,
      (context) {
        housingName = context.l10n.categoryHousing;
        groceriesName = context.l10n.categoryGroceries;
        rentLabel = context.l10n.categoryRent;
        groceriesLabel = context.l10n.categoryGroceries;
        recommendation = BudgetRecommender.recommend(
          context,
          OnboardingPreauthDraft.initial().copyWith(
            monthlyBudget: 3200,
            housingType: 'rent',
            housingPayment: 1250,
            utilitiesKnown: true,
            utilitiesAmount: 200,
          ),
        );
        return const SizedBox.shrink();
      },
      locale: const Locale('es'),
    );

    expect(recommendation.pockets.any((pocket) => pocket.name == housingName),
        true);
    expect(
      recommendation.pockets.any((pocket) => pocket.name == groceriesName),
      true,
    );

    final housingPocket = recommendation.pockets
        .firstWhere((pocket) => pocket.name == housingName);
    final groceriesPocket = recommendation.pockets
        .firstWhere((pocket) => pocket.name == groceriesName);

    expect(housingPocket.suggestedCategories, contains(rentLabel));
    expect(groceriesPocket.suggestedCategories, contains(groceriesLabel));
    expect(
      housingPocket.suggestedCategories.contains('rent'),
      false,
    );
  });

  testWidgets('pets pocket appears only when hasPets is true', (tester) async {
    late OnboardingBudgetRecommendation withPets;
    late OnboardingBudgetRecommendation withoutPets;
    late String petsName;

    await _withContext(tester, (context) {
      petsName = context.l10n.categoryPets;
      withPets = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2400,
          hasPets: true,
          petSpendLevel: 'medium',
        ),
      );
      withoutPets = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2400,
          hasPets: false,
        ),
      );
      return const SizedBox.shrink();
    });

    expect(withPets.pockets.any((p) => p.name == petsName), true);
    expect(withoutPets.pockets.any((p) => p.name == petsName), false);
  });

  testWidgets('subscriptions many allocates more than subscriptions few',
      (tester) async {
    late OnboardingBudgetRecommendation many;
    late OnboardingBudgetRecommendation few;
    late String subscriptionsName;

    await _withContext(tester, (context) {
      subscriptionsName = context.l10n.categorySubscriptions;
      many = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2500,
          subscriptionsLevel: 'many',
        ),
      );
      few = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2500,
          subscriptionsLevel: 'few',
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      _weightOf(many, subscriptionsName),
      greaterThan(_weightOf(few, subscriptionsName)),
    );
  });

  testWidgets('eat out often increases dining out allocation', (tester) async {
    late OnboardingBudgetRecommendation often;
    late OnboardingBudgetRecommendation sometimes;
    late String diningOutName;

    await _withContext(tester, (context) {
      diningOutName = context.l10n.diningOut;
      often = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2500,
          eatingOutFrequency: 'often',
        ),
      );
      sometimes = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2500,
          eatingOutFrequency: 'sometimes',
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      _weightOf(often, diningOutName),
      greaterThan(_weightOf(sometimes, diningOutName)),
    );
  });

  testWidgets('travel goal adds travel fund pocket', (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String travelFundName;

    await _withContext(tester, (context) {
      travelFundName = context.l10n.categoryTravelEventFund;
      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2600,
          primaryGoal: 'travel',
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      recommendation.pockets.any((pocket) => pocket.name == travelFundName),
      true,
    );
  });

  testWidgets('shared bill intent adds shared bills pocket', (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String sharedBillsName;

    await _withContext(tester, (context) {
      sharedBillsName = context.l10n.categorySharedBills;
      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2600,
          householdProfile: 'mates',
          billSplitFrequency: 'often',
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      recommendation.pockets.any((pocket) => pocket.name == sharedBillsName),
      true,
    );
  });

  testWidgets(
      'question-only intake still generates a starter budget recommendation',
      (tester) async {
    final recommendation = await _withContext(tester, (context) {
      final draft = derivePreauthBudgetProfile(
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 0,
          housingType: 'rent',
          livingSituation: 'renting',
          billSplitFrequency: 'sometimes',
          subscriptionsLevel: 'few',
          eatingOutFrequency: 'sometimes',
          lifestyleFocus: 'freelancer',
          primaryGoal: 'save',
          savingsMode: 'not_sure',
          selectedCurrency: 'USD',
        ),
      );
      return BudgetRecommender.recommend(context, draft);
    });

    expect(recommendation.hasBlockingError, false);
    expect(recommendation.totalBudget, greaterThan(0));
    expect(recommendation.pockets, isNotEmpty);
  });

  testWidgets('zero budget keeps localized blocking error without warnings',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String blockingMessage;

    await _withContext(
      tester,
      (context) {
        blockingMessage =
            context.l10n.addYourMonthlyAmountBeforeWeCanBuildYourPocketPlan;
        recommendation = BudgetRecommender.recommend(
          context,
          OnboardingPreauthDraft.initial().copyWith(monthlyBudget: 0),
        );
        return const SizedBox.shrink();
      },
      locale: const Locale('es'),
    );

    expect(recommendation.hasBlockingError, true);
    expect(recommendation.blockingError, blockingMessage);
    expect(recommendation.pockets, isEmpty);
  });

  testWidgets('utilities unknown still includes utilities pocket',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String utilitiesName;

    await _withContext(tester, (context) {
      utilitiesName = context.l10n.categoryUtilities;
      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 2600,
          utilitiesKnown: false,
        ),
      );
      return const SizedBox.shrink();
    });

    expect(
      recommendation.pockets.any((pocket) => pocket.name == utilitiesName),
      true,
    );
  });

  testWidgets(
      'suggested categories are localized and exclusive per recommendation',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String rentLabel;
    late String groceriesLabel;

    await _withContext(tester, (context) {
      rentLabel = context.l10n.categoryRent;
      groceriesLabel = context.l10n.categoryGroceries;
      recommendation = BudgetRecommender.recommend(
        context,
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
      return const SizedBox.shrink();
    }, locale: const Locale('es'));

    final seen = <String>{};

    for (final pocket in recommendation.pockets) {
      for (final category in pocket.suggestedCategories) {
        expect(
          seen.contains(category),
          false,
          reason: 'Category duplicated across pockets: $category',
        );
        seen.add(category);
      }
    }

    expect(seen.contains(rentLabel), true);
    expect(seen.contains(groceriesLabel), true);
    expect(seen.contains('rent'), false);
    expect(seen.contains('groceries'), false);
  });

  testWidgets(
      'housing not sure gets an estimated housing allocation without warnings',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String housingName;

    await _withContext(tester, (context) {
      housingName = context.l10n.categoryHousing;
      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 3000,
          housingType: 'not_sure',
          livingSituation: 'renting',
        ),
      );
      return const SizedBox.shrink();
    });

    expect(_weightOf(recommendation, housingName), greaterThan(0));
    expect(recommendation.hasBlockingError, false);
  });

  testWidgets(
      'shared bills owns essentials and removes housing utilities overlap',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String sharedBillsName;
    late String housingName;
    late String utilitiesName;
    late String groceriesName;
    late String rentLabel;
    late String internetLabel;

    await _withContext(tester, (context) {
      sharedBillsName = context.l10n.categorySharedBills;
      housingName = context.l10n.categoryHousing;
      utilitiesName = context.l10n.categoryUtilities;
      groceriesName = context.l10n.categoryGroceries;
      rentLabel = context.l10n.categoryRent;
      internetLabel = context.l10n.categoryInternet;

      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 4200,
          householdProfile: 'couple',
          billSplitFrequency: 'often',
          onboardingFocus: 'split_bills',
        ),
      );
      return const SizedBox.shrink();
    });

    final shared = recommendation.pockets
        .firstWhere((pocket) => pocket.name == sharedBillsName);
    final housing = recommendation.pockets
        .where((pocket) => pocket.name == housingName)
        .toList();
    final utilities = recommendation.pockets
        .where((pocket) => pocket.name == utilitiesName)
        .toList();
    final groceries = recommendation.pockets
        .where((pocket) => pocket.name == groceriesName)
        .toList();

    expect(shared.suggestedCategories, contains(rentLabel));
    expect(shared.suggestedCategories, contains(internetLabel));
    expect(shared.suggestedCategories, isNot(contains(groceriesName)));
    if (housing.isNotEmpty) {
      expect(housing.first.suggestedCategories, isEmpty);
    }
    if (utilities.isNotEmpty) {
      expect(utilities.first.suggestedCategories, isEmpty);
    }
    if (groceries.isNotEmpty) {
      expect(groceries.first.suggestedCategories, contains(groceriesName));
    }
  });

  testWidgets('keep shared expenses moves groceries into shared bills',
      (tester) async {
    late OnboardingBudgetRecommendation recommendation;
    late String sharedBillsName;
    late String groceriesName;

    await _withContext(tester, (context) {
      sharedBillsName = context.l10n.categorySharedBills;
      groceriesName = context.l10n.categoryGroceries;

      recommendation = BudgetRecommender.recommend(
        context,
        OnboardingPreauthDraft.initial().copyWith(
          monthlyBudget: 4200,
          householdProfile: 'mates',
          billSplitFrequency: 'often',
          onboardingFocus: 'keep_shared_expenses',
        ),
      );
      return const SizedBox.shrink();
    });

    final shared = recommendation.pockets
        .firstWhere((pocket) => pocket.name == sharedBillsName);
    final groceries = recommendation.pockets
        .where((pocket) => pocket.name == groceriesName)
        .toList();

    expect(shared.suggestedCategories, contains(groceriesName));
    if (groceries.isNotEmpty) {
      expect(groceries.first.suggestedCategories, isEmpty);
    }
  });
}
