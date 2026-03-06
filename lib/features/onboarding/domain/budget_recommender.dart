import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';

class OnboardingBudgetRecommendation {
  const OnboardingBudgetRecommendation({
    required this.recommendedTemplateId,
    required this.pockets,
    required this.warnings,
    required this.suggestedAdjustments,
    required this.fixedCostsExceedBudget,
    required this.blockingError,
    required this.totalBudget,
    required this.fixedCostsTotal,
    required this.leftoverAfterFixed,
  });

  final String recommendedTemplateId;
  final List<PocketTemplate> pockets;
  final List<String> warnings;
  final List<String> suggestedAdjustments;
  final bool fixedCostsExceedBudget;
  final String? blockingError;
  final double totalBudget;
  final double fixedCostsTotal;
  final double leftoverAfterFixed;

  bool get hasBlockingError => blockingError != null;
}

class BudgetRecommender {
  static OnboardingBudgetRecommendation recommend(
      OnboardingPreauthDraft draft) {
    final totalBudget = draft.monthlyBudget;
    if (totalBudget <= 0) {
      return OnboardingBudgetRecommendation(
        recommendedTemplateId: _selectTemplateId(draft),
        pockets: const [],
        warnings: const [],
        suggestedAdjustments: const [
          'Enter a monthly amount to generate your starting pocket plan.',
        ],
        fixedCostsExceedBudget: false,
        blockingError:
            'Add your monthly amount before we can build your pocket plan.',
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

    fixedAmounts['Housing'] = housingAmount;
    fixedAmounts['Utilities'] = utilitiesKnownAmount;
    fixedAmounts['Debt payments'] = debtMinimum;
    fixedAmounts['Savings / future'] = savingsAmount;
    if (dependentsKnownAmount > 0) {
      fixedAmounts['Kids / dependents'] = dependentsKnownAmount;
    }

    if (sharedBillsEnabled) {
      final sharedFixed = (fixedAmounts.remove('Housing') ?? 0) +
          (fixedAmounts.remove('Utilities') ?? 0);
      if (sharedFixed > 0) {
        fixedAmounts['Shared bills'] =
            (fixedAmounts['Shared bills'] ?? 0) + sharedFixed;
      }
    }

    final fixedSubtotal = fixedAmounts.values.fold<double>(0, (a, b) => a + b);
    final leftover = totalBudget - fixedSubtotal;

    if (leftover < 0) {
      return OnboardingBudgetRecommendation(
        recommendedTemplateId: _selectTemplateId(draft),
        pockets: _buildFixedOnlyPockets(totalBudget, fixedAmounts, draft),
        warnings: const [],
        suggestedAdjustments: const [
          'Increase your monthly total, or lower one of the fixed amounts.',
        ],
        fixedCostsExceedBudget: true,
        blockingError:
            'Your fixed costs are higher than your total. Increase your total or lower a fixed amount to continue.',
        totalBudget: totalBudget,
        fixedCostsTotal: fixedSubtotal,
        leftoverAfterFixed: leftover,
      );
    }

    final variablePoints = <String, double>{
      'Groceries': 1.0,
      'Transport': 0.9,
      'Everyday spending': 0.85,
      'Fun': 0.65,
      'True expenses': 0.7,
      'Buffer': _bufferBasePoints(draft.bufferPreference),
    };

    if (utilitiesKnownAmount <= 0) {
      variablePoints['Utilities'] = 0.5;
    }
    if (housingAmount <= 0 && draft.housingType != 'none') {
      variablePoints['Housing'] = 1.0;
    }

    if (draft.eatingOutFrequency != 'rarely') {
      variablePoints['Dining out'] =
          draft.eatingOutFrequency == 'often' ? 0.85 : 0.5;
      variablePoints['Groceries'] = math.max(
        0.5,
        variablePoints['Groceries']! -
            (draft.eatingOutFrequency == 'often' ? 0.25 : 0.1),
      );
    }

    switch (draft.subscriptionsLevel) {
      case 'many':
        variablePoints['Subscriptions'] = 0.5;
        break;
      case 'few':
        variablePoints['Subscriptions'] = 0.25;
        break;
      case 'none':
        break;
      default:
        break;
    }

    if (draft.hasPets) {
      variablePoints['Pets'] = switch (draft.petSpendLevel) {
        'low' => 0.2,
        'high' => 0.5,
        _ => 0.35,
      };
    }

    if (draft.hasDependents && dependentsKnownAmount <= 0) {
      variablePoints['Kids / dependents'] = 0.75;
    }

    if (draft.transportMode == 'car') {
      variablePoints['Transport'] = variablePoints['Transport']! + 0.2;
    }
    if (draft.transportMode == 'mixed') {
      variablePoints['Transport'] = variablePoints['Transport']! + 0.1;
    }

    if (draft.primaryGoal == 'travel' ||
        draft.planAheadSelections.contains('travel')) {
      variablePoints['Travel / event fund'] = 0.7;
    }

    if (draft.primaryGoal == 'debt' && debtMinimum <= 0) {
      variablePoints['Debt payments'] = 0.3;
    }

    if (sharedBillsEnabled) {
      variablePoints['Shared bills'] =
          draft.billSplitFrequency == 'often' ? 0.75 : 0.45;
    }

    if (sharedBillsEnabled) {
      final movedPoints = (variablePoints.remove('Housing') ?? 0) +
          (variablePoints.remove('Utilities') ?? 0) +
          (sharedGroceries ? (variablePoints.remove('Groceries') ?? 0) : 0);
      if (movedPoints > 0) {
        variablePoints['Shared bills'] =
            (variablePoints['Shared bills'] ?? 0) + movedPoints;
      }
    }

    final planAheadCount = draft.planAheadSelections.length;
    if (planAheadCount > 0) {
      variablePoints['True expenses'] =
          variablePoints['True expenses']! + (0.2 * planAheadCount.clamp(1, 4));
    }

    if (draft.primaryGoal == 'save') {
      variablePoints['Fun'] = math.max(0.3, variablePoints['Fun']! - 0.2);
    }
    if (draft.primaryGoal == 'debt') {
      variablePoints['Fun'] = math.max(0.25, variablePoints['Fun']! - 0.25);
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
      totalBudget: totalBudget,
      amounts: amounts,
      includeZeroWeightCore: true,
      draft: draft,
    );
    _normalizeWeights(pockets);

    final warnings = <String>[];
    if (leftover <= totalBudget * 0.1) {
      warnings.add(
        'This is tight for day-to-day spending. Consider reducing savings/debt extras or increasing your total.',
      );
    }
    if (!draft.utilitiesKnown) {
      warnings.add(
        'Utilities is estimated from your profile. You can fine-tune it anytime.',
      );
    }
    if (housingEstimatedAmount != null && housingEstimatedAmount > 0) {
      warnings.add(
        'Housing is estimated because you selected "Not sure". Update this amount once you know it.',
      );
    }

    return OnboardingBudgetRecommendation(
      recommendedTemplateId: _selectTemplateId(draft),
      pockets: pockets,
      warnings: warnings,
      suggestedAdjustments: const [],
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
    if (draft.housingType != 'not_sure') {
      return null;
    }

    final ratio = switch (draft.livingSituation) {
      'roommates' => 0.22,
      'family' => 0.32,
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
      'family' => 0.10,
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
    double total,
    Map<String, double> fixedAmounts,
    OnboardingPreauthDraft draft,
  ) {
    return _buildPocketsFromAmounts(
      totalBudget: total,
      amounts: fixedAmounts,
      includeZeroWeightCore: true,
      draft: draft,
    );
  }

  static List<PocketTemplate> _buildPocketsFromAmounts({
    required double totalBudget,
    required Map<String, double> amounts,
    required bool includeZeroWeightCore,
    required OnboardingPreauthDraft draft,
  }) {
    final normalized = <String, double>{};
    amounts.forEach((key, value) {
      final safe = _safeAmount(value);
      if (safe > 0 || (includeZeroWeightCore && _isCorePocket(key))) {
        normalized[key] = safe;
      }
    });

    final result = <PocketTemplate>[];
    for (final entry in normalized.entries) {
      final meta = _metaByPocketName[entry.key] ?? _metaByPocketName['Buffer']!;
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
      final leftOrder = _pocketOrder[a.name] ?? 999;
      final rightOrder = _pocketOrder[b.name] ?? 999;
      return leftOrder.compareTo(rightOrder);
    });
    return _canonicalizeAndDeduplicateCategories(result, draft: draft);
  }

  static bool _isCorePocket(String name) {
    return name == 'Housing' ||
        name == 'Utilities' ||
        name == 'Groceries' ||
        name == 'Transport' ||
        name == 'Everyday spending' ||
        name == 'Savings / future' ||
        name == 'Buffer' ||
        name == 'True expenses';
  }

  static List<PocketTemplate> _canonicalizeAndDeduplicateCategories(
    List<PocketTemplate> pockets, {
    required OnboardingPreauthDraft draft,
  }) {
    final sharedBillsEnabled = _needsSharedBillsPocket(draft);
    final sharedGroceries =
        sharedBillsEnabled && draft.onboardingFocus == 'keep_shared_expenses';
    final usedCategories = <String>{};
    final allowedCategories = getExpenseCategories().toSet();
    final pocketNames = pockets.map((pocket) => pocket.name).toSet();
    final normalized = <PocketTemplate>[];
    final pocketByName = <String, PocketTemplate>{
      for (final pocket in pockets) pocket.name: pocket,
    };

    final ownershipPriority = <String>[
      'Shared bills',
      'Housing',
      'Utilities',
      'Groceries',
      'Debt payments',
      'Subscriptions',
      'Pets',
      'Kids / dependents',
      'Dining out',
      'Transport',
      'Travel / event fund',
      'True expenses',
      'Everyday spending',
      'Fun',
      'Savings / future',
      'Buffer',
    ];

    final suggestedByPocket = <String, List<String>>{
      for (final name in pocketNames) name: const <String>[],
    };

    for (final pocketName in ownershipPriority) {
      if (!pocketByName.containsKey(pocketName)) continue;
      final candidates = _candidateCategoriesForPocket(
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
        final canonical = normalizeCategory(category);
        if (!allowedCategories.contains(canonical)) continue;
        if (usedCategories.contains(canonical)) continue;
        usedCategories.add(canonical);
        categories.add(canonical);
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
    required String pocketName,
    required bool sharedBillsEnabled,
    required bool sharedGroceries,
  }) {
    if (_manualOnlyPockets.contains(pocketName)) {
      return const <String>[];
    }

    switch (pocketName) {
      case 'Shared bills':
        if (!sharedBillsEnabled) {
          return const <String>[];
        }
        return [
          'rent',
          'mortgage',
          'home repairs',
          'home services',
          'home insurance',
          'renters insurance',
          'electricity',
          'water',
          'heating & gas',
          'internet',
          'phone bill',
          'trash & recycling',
          'home security',
          if (sharedGroceries) 'groceries',
          if (sharedGroceries) 'household supplies',
          if (sharedGroceries) 'cleaning supplies',
        ];
      case 'Housing':
      case 'Utilities':
        if (sharedBillsEnabled) {
          return const <String>[];
        }
        break;
      case 'Groceries':
        if (sharedGroceries) {
          return const <String>[];
        }
        break;
      case 'Savings / future':
        return const <String>[];
      default:
        break;
    }

    return _metaByPocketName[pocketName]?.categories ?? const <String>[];
  }

  static void _normalizeWeights(List<PocketTemplate> pockets) {
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

    final bufferIndex = adjusted.indexWhere((p) => p.name == 'Buffer');
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

const Map<String, int> _pocketOrder = {
  'Housing': 10,
  'Utilities': 20,
  'Debt payments': 30,
  'Savings / future': 40,
  'Shared bills': 50,
  'Kids / dependents': 60,
  'Groceries': 70,
  'Dining out': 80,
  'Transport': 90,
  'Subscriptions': 100,
  'Pets': 110,
  'Travel / event fund': 120,
  'True expenses': 130,
  'Everyday spending': 140,
  'Fun': 150,
  'Buffer': 160,
};

const Map<String, _PocketMeta> _metaByPocketName = {
  'Housing': _PocketMeta(
    iconName: 'house',
    categories: [
      'rent',
      'mortgage',
      'home repairs',
      'home services',
      'home insurance',
      'renters insurance',
    ],
    color: Color(0xFFEF4444),
  ),
  'Utilities': _PocketMeta(
    iconName: 'bolt',
    categories: [
      'electricity',
      'water',
      'heating & gas',
      'internet',
      'phone bill',
      'trash & recycling',
      'home security',
    ],
    color: Color(0xFF3B82F6),
  ),
  'Debt payments': _PocketMeta(
    iconName: 'credit_card',
    categories: ['debt payments', 'loan payments'],
    color: Color(0xFFB91C1C),
  ),
  'Savings / future': _PocketMeta(
    iconName: 'savings',
    categories: ['savings', 'investments'],
    color: Color(0xFF10B981),
  ),
  'Shared bills': _PocketMeta(
    iconName: 'groups',
    categories: [],
    color: Color(0xFF0EA5E9),
  ),
  'Kids / dependents': _PocketMeta(
    iconName: 'child_care',
    categories: [
      'childcare',
      'school supplies',
      'kids activities',
      'kids clothing',
      'toys & games',
      'baby supplies',
    ],
    color: Color(0xFFF59E0B),
  ),
  'Groceries': _PocketMeta(
    iconName: 'local_grocery_store',
    categories: ['groceries', 'household supplies', 'cleaning supplies'],
    color: Color(0xFF14B8A6),
  ),
  'Dining out': _PocketMeta(
    iconName: 'restaurant',
    categories: [
      'restaurants',
      'takeout & delivery',
      'coffee & tea',
      'bars & drinks'
    ],
    color: Color(0xFFEC4899),
  ),
  'Transport': _PocketMeta(
    iconName: 'directions_car',
    categories: [
      'fuel / gas',
      'public transport',
      'taxi & ride apps',
      'parking',
      'tolls',
      'car repairs',
      'car parts',
      'car rental',
      'bike / scooter',
    ],
    color: Color(0xFF6366F1),
  ),
  'Subscriptions': _PocketMeta(
    iconName: 'subscriptions',
    categories: [
      'music & streaming',
      'games & apps',
      'software tools',
      'cloud storage',
    ],
    color: Color(0xFF8B5CF6),
  ),
  'Pets': _PocketMeta(
    iconName: 'pets',
    categories: [
      'pet food',
      'pet treats',
      'vet visits',
      'pet medicine',
      'pet grooming',
      'pet supplies',
      'pet insurance',
      'pet boarding / sitting',
    ],
    color: Color(0xFFFF9800),
  ),
  'Travel / event fund': _PocketMeta(
    iconName: 'flight',
    categories: [
      'travel',
      'flights',
      'hotels',
      'travel activities',
      'luggage & travel gear',
      'passport & visa fees',
    ],
    color: Color(0xFF0EA5E9),
  ),
  'True expenses': _PocketMeta(
    iconName: 'event_repeat',
    categories: [
      'insurance',
      'health insurance',
      'life insurance',
      'travel insurance',
      'medical care',
      'gifts',
      'licensing & fees',
      'taxes',
      'bank fees',
    ],
    color: Color(0xFF64748B),
  ),
  'Everyday spending': _PocketMeta(
    iconName: 'account_balance_wallet',
    categories: [
      'personal care',
      'clothing & shoes',
      'laundry / dry cleaning',
      'miscellaneous',
      'other',
    ],
    color: Color(0xFF64748B),
  ),
  'Fun': _PocketMeta(
    iconName: 'celebration',
    categories: [
      'hobbies',
      'movies & shows',
      'concerts & events',
      'sports clubs',
      'crafts & art',
      'dating',
      'parties & hosting',
      'collectibles',
    ],
    color: Color(0xFFA855F7),
  ),
  'Buffer': _PocketMeta(
    iconName: 'account_balance_wallet',
    categories: [],
    color: Color(0xFF334155),
  ),
};

const _manualOnlyPockets = <String>{
  'Buffer',
};
