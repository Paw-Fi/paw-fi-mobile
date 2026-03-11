import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';

class OnboardingBudgetRecommendation {
  const OnboardingBudgetRecommendation({
    required this.recommendedTemplateId,
    required this.pockets,
    required this.fixedCostsExceedBudget,
    required this.blockingError,
    required this.totalBudget,
    required this.fixedCostsTotal,
    required this.leftoverAfterFixed,
  });

  final String recommendedTemplateId;
  final List<PocketTemplate> pockets;
  final bool fixedCostsExceedBudget;
  final String? blockingError;
  final double totalBudget;
  final double fixedCostsTotal;
  final double leftoverAfterFixed;

  bool get hasBlockingError => blockingError != null;
}

class BudgetRecommender {
  static OnboardingBudgetRecommendation recommend(
      BuildContext context, OnboardingPreauthDraft draft) {
    final totalBudget = draft.monthlyBudget;
    if (totalBudget <= 0) {
      return OnboardingBudgetRecommendation(
        recommendedTemplateId: _selectTemplateId(draft),
        pockets: const [],
        fixedCostsExceedBudget: false,
        blockingError:
            context.l10n.addYourMonthlyAmountBeforeWeCanBuildYourPocketPlan,
        totalBudget: totalBudget,
        fixedCostsTotal: 0,
        leftoverAfterFixed: 0,
      );
    }

    final fixedAmounts = <String, double>{};
    final utilitiesKnownAmount = draft.utilitiesKnown
        ? _safeAmount(draft.utilitiesAmount)
        : _estimatedUtilitiesAmount(draft, totalBudget);
    final housingKnownAmount =
        draft.housingType == 'rent' || draft.housingType == 'mortgage'
            ? _safeAmount(draft.housingPayment)
            : 0.0;
    final housingEstimatedAmount = _estimatedHousingAmount(draft, totalBudget);
    final housingAmount = housingKnownAmount > 0
        ? housingKnownAmount
        : (housingEstimatedAmount ?? 0.0);
    final debtMinimum = _safeAmount(draft.debtMinimumPayments);
    final savingsAmount = _computeSavingsAmount(draft, totalBudget);
    final dependentsKnownAmount =
        draft.hasDependents ? _safeAmount(draft.dependentsCostAmount) : 0.0;
    final sharedBillsEnabled = _needsSharedBillsPocket(draft);
    final sharedGroceries =
        sharedBillsEnabled && draft.onboardingFocus == 'keep_shared_expenses';

    fixedAmounts[context.l10n.categoryHousing] = housingAmount;
    fixedAmounts[context.l10n.categoryUtilities] = utilitiesKnownAmount;
    fixedAmounts[context.l10n.categoryDebtPayments] = debtMinimum;
    fixedAmounts[context.l10n.categorySavingsFuture] = savingsAmount;
    if (dependentsKnownAmount > 0) {
      fixedAmounts[context.l10n.categoryKidsDependents] = dependentsKnownAmount;
    }

    if (sharedBillsEnabled) {
      final sharedFixed =
          (fixedAmounts.remove(context.l10n.categoryHousing) ?? 0) +
              (fixedAmounts.remove(context.l10n.categoryUtilities) ?? 0);
      if (sharedFixed > 0) {
        fixedAmounts[context.l10n.categorySharedBills] =
            (fixedAmounts[context.l10n.categorySharedBills] ?? 0) + sharedFixed;
      }
    }

    final fixedSubtotal = fixedAmounts.values.fold<double>(0, (a, b) => a + b);
    final leftover = totalBudget - fixedSubtotal;

    if (leftover < 0) {
      return OnboardingBudgetRecommendation(
        recommendedTemplateId: _selectTemplateId(draft),
        pockets:
            _buildFixedOnlyPockets(context, totalBudget, fixedAmounts, draft),
        fixedCostsExceedBudget: true,
        blockingError: context.l10n
            .yourFixedCostsAreHigherThanYourTotalIncreaseYourTotalOrLowerAFixedAmountToContinue,
        totalBudget: totalBudget,
        fixedCostsTotal: fixedSubtotal,
        leftoverAfterFixed: leftover,
      );
    }

    final variablePoints = <String, double>{
      context.l10n.categoryGroceries: 1.0,
      context.l10n.categoryTransport: 0.9,
      context.l10n.categoryEverydaySpending: 0.85,
      context.l10n.fun: 0.65,
      context.l10n.categoryTrueExpenses: 0.7,
      context.l10n.categoryBuffer: _bufferBasePoints(draft.bufferPreference),
    };

    if (utilitiesKnownAmount <= 0) {
      variablePoints[context.l10n.categoryUtilities] = 0.5;
    }
    if (housingAmount <= 0 && draft.housingType != 'none') {
      variablePoints[context.l10n.categoryHousing] = 1.0;
    }

    if (draft.eatingOutFrequency != 'rarely') {
      variablePoints[context.l10n.diningOut] =
          draft.eatingOutFrequency == 'often' ? 0.85 : 0.5;
      variablePoints[context.l10n.categoryGroceries] = math.max(
        0.5,
        variablePoints[context.l10n.categoryGroceries]! -
            (draft.eatingOutFrequency == 'often' ? 0.25 : 0.1),
      );
    }

    switch (draft.subscriptionsLevel) {
      case 'many':
        variablePoints[context.l10n.categorySubscriptions] = 0.5;
        break;
      case 'few':
        variablePoints[context.l10n.categorySubscriptions] = 0.25;
        break;
      case 'none':
        break;
      default:
        break;
    }

    if (draft.hasPets) {
      variablePoints[context.l10n.categoryPets] = switch (draft.petSpendLevel) {
        'low' => 0.2,
        'high' => 0.5,
        _ => 0.35,
      };
    }

    if (draft.hasDependents && dependentsKnownAmount <= 0) {
      variablePoints[context.l10n.categoryKidsDependents] = 0.75;
    }

    if (draft.transportMode == 'car') {
      variablePoints[context.l10n.categoryTransport] =
          variablePoints[context.l10n.categoryTransport]! + 0.2;
    }
    if (draft.transportMode == 'mixed') {
      variablePoints[context.l10n.categoryTransport] =
          variablePoints[context.l10n.categoryTransport]! + 0.1;
    }

    switch (draft.lifestyleFocus) {
      case 'student':
        variablePoints[context.l10n.categoryGroceries] =
            variablePoints[context.l10n.categoryGroceries]! + 0.15;
        variablePoints[context.l10n.categoryTrueExpenses] =
            variablePoints[context.l10n.categoryTrueExpenses]! + 0.1;
        variablePoints[context.l10n.fun] =
            math.max(0.3, variablePoints[context.l10n.fun]! - 0.15);
        variablePoints[context.l10n.categoryEverydaySpending] = math.max(
            0.55, variablePoints[context.l10n.categoryEverydaySpending]! - 0.1);
        break;
      case 'freelancer':
        variablePoints[context.l10n.categoryBuffer] =
            variablePoints[context.l10n.categoryBuffer]! + 0.25;
        variablePoints[context.l10n.categoryTrueExpenses] =
            variablePoints[context.l10n.categoryTrueExpenses]! + 0.25;
        break;
      case 'commuter':
        variablePoints[context.l10n.categoryTransport] =
            variablePoints[context.l10n.categoryTransport]! + 0.25;
        break;
      case 'foodies':
        variablePoints[context.l10n.diningOut] =
            (variablePoints[context.l10n.diningOut] ?? 0.45) + 0.2;
        variablePoints[context.l10n.fun] =
            variablePoints[context.l10n.fun]! + 0.15;
        break;
      default:
        break;
    }

    if (draft.primaryGoal == 'travel' ||
        draft.planAheadSelections.contains('travel')) {
      variablePoints[context.l10n.categoryTravelEventFund] = 0.7;
    }

    if (draft.primaryGoal == 'debt' && debtMinimum <= 0) {
      variablePoints[context.l10n.categoryDebtPayments] = 0.3;
    }

    if (sharedBillsEnabled) {
      variablePoints[context.l10n.categorySharedBills] =
          draft.billSplitFrequency == 'often' ? 0.75 : 0.45;
    }

    if (sharedBillsEnabled) {
      final movedPoints =
          (variablePoints.remove(context.l10n.categoryHousing) ?? 0) +
              (variablePoints.remove(context.l10n.categoryUtilities) ?? 0) +
              (sharedGroceries
                  ? (variablePoints.remove(context.l10n.categoryGroceries) ?? 0)
                  : 0);
      if (movedPoints > 0) {
        variablePoints[context.l10n.categorySharedBills] =
            (variablePoints[context.l10n.categorySharedBills] ?? 0) +
                movedPoints;
      }
    }

    final planAheadCount = draft.planAheadSelections.length;
    if (planAheadCount > 0) {
      variablePoints[context.l10n.categoryTrueExpenses] =
          variablePoints[context.l10n.categoryTrueExpenses]! +
              (0.2 * planAheadCount.clamp(1, 4));
    }

    if (draft.primaryGoal == 'save') {
      variablePoints[context.l10n.fun] =
          math.max(0.3, variablePoints[context.l10n.fun]! - 0.2);
    }
    if (draft.primaryGoal == 'debt') {
      variablePoints[context.l10n.fun] =
          math.max(0.25, variablePoints[context.l10n.fun]! - 0.25);
    }

    final variableSum =
        variablePoints.values.fold<double>(0, (acc, value) => acc + value);
    final amounts = <String, double>{...fixedAmounts};
    if (variableSum > 0 && leftover > 0) {
      for (final entry in variablePoints.entries) {
        final share = entry.value / variableSum;
        amounts[entry.key] = (amounts[entry.key] ?? 0) + (leftover * share);
      }
    }

    final pockets = _buildPocketsFromAmounts(
      context: context,
      totalBudget: totalBudget,
      amounts: amounts,
      includeZeroWeightCore: true,
      draft: draft,
    );
    _normalizeWeights(context, pockets);

    return OnboardingBudgetRecommendation(
      recommendedTemplateId: _selectTemplateId(draft),
      pockets: pockets,
      fixedCostsExceedBudget: false,
      blockingError: null,
      totalBudget: totalBudget,
      fixedCostsTotal: fixedSubtotal,
      leftoverAfterFixed: leftover,
    );
  }

