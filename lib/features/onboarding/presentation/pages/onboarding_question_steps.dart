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
    title: 'What\'s your housing situation?',
    options: [
      OnboardingQuestionOption(label: 'Mortgage', value: 'mortgage'),
      OnboardingQuestionOption(label: 'Renting', value: 'rent'),
      OnboardingQuestionOption(
        label: 'Living with family',
        value: 'family_home',
      ),
      OnboardingQuestionOption(label: 'Own home', value: 'paid_off'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Do you split expenses with others?',
    options: [
      OnboardingQuestionOption(label: 'Often', value: 'often'),
      OnboardingQuestionOption(label: 'Sometimes', value: 'sometimes'),
      OnboardingQuestionOption(label: 'Rarely', value: 'rarely'),
      OnboardingQuestionOption(label: 'Never', value: 'none'),
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
    title: 'How often do you eat out?',
    options: [
      OnboardingQuestionOption(label: 'Often', value: 'often'),
      OnboardingQuestionOption(label: 'Sometimes', value: 'sometimes'),
      OnboardingQuestionOption(label: 'Rarely', value: 'rarely'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Which spending style sounds most like you?',
    options: [
      OnboardingQuestionOption(label: 'Student budget', value: 'student'),
      OnboardingQuestionOption(
        label: 'Freelancer income',
        value: 'freelancer',
      ),
      OnboardingQuestionOption(label: 'Daily commute', value: 'commuter'),
      OnboardingQuestionOption(label: 'Food and fun', value: 'foodies'),
    ],
  ),
  OnboardingQuestionStep(
    title: 'What is your main money goal right now?',
    options: [
      OnboardingQuestionOption(label: 'Stay balanced', value: 'balanced'),
      OnboardingQuestionOption(label: 'Save more', value: 'save'),
      OnboardingQuestionOption(label: 'Pay off debt', value: 'debt'),
      OnboardingQuestionOption(
        label: 'Travel or experiences',
        value: 'travel',
      ),
    ],
  ),
  OnboardingQuestionStep(
    title: 'Do you want to set a savings target?',
    options: [
      OnboardingQuestionOption(
        label: 'Save a fixed amount each month',
        value: 'amount',
      ),
      OnboardingQuestionOption(
        label: 'Save a percentage of income',
        value: 'percent',
      ),
      OnboardingQuestionOption(label: 'Not sure yet', value: 'not_sure'),
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
