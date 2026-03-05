class OnboardingQuestionOption {
  const OnboardingQuestionOption({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class OnboardingQuestionStep {
  const OnboardingQuestionStep({
    required this.title,
    required this.options,
  });

  final String title;
  final List<OnboardingQuestionOption> options;
}

const onboardingSharedQuestionSteps = <OnboardingQuestionStep>[
  OnboardingQuestionStep(
    title: 'What do you want help with?',
    options: [
      OnboardingQuestionOption(
        label: 'Keep track of shared expenses',
        value: 'keep_shared_expenses',
      ),
      OnboardingQuestionOption(label: 'Split bills', value: 'split_bills'),
      OnboardingQuestionOption(
        label: 'Stay on top of spending',
        value: 'stay_on_top',
      ),
      OnboardingQuestionOption(
        label: 'Track my own spending',
        value: 'track_spending',
      ),
      OnboardingQuestionOption(
        label: 'Plan a trip or event',
        value: 'trip_event',
      ),
      OnboardingQuestionOption(
        label: 'Keep track of receipts',
        value: 'track_receipts',
      ),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Where do you live?',
    options: [
      OnboardingQuestionOption(label: 'Renting', value: 'renting'),
      OnboardingQuestionOption(label: 'On my home', value: 'owning'),
      OnboardingQuestionOption(label: 'With roommates', value: 'roommates'),
      OnboardingQuestionOption(label: 'With family', value: 'family'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'How often do you eat out?',
    options: [
      OnboardingQuestionOption(label: 'Often', value: 'often'),
      OnboardingQuestionOption(label: 'Sometimes', value: 'sometimes'),
      OnboardingQuestionOption(label: 'Rarely', value: 'rarely'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Do you have subscriptions?',
    options: [
      OnboardingQuestionOption(label: 'Many', value: 'many'),
      OnboardingQuestionOption(label: 'A few', value: 'few'),
      OnboardingQuestionOption(label: 'None', value: 'none'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Do you have pets?',
    options: [
      OnboardingQuestionOption(label: 'Yes', value: 'yes'),
      OnboardingQuestionOption(label: 'No', value: 'no'),
    ],
  ),
];

String? onboardingQuestionLabelFromValue({
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
      return option.label;
    }
  }
  return null;
}