  static double _computeSavingsAmount(
      OnboardingPreauthDraft draft, double total) {
    switch (draft.savingsMode) {
      case 'amount':
        return _safeAmount(draft.savingsAmount);
      case 'percent':
        return total * draft.savingsPercent.clamp(0.0, 1.0);
      case 'not_sure':
        final percent = switch (draft.primaryGoal) {
          'debt' => 0.05,
          'save' => 0.15,
          'travel' => 0.08,
          _ => 0.10,
        };
        return total * percent;
      default:
        return total * 0.1;
    }
  }

  static double _safeAmount(double value) =>
      value.isFinite ? math.max(0, value) : 0;

  static double? _estimatedHousingAmount(
    OnboardingPreauthDraft draft,
    double total,
  ) {
    if (draft.housingType == 'family_home') {
      return total * 0.12;
    }
    if (draft.housingType == 'paid_off') {
      return total * 0.08;
    }
    if ((draft.housingType == 'rent' || draft.housingType == 'mortgage') &&
        draft.housingPayment <= 0) {
      final ratio = draft.housingType == 'mortgage' ? 0.31 : 0.28;
      return total * ratio;
    }
    if (draft.housingType != 'not_sure') {
      return null;
    }

    final ratio = switch (draft.livingSituation) {
      'roommates' => 0.22,
      'family' => 0.16,
      'owning' => 0.30,
      _ => 0.28,
    };

    return total * ratio;
  }

