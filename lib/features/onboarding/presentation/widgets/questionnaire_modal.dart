import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

class QuestionnaireModal extends HookConsumerWidget {
  final Function(Map<String, dynamic>) onComplete;
  final VoidCallback onClose;

  const QuestionnaireModal({
    super.key,
    required this.onComplete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupMode = useState<String?>('customized'); // 'customized' or 'faster'
    final currentStep =
        useState<String>('setup-experience'); // 'setup-experience', 'preset-profile', 'questionnaire'
    final selectedPreset = useState<String?>(null);

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: shadcnui.Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: shadcnui.Theme.of(context).colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentStep.value == 'setup-experience'
                            ? 'Choose Your Setup'
                            : currentStep.value == 'preset-profile'
                                ? 'Choose Your Profile'
                                : 'Financial Questionnaire',
                        style: shadcnui.Theme.of(context).typography.h3,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildStep(
                    context,
                    ref,
                    currentStep,
                    setupMode,
                    selectedPreset,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<String> currentStep,
    ValueNotifier<String?> setupMode,
    ValueNotifier<String?> selectedPreset,
  ) {
    switch (currentStep.value) {
      case 'setup-experience':
        return _buildSetupExperience(context, currentStep, setupMode);
      case 'preset-profile':
        return _buildPresetProfile(context, ref, currentStep, selectedPreset);
      case 'questionnaire':
        return _buildQuestionnaire(context, ref);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSetupExperience(
    BuildContext context,
    ValueNotifier<String> currentStep,
    ValueNotifier<String?> setupMode,
  ) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          'Choose Your Setup Experience',
          style: shadcnui.Theme.of(context).typography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'How would you like to create your financial plan?',
          style: shadcnui.Theme.of(context).typography.textMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Customized Setup
        GestureDetector(
          onTap: () => setupMode.value = 'customized',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: setupMode.value == 'customized'
                  ? shadcnui.Theme.of(context).colorScheme.primary.withValues(alpha:0.1)
                  : shadcnui.Theme.of(context).colorScheme.card,
              border: Border.all(
                color: setupMode.value == 'customized'
                    ? shadcnui.Theme.of(context).colorScheme.primary
                    : shadcnui.Theme.of(context).colorScheme.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customized Setup',
                      style: shadcnui.Theme.of(context).typography.h4,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: shadcnui.Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Recommended',
                        style: shadcnui.Theme.of(context).typography.small.copyWith(
                          color: shadcnui.Theme.of(context).colorScheme.primaryForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Answer detailed questions to get a personalized financial plan tailored specifically to your situation and goals.',
                  style: shadcnui.Theme.of(context).typography.textMuted,
                ),
                const SizedBox(height: 16),
                Text('• Fully personalized recommendations',
                    style: shadcnui.Theme.of(context).typography.small),
                Text('• Detailed financial analysis',
                    style: shadcnui.Theme.of(context).typography.small),
                Text('• Custom strategies & milestones',
                    style: shadcnui.Theme.of(context).typography.small),
                const SizedBox(height: 12),
                Text('⏱ 5-8 minutes',
                    style: shadcnui.Theme.of(context).typography.textMuted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Faster Setup
        GestureDetector(
          onTap: () => setupMode.value = 'faster',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: setupMode.value == 'faster'
                  ? shadcnui.Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : shadcnui.Theme.of(context).colorScheme.card,
              border: Border.all(
                color: setupMode.value == 'faster'
                    ? shadcnui.Theme.of(context).colorScheme.primary
                    : shadcnui.Theme.of(context).colorScheme.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Faster Setup',
                      style: shadcnui.Theme.of(context).typography.h4,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16CDA2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Express',
                        style: shadcnui.Theme.of(context).typography.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose from pre-built financial profiles and get started immediately with proven strategies.',
                  style: shadcnui.Theme.of(context).typography.textMuted,
                ),
                const SizedBox(height: 16),
                Text('• Pre-built expert templates',
                    style: shadcnui.Theme.of(context).typography.small),
                Text('• Instant plan generation',
                    style: shadcnui.Theme.of(context).typography.small),
                Text('• Easy to customize later',
                    style: shadcnui.Theme.of(context).typography.small),
                const SizedBox(height: 12),
                Text('⏱ 1-2 minutes',
                    style: shadcnui.Theme.of(context).typography.textMuted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: shadcnui.PrimaryButton(
            onPressed: setupMode.value == null
                ? null
                : () {
                    if (setupMode.value == 'customized') {
                      currentStep.value = 'questionnaire';
                    } else {
                      currentStep.value = 'preset-profile';
                    }
                  },
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetProfile(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<String> currentStep,
    ValueNotifier<String?> selectedPreset,
  ) {
    final presets = [
      {
        'id': 'young-professional',
        'name': 'Young Professional',
        'description':
            'Starting career, building savings, minimal debt, looking to invest',
      },
      {
        'id': 'mid-career',
        'name': 'Mid-Career Professional',
        'description':
            'Established income, some savings, planning for family and retirement',
      },
      {
        'id': 'family-focused',
        'name': 'Family Focused',
        'description':
            'Supporting dependents, balancing current needs with future goals',
      },
      {
        'id': 'approaching-retirement',
        'name': 'Approaching Retirement',
        'description':
            'Maximizing savings, reducing risk, preparing for retirement',
      },
      {
        'id': 'high-earner',
        'name': 'High Earner',
        'description':
            'Significant income, complex finances, tax optimization focus',
      },
      {
        'id': 'debt-reducer',
        'name': 'Debt Reducer',
        'description':
            'Prioritizing debt payoff, building emergency fund, starting investments',
      },
    ];

    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          'Choose Your Profile',
          style: shadcnui.Theme.of(context).typography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Select the profile that best matches your current situation',
          style: shadcnui.Theme.of(context).typography.textMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        ...presets.map((preset) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => selectedPreset.value = preset['id'] as String,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedPreset.value == preset['id']
                      ? shadcnui.Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : shadcnui.Theme.of(context).colorScheme.card,
                  border: Border.all(
                    color: selectedPreset.value == preset['id']
                        ? shadcnui.Theme.of(context).colorScheme.primary
                        : shadcnui.Theme.of(context).colorScheme.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset['name'] as String,
                      style: shadcnui.Theme.of(context).typography.h4,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset['description'] as String,
                      style: shadcnui.Theme.of(context).typography.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => currentStep.value = 'setup-experience',
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: shadcnui.PrimaryButton(
                onPressed: selectedPreset.value == null
                    ? null
                    : () {
                        // Create goal with preset profile
                        final data = {
                          'preset_profile': selectedPreset.value,
                          'mode': 'faster',
                        };
                        onComplete(data);
                      },
                child: const Text('Create Goal'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionnaire(BuildContext context, WidgetRef ref) {
    // Simplified questionnaire with basic fields
    // Full implementation would mirror web's QuestionnaireFlow categories
    return Column(
      children: [
        Text(
          'Financial Questionnaire',
          style: shadcnui.Theme.of(context).typography.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // This is a placeholder - full implementation would include:
        // - Category-based questions
        // - Form validation
        // - Progress tracking
        // - Dynamic question flow

        Text(
          'Detailed questionnaire implementation here',
          style: shadcnui.Theme.of(context).typography.textMuted,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: shadcnui.PrimaryButton(
            onPressed: () {
              // Collect answers and complete
              final data = {
                'mode': 'customized',
                // Add collected questionnaire data
              };
              onComplete(data);
            },
            child: const Text('Create Goal'),
          ),
        ),
      ],
    );
  }
}
