// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_amounts.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_profile.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_question_steps.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/subscription/data/models/app_store_reviews.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/app_store_review_card.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const _kStepHousingSituation = 0;
const _kStepBillSplit = 1;
const _kStepSubscriptions = 2;
const _kStepEatingOut = 3;
const _kStepTestimonial = 4;
const _kStepLifestyle = 5;
const _kStepGoal = 6;
const _kStepSavingsTarget = 7;
const _kStepCurrency = 8;
const _kStepCalculating = 9;
const _kStepStarter = 10;
const _kQuestionStepCount = 8;
const _kTotalPreAuthSteps = 11;

int _migratePreauthStepIndex(int legacyStep, int flowVersion) {
  if (flowVersion == 5) {
    if (legacyStep >= 4 && legacyStep <= 9) {
      return legacyStep + 1;
    }
    return legacyStep.clamp(0, _kTotalPreAuthSteps - 1);
  }

  switch (legacyStep) {
    case 0:
    case 1:
    case 8:
      return _kStepHousingSituation;
    case 5:
      return _kStepCurrency;
    case 7:
      return _kStepBillSplit;
    case 3:
      return _kStepSubscriptions;
    case 2:
      return _kStepEatingOut;
    case 4:
    case 14:
      return _kStepLifestyle;
    case 6:
    case 9:
    case 10:
      return _kStepSavingsTarget;
    case 11:
    case 12:
    case 13:
      return _kStepGoal;
    case 15:
      return _kStepCalculating;
    case 16:
    case 17:
      return _kStepStarter;
    default:
      return _kStepCurrency;
  }
}

Set<int> _answeredStepsForCurrentPage(int step) {
  final answeredCount = step.clamp(0, _kQuestionStepCount);
  return {
    for (var index = 0; index < answeredCount; index += 1) index,
  };
}

int _normalizePreauthStepIndex(int step, int maxStep) {
  var normalized = step.clamp(0, maxStep);
  while (normalized < maxStep && _kTransientSteps.contains(normalized)) {
    normalized += 1;
  }
  return normalized;
}