  static double _estimatedUtilitiesAmount(
    OnboardingPreauthDraft draft,
    double total,
  ) {
    if (total <= 0) return 0;

    final ratio = switch (draft.livingSituation) {
      'roommates' => 0.06,
      'family' => 0.07,
      _ => 0.08,
    };

    return total * ratio;
  }

  static String _selectTemplateId(OnboardingPreauthDraft draft) {
    if (draft.householdProfile == 'family' && draft.hasPets) {
      return 'family_pets';
    }
    if (draft.primaryGoal == 'travel') {
      return switch (draft.householdProfile) {
        'couple' => 'couple_travel',
        'mates' => 'mates_nomads',
        'family' => 'family_hosts',
        _ => 'personal_freelancer',
      };
    }
    if (draft.primaryGoal == 'debt') {
      return switch (draft.householdProfile) {
        'couple' => 'couple_debt_free',
        'family' => 'family_single_income',
        'mates' => 'mates_minimalist',
        _ => 'personal_student',
      };
    }
    if (draft.lifestyleFocus == 'foodies') {
      return switch (draft.householdProfile) {
        'couple' => 'couple_foodies',
        'family' => 'family_hosts',
        'mates' => 'mates_party',
        _ => 'personal_luxury',
      };
    }
    if (draft.lifestyleFocus == 'commuter') {
      return switch (draft.householdProfile) {
        'couple' => 'couple_dink',
        'family' => 'family_balanced',
        'mates' => 'mates_split',
        _ => 'personal_commuter',
      };
    }
    return switch (draft.householdProfile) {
      'couple' => 'couple_dink',
      'family' => 'family_balanced',
      'mates' => 'mates_split',
      _ => 'personal_freelancer',
    };
  }

