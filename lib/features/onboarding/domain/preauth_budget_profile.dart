import 'dart:math' as math;

import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_amounts.dart';

OnboardingPreauthDraft derivePreauthBudgetProfile(
    OnboardingPreauthDraft draft) {
  final normalizedHousingType = _normalizedHousingType(draft);
  final householdProfile = _householdProfileFor(draft, normalizedHousingType);
  final wantsSharedSpace = draft.billSplitFrequency != 'none';
  final onboardingFocus = _onboardingFocusForDraft(draft);
  final transportMode = _transportModeFor(draft.lifestyleFocus);
  final bufferPreference = _bufferPreferenceFor(draft.lifestyleFocus);
  final planAheadSelections = _planAheadSelectionsFor(draft);

  var nextDraft = draft.copyWith(
    selectedCurrency: draft.selectedCurrency.trim().toUpperCase(),
    householdProfile: householdProfile,
    wantsSharedSpace: wantsSharedSpace,
    onboardingFocus: onboardingFocus,
    transportMode: transportMode,
    bufferPreference: bufferPreference,
    planAheadSelections: planAheadSelections,
    housingType: normalizedHousingType,
  );

  final monthlyBudget = draft.monthlyBudget > 0
      ? draft.monthlyBudget
      : estimateStarterMonthlyBudget(nextDraft);
  nextDraft = nextDraft.copyWith(monthlyBudget: monthlyBudget);

  final defaultSavingsPercent = _defaultSavingsPercent(nextDraft);
  if (nextDraft.savingsMode == 'amount' && nextDraft.savingsAmount <= 0) {
    final savingsIncrement =
        preauthBudgetRangeForCurrency(nextDraft.selectedCurrency).rounding;
    nextDraft = nextDraft.copyWith(
      savingsAmount: _roundToIncrement(
        monthlyBudget * defaultSavingsPercent,
        savingsIncrement,
      ),
    );
  }
  if (nextDraft.savingsMode == 'percent' && nextDraft.savingsPercent <= 0) {
    nextDraft = nextDraft.copyWith(savingsPercent: defaultSavingsPercent);
  }

  return nextDraft;
}

double estimateStarterMonthlyBudget(OnboardingPreauthDraft draft) {
  final currency = draft.selectedCurrency.trim().toUpperCase();
  final range = preauthBudgetRangeForCurrency(currency);
  final baseline = range.baseline;

  var multiplier = 1.0;
  multiplier *= switch (_normalizedHousingType(draft)) {
    'mortgage' => 1.1,
    'rent' => 1.0,
    'family_home' => 0.78,
    'paid_off' => 0.84,
    _ => switch (draft.livingSituation) {
        'family' => 0.82,
        'owning' => 0.94,
        _ => 1.0,
      },
  };

  multiplier *= switch (draft.billSplitFrequency) {
    'often' => 0.95,
    'sometimes' => 0.98,
    'rarely' => 1.0,
    _ => 1.02,
  };

  multiplier *= switch (draft.subscriptionsLevel) {
    'many' => 1.05,
    'few' => 1.02,
    'none' => 0.98,
    _ => 1.0,
  };

  multiplier *= switch (draft.eatingOutFrequency) {
    'often' => 1.08,
    'sometimes' => 1.03,
    'rarely' => 0.97,
    _ => 1.0,
  };

  multiplier *= switch (draft.lifestyleFocus) {
    'student' => 0.82,
    'freelancer' => 1.06,
    'commuter' => 1.05,
    'foodies' => 1.09,
    _ => 1.0,
  };

  multiplier *= switch (draft.primaryGoal) {
    'debt' => 0.96,
    'save' => 0.98,
    'travel' => 1.04,
    _ => 1.0,
  };

  final estimated = (baseline * multiplier).clamp(range.min, range.max);

  return roundBudgetForCurrency(estimated.toDouble(), currency);
}

double _defaultSavingsPercent(OnboardingPreauthDraft draft) {
  var percent = switch (draft.primaryGoal) {
    'debt' => 0.05,
    'travel' => 0.08,
    'save' => 0.15,
    _ => 0.10,
  };

  if (draft.lifestyleFocus == 'student') {
    percent = math.min(percent, 0.08);
  }
  if (draft.lifestyleFocus == 'freelancer') {
    percent = math.max(percent, 0.12);
  }

  return percent;
}

String _normalizedHousingType(OnboardingPreauthDraft draft) {
  return switch (draft.housingType) {
    'mortgage' => 'mortgage',
    'rent' => 'rent',
    'family_home' => 'family_home',
    'paid_off' => 'paid_off',
    'not_sure' => 'not_sure',
    _ => switch (draft.livingSituation) {
        'owning' => 'mortgage',
        'family' => 'family_home',
        _ => 'rent',
      },
  };
}

String _householdProfileFor(
  OnboardingPreauthDraft draft,
  String normalizedHousingType,
) {
  if (draft.livingSituation == 'family' ||
      normalizedHousingType == 'family_home') {
    return 'family';
  }
  if (draft.billSplitFrequency != 'none') {
    return 'mates';
  }
  return 'personal';
}

String _onboardingFocusFor(String billSplitFrequency) {
  return switch (billSplitFrequency) {
    'often' => 'keep_shared_expenses',
    'sometimes' || 'rarely' => 'split_bills',
    _ => 'track_spending',
  };
}

String _onboardingFocusForDraft(OnboardingPreauthDraft draft) {
  if (draft.onboardingFocus == 'keep_shared_expenses' ||
      draft.onboardingFocus == 'split_bills') {
    return draft.onboardingFocus;
  }
  return _onboardingFocusFor(draft.billSplitFrequency);
}

String _transportModeFor(String lifestyleFocus) {
  return switch (lifestyleFocus) {
    'commuter' => 'car',
    'freelancer' => 'mixed',
    _ => 'mixed',
  };
}

String _bufferPreferenceFor(String lifestyleFocus) {
  return switch (lifestyleFocus) {
    'student' => 'small',
    'freelancer' => 'extra',
    _ => 'normal',
  };
}

List<String> _planAheadSelectionsFor(OnboardingPreauthDraft draft) {
  final selections = <String>{...draft.planAheadSelections};
  if (draft.primaryGoal == 'travel') {
    selections.add('travel');
  }
  if (draft.lifestyleFocus == 'freelancer') {
    selections
      ..add('taxes')
      ..add('insurance')
      ..add('income_gap');
  }
  return selections.toList(growable: false);
}

double _roundToIncrement(double amount, double increment) {
  if (amount <= 0 || increment <= 0) {
    return 0;
  }
  return (amount / increment).round() * increment;
}