String _preauthPageId(int step) {
  switch (step) {
    case _kStepHousingSituation:
      return 'preauth_housing_situation';
    case _kStepBillSplit:
      return 'preauth_bill_split';
    case _kStepSubscriptions:
      return 'preauth_subscriptions';
    case _kStepEatingOut:
      return 'preauth_eating_out';
    case _kStepTestimonial:
      return 'preauth_testimonial';
    case _kStepLifestyle:
      return 'preauth_lifestyle';
    case _kStepGoal:
      return 'preauth_goal';
    case _kStepSavingsTarget:
      return 'preauth_savings_target';
    case _kStepCurrency:
      return 'preauth_currency';
    case _kStepCalculating:
      return 'preauth_calculating';
    case _kStepStarter:
      return 'preauth_starter_budget';
    default:
      return 'preauth_unknown';
  }
}

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
    final budgetSliderDebounce = useRef<Timer?>(null);
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);
    const totalSteps = _kTotalPreAuthSteps;

    useEffect(() {
      if (!isLoaded.value) return null;
      unawaited(
        analytics.beginPage(
          flowName: 'onboarding_funnel',
          pageId: _preauthPageId(currentPage.value),
          stepIndex: currentPage.value,
          properties: const <String, Object?>{'entry_path': 'preauth'},
        ),
      );
      return null;
    }, [isLoaded.value, currentPage.value]);

    useEffect(() {
      final store = ref.read(onboardingPreauthDraftStoreProvider);
      var draft = store.load();
      if (draft.flowVersion < kOnboardingPreauthFlowVersion) {
        final migratedStep =
            _migratePreauthStepIndex(draft.currentStep, draft.flowVersion);
        final shouldResetCurrency = draft.flowVersion < 5 &&
            draft.currentStep <= _kStepCurrency &&
            draft.selectedCurrency.trim().toUpperCase() == 'USD';
        draft = draft.copyWith(
          flowVersion: kOnboardingPreauthFlowVersion,
          currentStep: migratedStep,
          selectedCurrency: shouldResetCurrency ? '' : draft.selectedCurrency,
        );
        unawaited(store.save(draft));
      }
      draftState.value = draft;
      final normalizedStep =
          _normalizePreauthStepIndex(draft.currentStep, totalSteps - 1);
      currentPage.value = normalizedStep;
      answeredOptionSteps.value = _answeredStepsForCurrentPage(normalizedStep);
      if (normalizedStep != draft.currentStep) {
        unawaited(
          store.save(
            draft.copyWith(currentStep: normalizedStep),
          ),
        );
      }
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

    void persistBudgetDraftDebounced(OnboardingPreauthDraft draft) {
      draftState.value = draft;
      budgetSliderDebounce.value?.cancel();
      budgetSliderDebounce.value = Timer(const Duration(milliseconds: 180), () {
        unawaited(persistDraft(draft));
      });
    }

    Future<void> flushPendingBudgetDraft() async {
      budgetSliderDebounce.value?.cancel();
      await persistDraft(draftState.value);
    }

    useEffect(() {
      return () {
        budgetSliderDebounce.value?.cancel();
      };
    }, const []);

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
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _preauthPageId(currentPage.value),
        stepIndex: currentPage.value,
        actionId: 'preauth_back',
        result: 'used',
        properties: <String, Object?>{
          'step_group': 'preauth',
          'step_key': _preauthPageId(currentPage.value),
        },
      );
      var previousStep = currentPage.value - 1;
      while (previousStep > 0 && _kTransientSteps.contains(previousStep)) {
        previousStep -= 1;
      }
      await goToPage(previousStep);
    }

    Future<void> next() async {
      if (currentPage.value < totalSteps - 1) {
        if (currentPage.value == _kStepStarter) {
          await flushPendingBudgetDraft();
          if (!context.mounted) return;
        }
        if (currentPage.value == _kStepCurrency) {
          final preparedDraft = derivePreauthBudgetProfile(draftState.value);
          final recommendedTemplate =
              BudgetRecommender.recommend(context, preparedDraft);
          await persistDraft(
            preparedDraft.copyWith(
              wantsStarterPockets: true,
              recommendedTemplateId: recommendedTemplate.recommendedTemplateId,
            ),
          );
        }
        final nextStep =
            _normalizePreauthStepIndex(currentPage.value + 1, totalSteps - 1);
        await goToPage(nextStep);
        return;
      }
      final store = ref.read(onboardingPreauthDraftStoreProvider);
      await store.markPreauthCompleted();
      if (context.mounted) {
        context.go('/onboarding?stage=save_budget');
      }
    }

    Future<void> answerAndAdvance({
      required int stepIndex,
      required OnboardingPreauthDraft nextDraft,
      String? selectedValue,
      VoidCallback? afterPersist,
    }) async {
      if (!context.mounted || isAutoAdvancing.value) return;
      HapticFeedback.lightImpact();
      markAnswered(stepIndex);
      await persistDraft(nextDraft);
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _preauthPageId(stepIndex),
        stepIndex: stepIndex,
        actionId: 'preauth_answered',
        result: 'used',
        properties: <String, Object?>{
          'step_group': 'preauth',
          'step_key': _preauthPageId(stepIndex),
          if (selectedValue != null) 'selected_value': selectedValue,
        },
      );
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

    final isAutoAdvanceStep = _kAutoAdvanceSteps.contains(currentPage.value);
    final hasBlockingRecommendation = currentPage.value == _kStepStarter
        ? BudgetRecommender.recommend(
            context,
            derivePreauthBudgetProfile(draftState.value),
          ).hasBlockingError
        : false;
    final isStarterStep = currentPage.value == _kStepStarter;
    const progressStepCount = _kQuestionStepCount;
    final canShowBackButton = !isStarterStep &&
        (currentPage.value < _kPostQuestionStartStep ||
            hasBlockingRecommendation);

    if (!isLoaded.value) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      ));
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
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
                            value:
                                ((_preauthProgressStep(currentPage.value) + 1) /
                                        progressStepCount)
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
                    _PreAuthLivingSituationStep(
                      selectedLiving: draftState.value.housingType,
                      hasAnswered: answeredOptionSteps.value
                          .contains(_kStepHousingSituation),
                      onChanged: (living) {
                        final nextDraft = switch (living) {
                          'mortgage' => draftState.value.copyWith(
                              livingSituation: 'owning',
                              housingType: 'mortgage',
                            ),
                          'family_home' => draftState.value.copyWith(
                              livingSituation: 'family',
                              housingType: 'family_home',
                              householdProfile: 'family',
                            ),
                          'paid_off' => draftState.value.copyWith(
                              livingSituation: 'owning',
                              housingType: 'paid_off',
                            ),
                          _ => draftState.value.copyWith(
                              livingSituation: 'renting',
                              housingType: 'rent',
                            ),
                        };
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepHousingSituation,
                            nextDraft: nextDraft,
                            selectedValue: living,
                          ),
                        );
                      },
                    ),
                    _PreAuthBillSplitStep(
                      selectedFrequency: draftState.value.billSplitFrequency,
                      hasAnswered:
                          answeredOptionSteps.value.contains(_kStepBillSplit),
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          billSplitFrequency: value,
                          wantsSharedSpace: value != 'none',
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepBillSplit,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthSubscriptionsStep(
                      selectedLevel: draftState.value.subscriptionsLevel,
                      hasAnswered: answeredOptionSteps.value
                          .contains(_kStepSubscriptions),
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          subscriptionsLevel: value,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepSubscriptions,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthEatingOutStep(
                      selectedFrequency: draftState.value.eatingOutFrequency,
                      hasAnswered:
                          answeredOptionSteps.value.contains(_kStepEatingOut),
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          eatingOutFrequency: value,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepEatingOut,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    const _PreAuthTestimonialStep(),
                    _PreAuthLifestyleStep(
                      selectedLifestyle: draftState.value.lifestyleFocus,
                      hasAnswered:
                          answeredOptionSteps.value.contains(_kStepLifestyle),
                      onLifestyleChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          lifestyleFocus: value,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepLifestyle,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthGoalStep(
                      selectedGoal: draftState.value.primaryGoal,
                      hasAnswered:
                          answeredOptionSteps.value.contains(_kStepGoal),
                      onGoalChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          primaryGoal: value,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepGoal,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthSavingsTargetStep(
                      selectedMode: draftState.value.savingsMode,
                      hasAnswered: answeredOptionSteps.value
                          .contains(_kStepSavingsTarget),
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          savingsMode: value,
                          savingsAmount: 0,
                          savingsPercent: 0,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepSavingsTarget,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthCurrencyStep(
                      selectedCurrency: draftState.value.selectedCurrency,
                      onChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          selectedCurrency: value,
                        );
                        unawaited(
                          answerAndAdvance(
                            stepIndex: _kStepCurrency,
                            nextDraft: nextDraft,
                            selectedValue: value,
                          ),
                        );
                      },
                    ),
                    _PreAuthCalculatingStep(
                      isActive: currentPage.value == _kStepCalculating,
                      onCompleted: () => unawaited(next()),
                    ),
                    _PreAuthStarterStep(
                      draft: derivePreauthBudgetProfile(draftState.value),
                      onBudgetChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          monthlyBudget: value,
                        );
                        persistBudgetDraftDebounced(nextDraft);
                      },
                    ),
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
                            context.l10n.next,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

const _kAutoAdvanceSteps = <int>{
  _kStepHousingSituation,
  _kStepBillSplit,
  _kStepSubscriptions,
  _kStepEatingOut,
  _kStepLifestyle,
  _kStepGoal,
  _kStepSavingsTarget,
  _kStepCurrency,
  _kStepCalculating,
};
const _kTransientSteps = <int>{};
const _kPostQuestionStartStep = _kStepCalculating;

bool _canContinuePreAuth({
  required int currentPage,
  required OnboardingPreauthDraft draft,
}) {
  if (currentPage == _kStepCurrency) {
    return draft.selectedCurrency.trim().isNotEmpty;
  }
  return true;
}

int _preauthProgressStep(int step) {
  if (step <= _kStepEatingOut) {
    return step;
  }
  if (step == _kStepTestimonial) {
    return _kStepEatingOut;
  }
  if (step <= _kStepCurrency) {
    return step - 1;
  }
  return _kQuestionStepCount - 1;
}

OnboardingQuestionStep _sharedQuestionStep(int index) =>
    onboardingSharedQuestionSteps[index];

List<(String label, String value)> _sharedQuestionOptions(
        BuildContext context, int index) =>
    _sharedQuestionStep(index)
        .options
        .map((option) => (option.getLabel(context), option.value))
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
      title: step.getTitle(context),
      options: _sharedQuestionOptions(context, 0),
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
    final step = _sharedQuestionStep(0);
    return _PreAuthQuestionOptionsStep(
      title: step.getTitle(context),
      options: _sharedQuestionOptions(context, 0),
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
    final step = _sharedQuestionStep(3);
    return _PreAuthQuestionOptionsStep(
      title: step.getTitle(context),
      options: _sharedQuestionOptions(context, 3),
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
    final step = _sharedQuestionStep(2);
    return _PreAuthQuestionOptionsStep(
      title: step.getTitle(context),
      options: _sharedQuestionOptions(context, 2),
      selectedValue: hasAnswered ? selectedLevel : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthTestimonialStep extends StatelessWidget {
  const _PreAuthTestimonialStep();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final qualityReview = appStoreReviews.firstWhere(
      (review) => review.id == 'review-020',
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onboardingPreauthTestimonialTitle,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.onboardingPreauthTestimonialSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/testimonial.svg',
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          AppStoreReviewCard(
            review: qualityReview,
          ),
        ],
      ),
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
      title: step.getTitle(context),
      options: _sharedQuestionOptions(context, 4),
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
          Text(
            context.l10n.onboardingPreAuthBudgetTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.onboardingPreAuthBudgetSubtitle,
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
              labelText: context.l10n.monthlyBudget,
              hintText: context.l10n.monthlyBudgetHint,
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

class _PreAuthBillSplitStep extends StatelessWidget {
  const _PreAuthBillSplitStep({
    required this.selectedFrequency,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedFrequency;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PreAuthQuestionOptionsStep(
      title: _sharedQuestionStep(1).getTitle(context),
      options: _sharedQuestionOptions(context, 1),
      selectedValue: hasAnswered ? selectedFrequency : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthHousingStep extends HookWidget {
  const _PreAuthHousingStep({
    required this.housingType,
    required this.housingPayment,
    required this.onHousingTypeChanged,
    required this.onHousingPaymentChanged,
  });

  final String housingType;
  final double housingPayment;
  final ValueChanged<String> onHousingTypeChanged;
  final ValueChanged<double> onHousingPaymentChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(
      text: housingPayment > 0 ? housingPayment.toStringAsFixed(0) : '',
    );

    useEffect(() {
      void listener() {
        final parsed = double.tryParse(controller.text.trim());
        if (parsed != null && parsed >= 0) {
          onHousingPaymentChanged(parsed);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.onboardingPreAuthHousingTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.onboardingPreAuthHousingSubtitle,
              style: TextStyle(color: colorScheme.mutedForeground),
            ),
            const SizedBox(height: 20),
            _PreAuthOptionTile(
              label: context.l10n.rent,
              selected: housingType == 'rent',
              onTap: () => onHousingTypeChanged('rent'),
            ),
            const SizedBox(height: 10),
            _PreAuthOptionTile(
              label: context.l10n.mortgage,
              selected: housingType == 'mortgage',
              onTap: () => onHousingTypeChanged('mortgage'),
            ),
            const SizedBox(height: 10),
            _PreAuthOptionTile(
              label: context.l10n.onboardingPreAuthNotSureEstimate,
              selected: housingType == 'not_sure',
              onTap: () => onHousingTypeChanged('not_sure'),
            ),
            const SizedBox(height: 16),
            if (housingType != 'not_sure')
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.monthlyHousingAmount,
                  hintText: context.l10n.monthlyHousingAmountHint,
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
      ),
    );
  }
}

class _PreAuthUtilitiesStep extends HookWidget {
  const _PreAuthUtilitiesStep({
    required this.utilitiesKnown,
    required this.utilitiesAmount,
    required this.onUtilitiesKnownChanged,
    required this.onUtilitiesAmountChanged,
  });

  final bool utilitiesKnown;
  final double utilitiesAmount;
  final ValueChanged<bool> onUtilitiesKnownChanged;
  final ValueChanged<double> onUtilitiesAmountChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(
      text: utilitiesAmount > 0 ? utilitiesAmount.toStringAsFixed(0) : '',
    );

    useEffect(() {
      void listener() {
        final parsed = double.tryParse(controller.text.trim());
        if (parsed != null && parsed >= 0) {
          onUtilitiesAmountChanged(parsed);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.onboardingPreAuthUtilitiesTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _PreAuthOptionTile(
              label: context.l10n.onboardingPreAuthUtilitiesKnown,
              selected: utilitiesKnown,
              onTap: () => onUtilitiesKnownChanged(true),
            ),
            const SizedBox(height: 10),
            _PreAuthOptionTile(
              label: context.l10n.onboardingPreAuthUtilitiesUnknown,
              selected: !utilitiesKnown,
              onTap: () => onUtilitiesKnownChanged(false),
            ),
            const SizedBox(height: 16),
            if (utilitiesKnown)
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.monthlyUtilitiesAmount,
                  hintText: context.l10n.monthlyUtilitiesAmountHint,
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
      ),
    );
  }
}

class _PreAuthDebtStep extends HookWidget {
  const _PreAuthDebtStep({
    required this.debtMinimumPayments,
    required this.onDebtChanged,
  });

  final double debtMinimumPayments;
  final ValueChanged<double> onDebtChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(
      text:
          debtMinimumPayments > 0 ? debtMinimumPayments.toStringAsFixed(0) : '',
    );

    useEffect(() {
      void listener() {
        final parsed = double.tryParse(controller.text.trim());
        if (parsed != null && parsed >= 0) {
          onDebtChanged(parsed);
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
          Text(
            context.l10n.onboardingPreAuthDebtTitle,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.onboardingPreAuthDebtSubtitle,
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.l10n.debtMinimumPayments,
              hintText: context.l10n.debtMinimumPaymentsHint,
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

class _PreAuthSavingsStep extends HookWidget {
  const _PreAuthSavingsStep({
    required this.savingsMode,
    required this.savingsAmount,
    required this.savingsPercent,
    required this.onSavingsModeChanged,
    required this.onSavingsAmountChanged,
    required this.onSavingsPercentChanged,
  });

  final String savingsMode;
  final double savingsAmount;
  final double savingsPercent;
  final ValueChanged<String> onSavingsModeChanged;
  final ValueChanged<double> onSavingsAmountChanged;
  final ValueChanged<double> onSavingsPercentChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountController = useTextEditingController(
      text: savingsAmount > 0 ? savingsAmount.toStringAsFixed(0) : '',
    );
    final percentController = useTextEditingController(
      text: savingsPercent > 0 ? (savingsPercent * 100).toStringAsFixed(0) : '',
    );

    useEffect(() {
      void amountListener() {
        final parsed = double.tryParse(amountController.text.trim());
        if (parsed != null && parsed >= 0) {
          onSavingsAmountChanged(parsed);
        }
      }

      amountController.addListener(amountListener);
      return () => amountController.removeListener(amountListener);
    }, [amountController]);

    useEffect(() {
      void percentListener() {
        final parsed = double.tryParse(percentController.text.trim());
        if (parsed != null && parsed >= 0) {
          onSavingsPercentChanged(parsed / 100);
        }
      }

      percentController.addListener(percentListener);
      return () => percentController.removeListener(percentListener);
    }, [percentController]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.onboardingPreAuthSavingsTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _PreAuthOptionTile(
              label: context.l10n.onboardingQuestionSavingsFixed,
              selected: savingsMode == 'amount',
              onTap: () => onSavingsModeChanged('amount'),
            ),
            const SizedBox(height: 10),
            _PreAuthOptionTile(
              label: context.l10n.onboardingQuestionSavingsPercent,
              selected: savingsMode == 'percent',
              onTap: () => onSavingsModeChanged('percent'),
            ),
            const SizedBox(height: 10),
            _PreAuthOptionTile(
              label: context.l10n.onboardingQuestionSavingsNotSure,
              selected: savingsMode == 'not_sure',
              onTap: () => onSavingsModeChanged('not_sure'),
            ),
            const SizedBox(height: 16),
            if (savingsMode == 'amount')
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.amount,
                  hintText: '300',
                  filled: true,
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.border),
                  ),
                ),
              ),
            if (savingsMode == 'percent')
              TextField(
                controller: percentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.onboardingQuestionSavingsPercent,
                  hintText: '10',
                  suffixText: '%',
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
      ),
    );
  }
}

class _PreAuthGoalStep extends StatelessWidget {
  const _PreAuthGoalStep({
    required this.selectedGoal,
    required this.hasAnswered,
    required this.onGoalChanged,
  });

  final String selectedGoal;
  final bool hasAnswered;
  final ValueChanged<String> onGoalChanged;

  @override
  Widget build(BuildContext context) {
    return _PreAuthQuestionOptionsStep(
      title: _sharedQuestionStep(5).getTitle(context),
      options: _sharedQuestionOptions(context, 5),
      selectedValue: hasAnswered ? selectedGoal : '',
      onChanged: onGoalChanged,
    );
  }
}

class _PreAuthLifestyleStep extends StatelessWidget {
  const _PreAuthLifestyleStep({
    required this.selectedLifestyle,
    required this.hasAnswered,
    required this.onLifestyleChanged,
  });

  final String selectedLifestyle;
  final bool hasAnswered;
  final ValueChanged<String> onLifestyleChanged;

  @override
  Widget build(BuildContext context) {
    return _PreAuthQuestionOptionsStep(
      title: _sharedQuestionStep(4).getTitle(context),
      options: _sharedQuestionOptions(context, 4),
      selectedValue: hasAnswered ? selectedLifestyle : '',
      onChanged: onLifestyleChanged,
    );
  }
}

class _PreAuthSavingsTargetStep extends StatelessWidget {
  const _PreAuthSavingsTargetStep({
    required this.selectedMode,
    required this.hasAnswered,
    required this.onChanged,
  });

  final String selectedMode;
  final bool hasAnswered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PreAuthQuestionOptionsStep(
      title: _sharedQuestionStep(6).getTitle(context),
      options: _sharedQuestionOptions(context, 6),
      selectedValue: hasAnswered ? selectedMode : '',
      onChanged: onChanged,
    );
  }
}

class _PreAuthCurrencyStep extends HookConsumerWidget {
  const _PreAuthCurrencyStep({
    required this.selectedCurrency,
    required this.onChanged,
  });

  final String selectedCurrency;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = selectedCurrency.trim().toUpperCase();
    final hasSelectedCurrency = currency.isNotEmpty;
    final flagPath = hasSelectedCurrency ? getCurrencyFlagPath(currency) : null;

    Future<void> handleSelectCurrency() async {
      final selected = await showCurrencySelectorModal(
        context,
        ref,
        showAllByDefault: true,
      );
      if (selected == null || selected.isEmpty) {
        return;
      }
      onChanged(selected.toUpperCase());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onboardingPreAuthCurrencyTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: colorScheme.surface.withValues(alpha: 0.0),
            child: InkWell(
              onTap: handleSelectCurrency,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    if (flagPath != null) ...[
                      ClipOval(
                        child: Image.asset(
                          flagPath,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        hasSelectedCurrency
                            ? currency
                            : context.l10n.onboardingPreAuthCurrencySelect,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: hasSelectedCurrency
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasSelectedCurrency
                              ? colorScheme.foreground
                              : colorScheme.mutedForeground,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.onboardingPreAuthCurrencyChangeLater,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground,
            ),
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
        unawaited(progressController.forward(from: 0.0));
        await Future<void>.delayed(const Duration(milliseconds: 4500));
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
            context.l10n.onboardingPreAuthCalculatingTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
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
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PreAuthStarterStep extends StatelessWidget {
  const _PreAuthStarterStep({
    required this.draft,
    required this.onBudgetChanged,
  });

  final OnboardingPreauthDraft draft;
  final ValueChanged<double> onBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currency = draft.selectedCurrency.toUpperCase();
    final recommendation = BudgetRecommender.recommend(context, draft);
    final totalBudget = draft.monthlyBudget;
    final sliderConfig = _preauthBudgetSliderConfig(
      currencyCode: currency,
      values: [
        totalBudget,
        recommendation.fixedCostsTotal,
        recommendation.totalBudget,
      ],
    );
    final previewPockets = recommendation.pockets.map((item) {
      final budget = (totalBudget * item.weight).clamp(0, totalBudget);
      final previewFill = _starterPreviewFillRatio(
        item.name,
        hasBlockingRecommendation: recommendation.hasBlockingError,
      );
      return PocketEnvelope(
        id: 'starter-${item.name}',
        name: item.name,
        budgetAmountCents: (budget * 100).round(),
        spent: budget * previewFill,
        currency: currency,
        icon: item.iconName,
        color: _colorToHex(item.color),
        budgetId: null,
        householdId: null,
        lastUpdated: now,
      );
    }).toList(growable: false);

    String formatLocalizedCurrency(double amount) {
      final symbol = resolveCurrencySymbol(currency);
      final localized = formatLocalizedNumber(context, amount);
      return '$symbol$localized';
    }

    Future<void> showBudgetInputDialog() async {
      final result = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.onboardingPreAuthAdjustBudgetTitle,
        description: context.l10n.onboardingPreAuthAdjustBudgetSubtitle,
        confirmLabel: context.l10n.save,
        cancelLabel: context.l10n.cancel,
        inputConfig: MonekoAlertDialogInputConfig(
          initialValue: totalBudget.toStringAsFixed(0),
          placeholder: '0',
          isRequired: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          validationPattern: RegExp(r'^[0-9,]+$'),
          validationMessage:
              context.l10n.onboardingPreAuthAdjustBudgetValidation,
        ),
      );

      if (result == null || !result.confirmed || result.text == null) {
        return;
      }

      final parsed = double.tryParse(result.text!.trim().replaceAll(',', ''));
      if (parsed == null) {
        return;
      }

      onBudgetChanged(roundBudgetForCurrency(parsed, currency));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.onboardingPreAuthStarterTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.onboardingPreAuthStarterSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.onboardingPreAuthStarterSliderHint,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: colorScheme.surface.withValues(alpha: 0.0),
              child: InkWell(
                onTap: showBudgetInputDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.l10n.monthlyBudgetLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 72,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatLocalizedCurrency(totalBudget),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.foreground,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: colorScheme.primary,
                          inactiveTrackColor: colorScheme.mutedForeground
                              .withValues(alpha: 0.3),
                          thumbColor: colorScheme.primaryForeground,
                          trackHeight: 4,
                        ),
                        child: AdaptiveSlider(
                          activeColor: colorScheme.primary,
                          thumbColor: colorScheme.primaryForeground,
                          value: totalBudget.clamp(
                            sliderConfig.min,
                            sliderConfig.max,
                          ),
                          min: sliderConfig.min,
                          max: sliderConfig.max,
                          divisions: sliderConfig.divisions,
                          onChanged: (value) {
                            final roundedValue =
                                ((value - sliderConfig.min) / sliderConfig.step)
                                            .round() *
                                        sliderConfig.step +
                                    sliderConfig.min;
                            onBudgetChanged(
                              roundedValue
                                  .clamp(sliderConfig.min, sliderConfig.max)
                                  .toDouble(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatLocalizedCurrency(sliderConfig.min),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          Text(
                            formatLocalizedCurrency(sliderConfig.max),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (totalBudget > 0)
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(previewPockets.length, (index) {
                  return IgnorePointer(
                    child: PocketCard(
                      pocket: previewPockets[index],
                      currency: currency,
                      colorScheme: colorScheme,
                      totalBudget: totalBudget,
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

double _starterPreviewFillRatio(
  String pocketName, {
  required bool hasBlockingRecommendation,
}) {
  final hash = pocketName.runes.fold<int>(0, (acc, rune) => acc + rune);
  final base = 0.22 + ((hash % 38) / 100.0); // 22%..60%
  if (!hasBlockingRecommendation) {
    return base;
  }
  return (base * 0.85).clamp(0.16, 0.52);
}

class _PreauthBudgetSliderConfig {
  const _PreauthBudgetSliderConfig({
    required this.min,
    required this.max,
    required this.step,
    required this.divisions,
  });

  final double min;
  final double max;
  final double step;
  final int divisions;
}

_PreauthBudgetSliderConfig _preauthBudgetSliderConfig({
  required String currencyCode,
  required List<double> values,
}) {
  final normalizedCode = isSupportedCurrencyCode(currencyCode)
      ? currencyCode.toUpperCase()
      : 'USD';
  final range = preauthBudgetRangeForCurrency(normalizedCode);
  final observedMax = values
      .where((value) => value.isFinite && value > 0)
      .fold<double>(0, math.max);
  final candidateMax = math.max(range.baseline, observedMax).toDouble();
  final max = _roundUpToChunk(
    candidateMax.clamp(range.min, range.max).toDouble(),
    range.rounding,
  );
  final min = range.min;
  final rawStep = _calculateSliderStep(min, max);
  final divisions = _calculateSliderDivisions(min, max, rawStep);
  final step = (max - min) / divisions;

  return _PreauthBudgetSliderConfig(
    min: min,
    max: max,
    step: step,
    divisions: divisions,
  );
}

double _calculateSliderStep(double min, double max) {
  final span = max - min;
  if (span <= 0) return 1;

  final targetDivisions = span <= 50000
      ? 1000
      : span <= 500000
          ? 700
          : span <= 20000000
              ? 450
              : 300;
  return _niceSliderNumber(span / targetDivisions);
}

int _calculateSliderDivisions(double min, double max, double step) {
  if (step <= 0) return 1;
  final divisions = ((max - min) / step).round();
  return math.max(1, math.min(divisions, 1200));
}

double _roundUpToChunk(double value, double chunk) {
  final safeChunk = chunk.isFinite && chunk > 0 ? chunk : 10000.0;
  if (!value.isFinite || value <= 0) return safeChunk;
  final quotient = value / safeChunk;
  final rounded = quotient.isFinite ? quotient.ceilToDouble() : 1.0;
  return rounded * safeChunk;
}

double _niceSliderNumber(double rawStep) {
  if (!rawStep.isFinite || rawStep <= 0) return 1;
  final exponent = (math.log(rawStep) / math.ln10).floor();
  final magnitude = math.pow(10.0, exponent).toDouble();
  final fraction = rawStep / magnitude;

  double niceFraction;
  if (fraction <= 1) {
    niceFraction = 1;
  } else if (fraction <= 5) {
    niceFraction = 5;
  } else {
    niceFraction = 10;
  }

  return math.max(1, niceFraction * magnitude);
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