  static bool _needsSharedBillsPocket(OnboardingPreauthDraft draft) {
    if (draft.billSplitFrequency == 'none') {
      return false;
    }
    return draft.wantsSharedSpace ||
        draft.householdProfile == 'couple' ||
        draft.householdProfile == 'family' ||
        draft.householdProfile == 'mates';
  }

  static double _bufferBasePoints(String preference) {
    return switch (preference) {
      'small' => 0.35,
      'extra' => 0.9,
      _ => 0.6,
    };
  }

  static List<PocketTemplate> _buildFixedOnlyPockets(
    BuildContext context,
    double total,
    Map<String, double> fixedAmounts,
    OnboardingPreauthDraft draft,
  ) {
    return _buildPocketsFromAmounts(
      context: context,
      totalBudget: total,
      amounts: fixedAmounts,
      includeZeroWeightCore: true,
      draft: draft,
    );
  }

  static List<PocketTemplate> _buildPocketsFromAmounts({
    required BuildContext context,
    required double totalBudget,
    required Map<String, double> amounts,
    required bool includeZeroWeightCore,
    required OnboardingPreauthDraft draft,
  }) {
    final normalized = <String, double>{};
    amounts.forEach((key, value) {
      final safe = _safeAmount(value);
      if (safe > 0 || (includeZeroWeightCore && _isCorePocket(context, key))) {
        normalized[key] = safe;
      }
    });

    final result = <PocketTemplate>[];
    for (final entry in normalized.entries) {
      final meta = _metaByPocketName(context)[entry.key] ??
          _metaByPocketName(context)[context.l10n.categoryBuffer]!;
      result.add(
        PocketTemplate(
          name: entry.key,
          weight: totalBudget > 0 ? entry.value / totalBudget : 0,
          iconName: meta.iconName,
          suggestedCategories: meta.categories,
          color: meta.color,
        ),
      );
    }

    result.sort((a, b) {
      final leftOrder = _pocketOrder(context)[a.name] ?? 999;
      final rightOrder = _pocketOrder(context)[b.name] ?? 999;
      return leftOrder.compareTo(rightOrder);
    });
    return _canonicalizeAndDeduplicateCategories(context, result, draft: draft);
  }

  static bool _isCorePocket(BuildContext context, String name) {
    return name == context.l10n.categoryHousing ||
        name == context.l10n.categoryUtilities ||
        name == context.l10n.categoryGroceries ||
        name == context.l10n.categoryTransport ||
        name == context.l10n.categoryEverydaySpending ||
        name == context.l10n.categorySavingsFuture ||
        name == context.l10n.categoryBuffer ||
        name == context.l10n.categoryTrueExpenses;
  }

