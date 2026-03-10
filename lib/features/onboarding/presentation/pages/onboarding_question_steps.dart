import 'package:flutter/widgets.dart';
import 'package:moneko/core/l10n/l10n.dart';

class OnboardingQuestionOption {
  const OnboardingQuestionOption({
    required this.labelKey,
    required this.value,
  });

  final String labelKey;
  final String value;

  String getLabel(BuildContext context) {
    return switch (labelKey) {
      'onboardingQuestionHousingMortgage' => context.l10n.onboardingQuestionHousingMortgage,
      'onboardingQuestionHousingRenting' => context.l10n.onboardingQuestionHousingRenting,
      'onboardingQuestionHousingFamily' => context.l10n.onboardingQuestionHousingFamily,
      'onboardingQuestionHousingOwn' => context.l10n.onboardingQuestionHousingOwn,
      'onboardingQuestionSplitOften' => context.l10n.onboardingQuestionSplitOften,
      'onboardingQuestionSplitSometimes' => context.l10n.onboardingQuestionSplitSometimes,
      'onboardingQuestionSplitNever' => context.l10n.onboardingQuestionSplitNever,
      'onboardingQuestionSubscriptionsMany' => context.l10n.onboardingQuestionSubscriptionsMany,
      'onboardingQuestionSubscriptionsFew' => context.l10n.onboardingQuestionSubscriptionsFew,
      'onboardingQuestionSubscriptionsNone' => context.l10n.onboardingQuestionSubscriptionsNone,
      'onboardingQuestionStyleStudent' => context.l10n.onboardingQuestionStyleStudent,
      'onboardingQuestionStyleFreelancer' => context.l10n.onboardingQuestionStyleFreelancer,
      'onboardingQuestionStyleCommuter' => context.l10n.onboardingQuestionStyleCommuter,
      'onboardingQuestionStyleFoodies' => context.l10n.onboardingQuestionStyleFoodies,
      'onboardingQuestionGoalBalanced' => context.l10n.onboardingQuestionGoalBalanced,
      'onboardingQuestionGoalSave' => context.l10n.onboardingQuestionGoalSave,
      'onboardingQuestionGoalDebt' => context.l10n.onboardingQuestionGoalDebt,
      'onboardingQuestionGoalTravel' => context.l10n.onboardingQuestionGoalTravel,
      'onboardingQuestionSavingsFixed' => context.l10n.onboardingQuestionSavingsFixed,
      'onboardingQuestionSavingsPercent' => context.l10n.onboardingQuestionSavingsPercent,
      'onboardingQuestionSavingsNotSure' => context.l10n.onboardingQuestionSavingsNotSure,
      _ => labelKey,
    };
  }
}

class OnboardingQuestionStep {
  const OnboardingQuestionStep({
    required this.titleKey,
    required this.options,
  });

  final String titleKey;
  final List<OnboardingQuestionOption> options;

  String getTitle(BuildContext context) {
    return switch (titleKey) {
      'onboardingQuestionHousingTitle' => context.l10n.onboardingQuestionHousingTitle,
      'onboardingQuestionSplitTitle' => context.l10n.onboardingQuestionSplitTitle,
      'onboardingQuestionSubscriptionsTitle' => context.l10n.onboardingQuestionSubscriptionsTitle,
      'onboardingQuestionEatingOutTitle' => context.l10n.onboardingQuestionEatingOutTitle,
      'onboardingQuestionStyleTitle' => context.l10n.onboardingQuestionStyleTitle,
      'onboardingQuestionGoalTitle' => context.l10n.onboardingQuestionGoalTitle,
      'onboardingQuestionSavingsTitle' => context.l10n.onboardingQuestionSavingsTitle,
      _ => titleKey,
    };
  }
}

const onboardingSharedQuestionSteps = <OnboardingQuestionStep>[
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionHousingTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionHousingMortgage', value: 'mortgage'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionHousingRenting', value: 'rent'),
      OnboardingQuestionOption(
        labelKey: 'onboardingQuestionHousingFamily',
        value: 'family_home',
      ),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionHousingOwn', value: 'paid_off'),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionSplitTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitOften', value: 'often'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitSometimes', value: 'sometimes'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitRarely', value: 'rarely'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitNever', value: 'none'),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionSubscriptionsTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSubscriptionsMany', value: 'many'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSubscriptionsFew', value: 'few'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSubscriptionsNone', value: 'none'),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionEatingOutTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitOften', value: 'often'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitSometimes', value: 'sometimes'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSplitRarely', value: 'rarely'),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionStyleTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionStyleStudent', value: 'student'),
      OnboardingQuestionOption(
        labelKey: 'onboardingQuestionStyleFreelancer',
        value: 'freelancer',
      ),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionStyleCommuter', value: 'commuter'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionStyleFoodies', value: 'foodies'),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionGoalTitle',
    options: [
      OnboardingQuestionOption(labelKey: 'onboardingQuestionGoalBalanced', value: 'balanced'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionGoalSave', value: 'save'),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionGoalDebt', value: 'debt'),
      OnboardingQuestionOption(
        labelKey: 'onboardingQuestionGoalTravel',
        value: 'travel',
      ),
    ],
  ),
  OnboardingQuestionStep(
    titleKey: 'onboardingQuestionSavingsTitle',
    options: [
      OnboardingQuestionOption(
        labelKey: 'onboardingQuestionSavingsFixed',
        value: 'amount',
      ),
      OnboardingQuestionOption(
        labelKey: 'onboardingQuestionSavingsPercent',
        value: 'percent',
      ),
      OnboardingQuestionOption(labelKey: 'onboardingQuestionSavingsNotSure', value: 'not_sure'),
    ],
  ),
];

String? onboardingQuestionLabelFromValue({
  required BuildContext context,
  required int stepIndex,
  required String? value,
}) {
  if (value == null || value.isEmpty) {
    return null;
  }
  if (stepIndex < 0 || stepIndex >= onboardingSharedQuestionSteps.length) {
    return null;
  }
  for (final option in onboardingSharedQuestionSteps[stepIndex].options) {
    if (option.value == value) {
      return option.getLabel(context);
    }
  }
  return null;
}
