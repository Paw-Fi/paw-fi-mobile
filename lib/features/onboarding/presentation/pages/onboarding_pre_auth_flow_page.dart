import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_question_steps.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/households/presentation/widgets/household_image_picker.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class OnboardingPreAuthFlowPage extends HookConsumerWidget {
  const OnboardingPreAuthFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageController = usePageController();
    final currentPage = useState(0);
    final isLoaded = useState(false);
    final draftState = useState(OnboardingPreauthDraft.initial());
    final answeredOptionSteps = useState<Set<int>>(<int>{});
    final isAutoAdvancing = useState(false);
    const totalSteps = 13;

    useEffect(() {
      final store = ref.read(onboardingPreauthDraftStoreProvider);
      final draft = store.load();
      draftState.value = draft;
      currentPage.value = draft.currentStep.clamp(0, totalSteps - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !pageController.hasClients) return;
        pageController.jumpToPage(currentPage.value);
      });
      isLoaded.value = true;
      return null;
    }, const []);

    Future<void> persistDraft(OnboardingPreauthDraft draft) async {
      if (!context.mounted) return;
      draftState.value = draft;
      await ref.read(onboardingPreauthDraftStoreProvider).save(draft);
    }

    void markAnswered(int stepIndex) {
      if (!context.mounted) return;
      answeredOptionSteps.value = {...answeredOptionSteps.value, stepIndex};
    }

    Future<void> goToPage(int index) async {
      final nextDraft = draftState.value.copyWith(currentStep: index);
      await persistDraft(nextDraft);
      if (pageController.hasClients) {
        await pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    }

    Future<void> goBack() async {
      if (currentPage.value <= 0) return;
      var previousStep = currentPage.value - 1;
      while (previousStep > 0 && _kTransientSteps.contains(previousStep)) {
        previousStep -= 1;
      }
      await goToPage(previousStep);
    }

    Future<void> next() async {
      if (currentPage.value < totalSteps - 1) {
        if (currentPage.value == totalSteps - 3) {
          final recommendedTemplate = _recommendTemplate(draftState.value);
          await persistDraft(
            draftState.value.copyWith(
              wantsStarterPockets: true,
              recommendedTemplateId: recommendedTemplate.id,
            ),
          );
        }
        await goToPage(currentPage.value + 1);
        return;
      }
      final store = ref.read(onboardingPreauthDraftStoreProvider);
      await store.markPreauthCompleted();
      if (context.mounted) {
        context.go('/register');
      }
    }

    Future<void> answerAndAdvance({
      required int stepIndex,
      required OnboardingPreauthDraft nextDraft,
      VoidCallback? afterPersist,
    }) async {
      if (!context.mounted || isAutoAdvancing.value) return;
      HapticFeedback.lightImpact();
      markAnswered(stepIndex);
      await persistDraft(nextDraft);
      afterPersist?.call();
      if (!context.mounted) return;
      isAutoAdvancing.value = true;
      try {
        await next();
      } finally {
        if (context.mounted) {
          isAutoAdvancing.value = false;
        }
      }
    }

    Future<void> exploreAppInPreview() async {
      final prefs = ref.read(sharedPreferencesProvider);
      await persistDraft(
        draftState.value.copyWith(currentStep: totalSteps - 1),
      );
      await prefs.setBool(kPreviewModeActiveKey, true);
      await prefs.setBool(kPreviewReturnToPreauthKey, true);
      ref.read(previewModeProvider.notifier).enable();
      if (!context.mounted) return;
      context.go('/dashboard');
    }

    final isAutoAdvanceStep = _kAutoAdvanceSteps.contains(currentPage.value);
    final canShowBackButton = currentPage.value < _kPostQuestionStartStep;

    if (!isLoaded.value) {
      return AdaptiveScaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              if (canShowBackButton)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: currentPage.value > 0
                            ? () => unawaited(goBack())
                            : null,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.cardSurface,
                          ),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2.0),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: currentPage.value > 0
                                  ? colorScheme.mutedForeground
                                  : colorScheme.mutedForeground
                                      .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ((currentPage.value + 1) / totalSteps)
                                .clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: colorScheme.mutedForeground
                                .withValues(alpha: 0.25),
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    _PreAuthHelpFocusStep(
                      selectedFocus: draftState.value.onboardingFocus,
                      hasAnswered: answeredOptionSteps.value.contains(0),
                      onChanged: (focus) {
                        final nextDraft = switch (focus) {
                          'keep_shared_expenses' => draftState.value.copyWith(
                              onboardingFocus: focus,
                              primaryGoal: 'balanced',
                              wantsSharedSpace: true,
                            ),
                          'split_bills' => draftState.value.copyWith(
                              onboardingFocus: focus,
                              primaryGoal: 'balanced',
                              wantsSharedSpace: true,
                            ),
                          'trip_event' => draftState.value.copyWith(
                              onboardingFocus: focus,
                              primaryGoal: 'travel',
                            ),
                          'track_receipts' => draftState.value.copyWith(
                              onboardingFocus: focus,
                              primaryGoal: 'save',
                            ),
                          _ => draftState.value.copyWith(
                              onboardingFocus: focus,
                              primaryGoal: 'balanced',
                            ),
                        };
                        unawaited(
                          answerAndAdvance(stepIndex: 0, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthLivingSituationStep(
                      selectedLiving: draftState.value.livingSituation,
                      hasAnswered: answeredOptionSteps.value.contains(1),
                      onChanged: (living) {
                        final nextDraft = switch (living) {
                          'roommates' => draftState.value.copyWith(
                              livingSituation: living,
                              householdProfile: 'mates',
                              wantsSharedSpace: true,
                            ),
                          'family' => draftState.value.copyWith(
                              livingSituation: living,
                              householdProfile: 'family',
                              wantsSharedSpace: true,
                            ),
                          _ => draftState.value.copyWith(
                              livingSituation: living,
                            ),
                        };
                        unawaited(
                          answerAndAdvance(stepIndex: 1, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthEatingOutStep(
                      selectedFrequency: draftState.value.eatingOutFrequency,
                      hasAnswered: answeredOptionSteps.value.contains(2),
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          eatingOutFrequency: value,
                          lifestyleFocus: value == 'often'
                              ? 'foodies'
                              : draftState.value.lifestyleFocus,
                        );
                        unawaited(
                          answerAndAdvance(stepIndex: 2, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthSubscriptionsStep(
                      selectedLevel: draftState.value.subscriptionsLevel,
                      hasAnswered: answeredOptionSteps.value.contains(3),
                      onChanged: (value) {
                        final nextDraft = draftState.value
                            .copyWith(subscriptionsLevel: value);
                        unawaited(
                          answerAndAdvance(stepIndex: 3, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthPetsStep(
                      hasPets: draftState.value.hasPets,
                      hasAnswered: answeredOptionSteps.value.contains(4),
                      onChanged: (hasPets) {
                        final nextDraft = draftState.value.copyWith(
                          hasPets: hasPets,
                        );
                        unawaited(
                          answerAndAdvance(stepIndex: 4, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthCurrencyStep(
                      selectedCurrency: draftState.value.selectedCurrency,
                      onSelected: (currency) {
                        final nextDraft = draftState.value.copyWith(
                          selectedCurrency: currency.toUpperCase(),
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: 5,
                            nextDraft: nextDraft,
                            afterPersist: () {
                              ref
                                  .read(homeFilterProvider.notifier)
                                  .setSelectedCurrency(currency.toUpperCase());
                            },
                          ),
                        );
                      },
                    ),
                    _PreAuthBudgetStep(
                      monthlyBudget: draftState.value.monthlyBudget,
                      onBudgetChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          monthlyBudget: value,
                        );
                        unawaited(persistDraft(nextDraft));
                      },
                    ),
                    _PreAuthHouseholdStep(
                      householdProfile: draftState.value.householdProfile,
                      spaceName: draftState.value.spaceName,
                      spaceImageUrl: draftState.value.spaceImageUrl,
                      spaceImagePath: draftState.value.spaceImagePath,
                      inviteEmail: draftState.value.inviteEmail,
                      inviteMessage: draftState.value.inviteMessage,
                      inviteExpiresInDays: draftState.value.inviteExpiresInDays,
                      onHouseholdProfileChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          householdProfile: value,
                          wantsSharedSpace: value != 'personal',
                        );
                        unawaited(persistDraft(nextDraft));
                      },
                      onSpaceNameChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          spaceName: value,
                        );
                        unawaited(persistDraft(nextDraft));
                      },
                      onImageSelected: (imageUrl, imagePath) {
                        final nextDraft = draftState.value.copyWith(
                          spaceImageUrl: imageUrl,
                          spaceImagePath: imagePath,
                        );
                        unawaited(persistDraft(nextDraft));
                      },
                      onInviteEmailChanged: (value) {
                        final nextDraft =
                            draftState.value.copyWith(inviteEmail: value);
                        unawaited(persistDraft(nextDraft));
                      },
                      onInviteMessageChanged: (value) {
                        final nextDraft =
                            draftState.value.copyWith(inviteMessage: value);
                        unawaited(persistDraft(nextDraft));
                      },
                      onInviteExpiresChanged: (value) {
                        final nextDraft = draftState.value
                            .copyWith(inviteExpiresInDays: value);
                        unawaited(persistDraft(nextDraft));
                      },
                    ),
                    _PreAuthGoalStep(
                      selectedGoal: draftState.value.primaryGoal,
                      onGoalChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          primaryGoal: value,
                        );
                        unawaited(
                          answerAndAdvance(stepIndex: 8, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthLifestyleStep(
                      selectedLifestyle: draftState.value.lifestyleFocus,
                      onLifestyleChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          lifestyleFocus: value,
                        );
                        unawaited(
                          answerAndAdvance(stepIndex: 9, nextDraft: nextDraft),
                        );
                      },
                    ),
                    _PreAuthCalculatingStep(
                      isActive: currentPage.value == 10,
                      onCompleted: () => unawaited(next()),
                    ),
                    _PreAuthStarterStep(
                      templateId: draftState.value.recommendedTemplateId,
                      selectedCurrency: draftState.value.selectedCurrency,
                      monthlyBudget: draftState.value.monthlyBudget,
                    ),
                    const _PreAuthCreateAccountStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isAutoAdvanceStep)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: PrimaryAdaptiveButton(
                          onPressed: _canContinuePreAuth(
                            currentPage: currentPage.value,
                            draft: draftState.value,
                          )
                              ? () => unawaited(next())
                              : null,
                          child: Text(
                            currentPage.value == totalSteps - 1
                                ? context.l10n.createAccount
                                : context.l10n.continueAction,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (currentPage.value == totalSteps - 1)
                      Center(
                        child: GestureDetector(
                          onTap: () => unawaited(exploreAppInPreview()),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Explore the app',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kAutoAdvanceSteps = <int>{0, 1, 2, 3, 4, 5, 8, 9, 10};
const _kTransientSteps = <int>{10};
const _kPostQuestionStartStep = 10;

bool _canContinuePreAuth({
  required int currentPage,
  required OnboardingPreauthDraft draft,
}) {
  if (currentPage == 6) {
    return draft.monthlyBudget > 0;
  }
  return true;
}

OnboardingQuestionStep _sharedQuestionStep(int index) =>
    onboardingSharedQuestionSteps[index];

List<(String label, String value)> _sharedQuestionOptions(int index) =>
    _sharedQuestionStep(index)
        .options
        .map((option) => (option.label, option.value))
        .toList(growable: false);

class _PreAuthHelpFocusStep extends StatelessWidget {
  const _PreAuthHelpFocusStep({
    required this.selectedFocus,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedFocus;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = _sharedQuestionStep(0);
    return _PreAuthQuestionOptionsStep(
      title: step.title,
      options: _sharedQuestionOptions(0),
      selectedValue: hasAnswered ? selectedFocus : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthLivingSituationStep extends StatelessWidget {
  const _PreAuthLivingSituationStep({
    required this.selectedLiving,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedLiving;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = _sharedQuestionStep(1);
    return _PreAuthQuestionOptionsStep(
      title: step.title,
      options: _sharedQuestionOptions(1),
      selectedValue: hasAnswered ? selectedLiving : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthEatingOutStep extends StatelessWidget {
  const _PreAuthEatingOutStep({
    required this.selectedFrequency,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedFrequency;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = _sharedQuestionStep(2);
    return _PreAuthQuestionOptionsStep(
      title: step.title,
      options: _sharedQuestionOptions(2),
      selectedValue: hasAnswered ? selectedFrequency : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthSubscriptionsStep extends StatelessWidget {
  const _PreAuthSubscriptionsStep({
    required this.selectedLevel,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedLevel;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = _sharedQuestionStep(3);
    return _PreAuthQuestionOptionsStep(
      title: step.title,
      options: _sharedQuestionOptions(3),
      selectedValue: hasAnswered ? selectedLevel : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthPetsStep extends StatelessWidget {
  const _PreAuthPetsStep({
    required this.hasPets,
    required this.hasAnswered,
    required this.onChanged,
  });

  final bool hasPets;
  final bool hasAnswered;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = _sharedQuestionStep(4);
    return _PreAuthQuestionOptionsStep(
      title: step.title,
      options: _sharedQuestionOptions(4),
      selectedValue: hasAnswered ? (hasPets ? 'yes' : 'no') : '',
      onChanged: (value) => onChanged(value == 'yes'),
    );
  }
}

class _PreAuthQuestionOptionsStep extends StatelessWidget {
  const _PreAuthQuestionOptionsStep({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final List<(String label, String value)> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 20),
            ...options.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PreAuthOptionTile(
                  label: item.$1,
                  selected: selectedValue == item.$2,
                  onTap: () => onChanged(item.$2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreAuthOptionTile extends StatelessWidget {
  const _PreAuthOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.border.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: colorScheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreAuthCurrencyStep extends ConsumerWidget {
  const _PreAuthCurrencyStep({
    required this.selectedCurrency,
    required this.onSelected,
  });

  final String selectedCurrency;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upper = selectedCurrency.toUpperCase();

    return _PreAuthQuestionOptionsStep(
      title: context.l10n.selectCurrencyForDailySpending,
      options: [
        ('Current: $upper  -  Tap to choose currency', upper),
      ],
      selectedValue: upper,
      onChanged: (_) async {
        final result = await showCurrencySelectorModal(
          context,
          ref,
          showAllByDefault: true,
        );
        if (!context.mounted) return;
        if (result != null && result.isNotEmpty) {
          onSelected(result.toUpperCase());
        }
      },
    );
  }
}

class _PreAuthBudgetStep extends HookWidget {
  const _PreAuthBudgetStep({
    required this.monthlyBudget,
    required this.onBudgetChanged,
  });

  final double monthlyBudget;
  final ValueChanged<double> onBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(
      text: monthlyBudget > 0 ? monthlyBudget.toStringAsFixed(0) : '',
    );

    useEffect(() {
      void listener() {
        final parsed = double.tryParse(controller.text.trim());
        if (parsed != null && parsed > 0) {
          onBudgetChanged(parsed);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding2.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.createSpendingLimitForCategory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'What monthly budget target should we prepare for you?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Monthly budget',
              hintText: '1200',
              filled: true,
              fillColor: colorScheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreAuthHouseholdStep extends HookConsumerWidget {
  const _PreAuthHouseholdStep({
    required this.householdProfile,
    required this.spaceName,
    required this.spaceImageUrl,
    required this.spaceImagePath,
    required this.inviteEmail,
    required this.inviteMessage,
    required this.inviteExpiresInDays,
    required this.onHouseholdProfileChanged,
    required this.onSpaceNameChanged,
    required this.onImageSelected,
    required this.onInviteEmailChanged,
    required this.onInviteMessageChanged,
    required this.onInviteExpiresChanged,
  });

  final String householdProfile;
  final String spaceName;
  final String spaceImageUrl;
  final String spaceImagePath;
  final String inviteEmail;
  final String inviteMessage;
  final int inviteExpiresInDays;
  final ValueChanged<String> onHouseholdProfileChanged;
  final ValueChanged<String> onSpaceNameChanged;
  final void Function(String imageUrl, String imagePath) onImageSelected;
  final ValueChanged<String> onInviteEmailChanged;
  final ValueChanged<String> onInviteMessageChanged;
  final ValueChanged<int> onInviteExpiresChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(text: spaceName);
    final inviteEmailController = useTextEditingController(text: inviteEmail);
    final inviteMessageController =
        useTextEditingController(text: inviteMessage);
    final pickedImageFile =
        spaceImagePath.isNotEmpty ? File(spaceImagePath) : null;

    useEffect(() {
      void listener() => onSpaceNameChanged(controller.text);
      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    useEffect(() {
      void emailListener() => onInviteEmailChanged(inviteEmailController.text);
      inviteEmailController.addListener(emailListener);
      return () => inviteEmailController.removeListener(emailListener);
    }, [inviteEmailController]);

    useEffect(() {
      void msgListener() =>
          onInviteMessageChanged(inviteMessageController.text);
      inviteMessageController.addListener(msgListener);
      return () => inviteMessageController.removeListener(msgListener);
    }, [inviteMessageController]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SvgPicture.asset(
                'lib/assets/images/onboarding/onboarding4.svg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.inviteOthersToShareBudget,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Who are you budgeting with most of the time?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _AdvisorChoiceChip(
                  label: 'Just me',
                  selected: householdProfile == 'personal',
                  onTap: () => onHouseholdProfileChanged('personal'),
                ),
                _AdvisorChoiceChip(
                  label: 'Couple',
                  selected: householdProfile == 'couple',
                  onTap: () => onHouseholdProfileChanged('couple'),
                ),
                _AdvisorChoiceChip(
                  label: 'Family',
                  selected: householdProfile == 'family',
                  onTap: () => onHouseholdProfileChanged('family'),
                ),
                _AdvisorChoiceChip(
                  label: 'Housemates',
                  selected: householdProfile == 'mates',
                  onTap: () => onHouseholdProfileChanged('mates'),
                ),
              ],
            ),
            if (householdProfile != 'personal') ...[
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Space name (optional)',
                  hintText: context.l10n.householdNameHint,
                  filled: true,
                  fillColor: colorScheme.appleInputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  await HouseholdImagePicker.showImageSourceModal(
                    context: context,
                    ref: ref,
                    currentImageUrl:
                        spaceImageUrl.isNotEmpty ? spaceImageUrl : null,
                    onImageSelected: (imageUrl, imageFile) {
                      onImageSelected(
                        imageUrl ?? '',
                        imageFile?.path ?? '',
                      );
                    },
                  );
                },
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.appleInputBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 86,
                          height: 86,
                          child: pickedImageFile != null
                              ? Image.file(pickedImageFile, fit: BoxFit.cover)
                              : (spaceImageUrl.isNotEmpty
                                  ? Image.network(spaceImageUrl,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: colorScheme.muted
                                          .withValues(alpha: 0.2),
                                      child: Icon(
                                        Icons.image_rounded,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choose a space cover image',
                          style: TextStyle(
                            color: colorScheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: inviteEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Who to invite (email)',
                  hintText: 'friend@example.com',
                  filled: true,
                  fillColor: colorScheme.appleInputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: inviteMessageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Invite message',
                  hintText: 'Hey! Join my shared budget space on Moneko.',
                  filled: true,
                  fillColor: colorScheme.appleInputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: inviteExpiresInDays,
                decoration: InputDecoration(
                  labelText: 'Invite expires in',
                  filled: true,
                  fillColor: colorScheme.appleInputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: colorScheme.border.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 0, child: Text('Unlimited')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onInviteExpiresChanged(value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreAuthGoalStep extends StatelessWidget {
  const _PreAuthGoalStep({
    required this.selectedGoal,
    required this.onGoalChanged,
  });

  final String selectedGoal;
  final ValueChanged<String> onGoalChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding2.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What is your top money goal right now?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We will tailor your pockets to match this priority.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _AdvisorChoiceChip(
                label: 'Balanced',
                selected: selectedGoal == 'balanced',
                onTap: () => onGoalChanged('balanced'),
              ),
              _AdvisorChoiceChip(
                label: 'Save more',
                selected: selectedGoal == 'save',
                onTap: () => onGoalChanged('save'),
              ),
              _AdvisorChoiceChip(
                label: 'Pay debt',
                selected: selectedGoal == 'debt',
                onTap: () => onGoalChanged('debt'),
              ),
              _AdvisorChoiceChip(
                label: 'Travel / experiences',
                selected: selectedGoal == 'travel',
                onTap: () => onGoalChanged('travel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreAuthLifestyleStep extends StatelessWidget {
  const _PreAuthLifestyleStep({
    required this.selectedLifestyle,
    required this.onLifestyleChanged,
  });

  final String selectedLifestyle;
  final ValueChanged<String> onLifestyleChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding3.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Which spending style sounds most like you?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose one so your starter template feels right from day one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _AdvisorChoiceChip(
                label: 'Student / lean',
                selected: selectedLifestyle == 'student',
                onTap: () => onLifestyleChanged('student'),
              ),
              _AdvisorChoiceChip(
                label: 'Freelancer',
                selected: selectedLifestyle == 'freelancer',
                onTap: () => onLifestyleChanged('freelancer'),
              ),
              _AdvisorChoiceChip(
                label: 'Commuter',
                selected: selectedLifestyle == 'commuter',
                onTap: () => onLifestyleChanged('commuter'),
              ),
              _AdvisorChoiceChip(
                label: 'Food & fun',
                selected: selectedLifestyle == 'foodies',
                onTap: () => onLifestyleChanged('foodies'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvisorChoiceChip extends StatelessWidget {
  const _AdvisorChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? colorScheme.primary : colorScheme.foreground,
          ),
        ),
      ),
    );
  }
}

class _PreAuthCalculatingStep extends HookWidget {
  const _PreAuthCalculatingStep({
    required this.isActive,
    required this.onCompleted,
  });

  final bool isActive;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressController = useAnimationController(
      duration: const Duration(milliseconds: 4500),
    );
    final progress = useAnimation(progressController);
    final hasCompleted = useRef(false);

    useEffect(() {
      if (!isActive) {
        progressController.stop();
        progressController.value = 0;
        hasCompleted.value = false;
        return null;
      }

      Future<void> run() async {
        hasCompleted.value = false;
        await progressController.forward(from: 0.0);
        if (!context.mounted || hasCompleted.value) return;
        hasCompleted.value = true;
        onCompleted();
      }

      unawaited(run());

      return () {
        hasCompleted.value = true;
        progressController.stop();
      };
    }, [isActive]);

    final stageLabel = switch (progress) {
      < 0.22 => 'Analyzing your answers',
      < 0.48 => 'Mapping your fixed costs',
      < 0.74 => 'Designing your pockets',
      < 0.95 => 'Fine-tuning your plan',
      _ => 'Finalizing your budget setup',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 42,
              color: colorScheme.primary,
            ),
          ),
          Text(
            'Crafting your personalized budget...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            stageLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  colorScheme.mutedForeground.withValues(alpha: 0.25),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).clamp(0, 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PreAuthStarterStep extends StatelessWidget {
  const _PreAuthStarterStep({
    required this.templateId,
    required this.selectedCurrency,
    required this.monthlyBudget,
  });

  final String templateId;
  final String selectedCurrency;
  final double monthlyBudget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currency = selectedCurrency.toUpperCase();

    final template = BudgetTemplates.all.firstWhere(
      (item) => item.id == templateId,
      orElse: () => BudgetTemplates.all.first,
    );

    final annualized = (monthlyBudget > 0 ? monthlyBudget : 1200);
    final mockPockets = template.pockets.map((item) {
      final budget = (annualized * item.weight).clamp(50, annualized);
      final spent = budget * 0.62;
      return PocketEnvelope(
        id: 'starter-${template.id}-${item.name}',
        name: item.name,
        budgetAmountCents: (budget * 100).round(),
        spent: spent,
        currency: currency,
        icon: item.iconName,
        color: _colorToHex(item.color),
        budgetId: null,
        householdId: null,
        lastUpdated: now,
      );
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.pocketsIntroTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Based on your answers, this plan fits you best and will be created automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _templateTitle(template),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(mockPockets.length, (index) {
                return IgnorePointer(
                  child: PocketCard(
                    pocket: mockPockets[index],
                    colorScheme: colorScheme,
                    totalBudget: 1200,
                    envelopeMode: true,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String _templateTitle(BudgetTemplate template) {
  return template.id
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _PreAuthCreateAccountStep extends StatelessWidget {
  const _PreAuthCreateAccountStep();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding4.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.infoSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.infoBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: colorScheme.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After signup, we will prepare your account, sync your choices, then continue onboarding.',
                    style: TextStyle(
                      color: colorScheme.foreground,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BudgetTemplate _recommendTemplate(OnboardingPreauthDraft draft) {
  final profilePrefix = switch (draft.householdProfile) {
    'couple' => 'couple_',
    'family' => 'family_',
    'mates' => 'mates_',
    _ => 'personal_',
  };

  final candidates = BudgetTemplates.all
      .where((template) => template.id.startsWith(profilePrefix))
      .toList(growable: false);

  if (candidates.isEmpty) {
    return BudgetTemplates.all.first;
  }

  BudgetTemplate? byGoal() {
    if (draft.primaryGoal == 'debt') {
      return candidates.firstWhere(
        (t) => t.id.contains('debt') || t.id.contains('single_income'),
        orElse: () => candidates.first,
      );
    }
    if (draft.primaryGoal == 'save') {
      return candidates.firstWhere(
        (t) => t.id.contains('fire') || t.id.contains('freelancer'),
        orElse: () => candidates.first,
      );
    }
    if (draft.primaryGoal == 'travel') {
      return candidates.firstWhere(
        (t) => t.id.contains('travel') || t.id.contains('nomads'),
        orElse: () => candidates.first,
      );
    }
    return null;
  }

  BudgetTemplate? byLifestyle() {
    switch (draft.lifestyleFocus) {
      case 'student':
        return _firstMatching(candidates, (t) => t.id.contains('student'));
      case 'freelancer':
        return _firstMatching(
          candidates,
          (t) => t.id.contains('freelancer') || t.id.contains('nomads'),
        );
      case 'commuter':
        return _firstMatching(
          candidates,
          (t) => t.id.contains('commuter') || t.id.contains('active'),
        );
      case 'foodies':
        return _firstMatching(
          candidates,
          (t) => t.id.contains('foodies') || t.id.contains('party'),
        );
      default:
        return null;
    }
  }

  return byLifestyle() ?? byGoal() ?? candidates.first;
}

String? _colorToHex(Color? color) {
  if (color == null) return null;
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

BudgetTemplate? _firstMatching(
  List<BudgetTemplate> templates,
  bool Function(BudgetTemplate item) test,
) {
  for (final item in templates) {
    if (test(item)) return item;
  }
  return null;
}