  static List<PocketTemplate> _canonicalizeAndDeduplicateCategories(
    BuildContext context,
    List<PocketTemplate> pockets, {
    required OnboardingPreauthDraft draft,
  }) {
    final sharedBillsEnabled = _needsSharedBillsPocket(draft);
    final sharedGroceries =
        sharedBillsEnabled && draft.onboardingFocus == 'keep_shared_expenses';
    final usedCategories = <String>{};
    final pocketNames = pockets.map((pocket) => pocket.name).toSet();
    final normalized = <PocketTemplate>[];
    final pocketByName = <String, PocketTemplate>{
      for (final pocket in pockets) pocket.name: pocket,
    };

    final ownershipPriority = <String>[
      context.l10n.categorySharedBills,
      context.l10n.categoryHousing,
      context.l10n.categoryUtilities,
      context.l10n.categoryGroceries,
      context.l10n.categoryDebtPayments,
      context.l10n.categorySubscriptions,
      context.l10n.categoryPets,
      context.l10n.categoryKidsDependents,
      context.l10n.categoryTransport,
      context.l10n.categoryTravelEventFund,
      context.l10n.categoryTrueExpenses,
      context.l10n.categoryEverydaySpending,
      context.l10n.categorySavingsFuture,
      context.l10n.categoryBuffer,
    ];

    final suggestedByPocket = <String, List<String>>{
      for (final name in pocketNames) name: const <String>[],
    };

    for (final pocketName in ownershipPriority) {
      if (!pocketByName.containsKey(pocketName)) continue;
      final candidates = _candidateCategoriesForPocket(
        context: context,
        pocketName: pocketName,
        sharedBillsEnabled: sharedBillsEnabled,
        sharedGroceries: sharedGroceries,
      );
      if (candidates.isEmpty) {
        suggestedByPocket[pocketName] = const <String>[];
        continue;
      }

      final categories = <String>[];
      for (final category in candidates) {
        final localized = category.trim();
        if (localized.isEmpty) continue;
        final localizedKey = localized.toLowerCase();
        if (usedCategories.contains(localizedKey)) continue;
        usedCategories.add(localizedKey);
        categories.add(localized);
      }
      suggestedByPocket[pocketName] = categories;
    }

    for (final pocket in pockets) {
      final categories = suggestedByPocket[pocket.name] ?? const <String>[];
      normalized.add(
        pocket.copyWith(suggestedCategories: categories),
      );
    }

    return normalized;
  }

  static List<String> _candidateCategoriesForPocket({
    required BuildContext context,
    required String pocketName,
    required bool sharedBillsEnabled,
    required bool sharedGroceries,
  }) {
    if (_manualOnlyPockets(context).contains(pocketName)) {
      return const <String>[];
    }

    if (pocketName == context.l10n.categorySharedBills) {
      if (!sharedBillsEnabled) {
        return const <String>[];
      }
      return [
        context.l10n.categoryRent,
        context.l10n.categoryMortgage,
        context.l10n.categoryHomeRepairs,
        context.l10n.categoryHomeServices,
        context.l10n.categoryHomeInsurance,
        context.l10n.categoryRentersInsurance,
        context.l10n.categoryElectricity,
        context.l10n.categoryWater,
        context.l10n.categoryHeatingGas,
        context.l10n.categoryInternet,
        context.l10n.categoryPhoneBill,
        context.l10n.categoryTrashRecycling,
        context.l10n.categoryHomeSecurity,
        if (sharedGroceries) context.l10n.categoryGroceries,
        if (sharedGroceries) context.l10n.categoryHouseholdSupplies,
        if (sharedGroceries) context.l10n.categoryCleaningSupplies,
      ];
    } else if (pocketName == context.l10n.categoryHousing ||
        pocketName == context.l10n.categoryUtilities) {
      if (sharedBillsEnabled) {
        return const <String>[];
      }
    } else if (pocketName == context.l10n.categoryGroceries) {
      if (sharedGroceries) {
        return const <String>[];
      }
    } else if (pocketName == context.l10n.categorySavingsFuture) {
      return const <String>[];
    }

    return _metaByPocketName(context)[pocketName]?.categories ??
        const <String>[];
  }

  static void _normalizeWeights(
      BuildContext context, List<PocketTemplate> pockets) {
    if (pockets.isEmpty) return;
    final sum = pockets.fold<double>(0, (acc, p) => acc + p.weight);
    if (sum <= 0) return;

    final normalized = <PocketTemplate>[];
    for (final pocket in pockets) {
      normalized.add(pocket.copyWith(weight: pocket.weight / sum));
    }

    final normalizedSum =
        normalized.fold<double>(0, (acc, p) => acc + p.weight);
    final delta = 1.0 - normalizedSum;
    final adjusted = <PocketTemplate>[...normalized];
    if (delta.abs() < 0.000001) {
      pockets
        ..clear()
        ..addAll(adjusted);
      return;
    }

    final bufferIndex =
        adjusted.indexWhere((p) => p.name == context.l10n.categoryBuffer);
    final targetIndex = bufferIndex >= 0 ? bufferIndex : 0;
    final target = adjusted[targetIndex];
    adjusted[targetIndex] = target.copyWith(
      weight: math.max(0, target.weight + delta),
    );

    pockets
      ..clear()
      ..addAll(adjusted);
  }
}

class _PocketMeta {
  const _PocketMeta({
    required this.iconName,
    required this.categories,
    required this.color,
  });

  final String iconName;
  final List<String> categories;
  final Color color;
}

Map<String, int> _pocketOrder(BuildContext context) => {
      context.l10n.categoryHousing: 10,
      context.l10n.categoryUtilities: 20,
      context.l10n.categoryDebtPayments: 30,
      context.l10n.categorySavingsFuture: 40,
      context.l10n.categorySharedBills: 50,
      context.l10n.categoryKidsDependents: 60,
      context.l10n.categoryGroceries: 70,
      context.l10n.categoryTransport: 90,
      context.l10n.categorySubscriptions: 100,
      context.l10n.categoryPets: 110,
      context.l10n.categoryTravelEventFund: 120,
      context.l10n.categoryTrueExpenses: 130,
      context.l10n.categoryEverydaySpending: 140,
      context.l10n.categoryBuffer: 160,
    };

Map<String, _PocketMeta> _metaByPocketName(BuildContext context) => {
      context.l10n.categoryHousing: _PocketMeta(
        iconName: 'house',
        categories: [
          context.l10n.categoryRent,
          context.l10n.categoryMortgage,
          context.l10n.categoryHomeRepairs,
          context.l10n.categoryHomeServices,
          context.l10n.categoryHomeInsurance,
          context.l10n.categoryRentersInsurance,
        ],
        color: Color(0xFFEF4444),
      ),
      context.l10n.categoryUtilities: _PocketMeta(
        iconName: 'bolt',
        categories: [
          context.l10n.categoryElectricity,
          context.l10n.categoryWater,
          context.l10n.categoryHeatingGas,
          context.l10n.categoryInternet,
          context.l10n.categoryPhoneBill,
          context.l10n.categoryTrashRecycling,
          context.l10n.categoryHomeSecurity,
        ],
        color: Color(0xFF3B82F6),
      ),
      context.l10n.categoryDebtPayments: _PocketMeta(
        iconName: 'credit_card',
        categories: [
          context.l10n.categoryDebtPayments,
          context.l10n.categoryLoanPayments,
        ],
        color: Color(0xFFB91C1C),
      ),
      context.l10n.categorySavingsFuture: _PocketMeta(
        iconName: 'savings',
        categories: [
          context.l10n.categorySavings,
          context.l10n.categoryInvestments,
        ],
        color: Color(0xFF10B981),
      ),
      context.l10n.categorySharedBills: const _PocketMeta(
        iconName: 'groups',
        categories: [],
        color: Color(0xFF0EA5E9),
      ),
      context.l10n.categoryKidsDependents: _PocketMeta(
        iconName: 'child_care',
        categories: [
          context.l10n.categoryChildcare,
          context.l10n.categorySchoolSupplies,
          context.l10n.categoryKidsActivities,
          context.l10n.categoryKidsClothing,
          context.l10n.categoryToysGames,
          context.l10n.categoryBabySupplies,
        ],
        color: Color(0xFFF59E0B),
      ),
      context.l10n.categoryGroceries: _PocketMeta(
        iconName: 'local_grocery_store',
        categories: [
          context.l10n.categoryGroceries,
          context.l10n.categoryHouseholdSupplies,
          context.l10n.categoryCleaningSupplies,
        ],
        color: Color(0xFF14B8A6),
      ),
      context.l10n.categoryRestaurants: _PocketMeta(
        iconName: 'restaurant',
        categories: [
          context.l10n.categoryRestaurants,
          context.l10n.categoryTakeoutDelivery,
          context.l10n.categoryCoffeeTea,
          context.l10n.categoryBarsDrinks,
        ],
        color: Color(0xFFEC4899),
      ),
      context.l10n.categoryTransport: _PocketMeta(
        iconName: 'directions_car',
        categories: [
          context.l10n.categoryFuelGas,
          context.l10n.categoryPublicTransport,
          context.l10n.categoryTaxiRideApps,
          context.l10n.categoryParking,
          context.l10n.categoryTolls,
          context.l10n.categoryCarRepairs,
          context.l10n.categoryCarParts,
          context.l10n.categoryCarRental,
          context.l10n.categoryBikeScooter,
        ],
        color: Color(0xFF6366F1),
      ),
      context.l10n.categorySubscriptions: _PocketMeta(
        iconName: 'subscriptions',
        categories: [
          context.l10n.categoryMusicStreaming,
          context.l10n.categorySoftwareTools,
          context.l10n.categoryFitnessGym,
          context.l10n.categoryCloudStorage,
        ],
        color: Color(0xFF8B5CF6),
      ),
      context.l10n.categoryPets: _PocketMeta(
        iconName: 'pets',
        categories: [
          context.l10n.categoryPetFood,
          context.l10n.categoryPetSupplies,
          context.l10n.categoryVetVisits,
          context.l10n.categoryPetGrooming,
          context.l10n.categoryPetInsurance,
        ],
        color: Color(0xFFEAB308),
      ),
      context.l10n.categoryTravelEventFund: _PocketMeta(
        iconName: 'flight',
        categories: [
          context.l10n.categoryTravel,
          context.l10n.categoryFlights,
          context.l10n.categoryConcertsEvents,
          context.l10n.categoryGifts,
        ],
        color: Color(0xFF06B6D4),
      ),
      context.l10n.categoryTrueExpenses: _PocketMeta(
        iconName: 'calendar_today',
        categories: [
          context.l10n.categoryClothingShoes,
          context.l10n.categoryAppliances,
          context.l10n.categoryFurniture,
          context.l10n.categoryPersonalCare,
          context.l10n.categoryMedicalCare,
          context.l10n.categoryCoursesClasses,
        ],
        color: Color(0xFF6366F1),
      ),
      context.l10n.categoryEverydaySpending: _PocketMeta(
        iconName: 'coffee',
        categories: [
          context.l10n.categoryCoffeeTea,
          context.l10n.categorySnacks,
          context.l10n.categoryPersonalCare,
          context.l10n.categoryMiscellaneous,
          context.l10n.categoryPharmacy,
        ],
        color: Color(0xFFEA580C),
      ),
      context.l10n.fun: _PocketMeta(
        iconName: 'celebration',
        categories: [
          context.l10n.categoryHobbies,
          context.l10n.categoryMoviesShows,
          context.l10n.categoryConcertsEvents,
          context.l10n.categorySportsClubs,
          context.l10n.categoryCraftsArt,
          context.l10n.categoryDating,
          context.l10n.categoryPartiesHosting,
          context.l10n.categoryCollectibles,
        ],
        color: Color(0xFFA855F7),
      ),
      context.l10n.categoryBuffer: const _PocketMeta(
        iconName: 'account_balance_wallet',
        categories: [],
        color: Color(0xFF334155),
      ),
    };

Set<String> _manualOnlyPockets(BuildContext context) => {
      context.l10n.categoryBuffer,
    };
