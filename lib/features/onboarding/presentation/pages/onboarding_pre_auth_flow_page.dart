import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/households/presentation/widgets/household_image_picker.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
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
    const totalSteps = 7;

    final progressValue =
        ((currentPage.value + 1) / totalSteps).clamp(0.0, 1.0);

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
      draftState.value = draft;
      await ref.read(onboardingPreauthDraftStoreProvider).save(draft);
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

    Future<void> skip() async {
      await next();
    }

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Step ${currentPage.value + 1} of $totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progressValue),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: colorScheme.mutedForeground
                                .withValues(alpha: 0.2),
                            color: colorScheme.primary,
                          );
                        },
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
                    _PreAuthCurrencyStep(
                      selectedCurrency: draftState.value.selectedCurrency,
                      onSelected: (currency) {
                        final nextDraft = draftState.value.copyWith(
                          selectedCurrency: currency.toUpperCase(),
                        );
                        unawaited(persistDraft(nextDraft));
                        ref
                            .read(homeFilterProvider.notifier)
                            .setSelectedCurrency(currency.toUpperCase());
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
                        unawaited(persistDraft(nextDraft));
                      },
                    ),
                    _PreAuthLifestyleStep(
                      selectedLifestyle: draftState.value.lifestyleFocus,
                      onLifestyleChanged: (value) {
                        final nextDraft = draftState.value.copyWith(
                          lifestyleFocus: value,
                        );
                        unawaited(persistDraft(nextDraft));
                      },
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: PrimaryAdaptiveButton(
                        onPressed: () => unawaited(next()),
                        child: Text(
                          currentPage.value == totalSteps - 1
                              ? context.l10n.createAccount
                              : context.l10n.continueAction,
                        ),
                      ),
                    ),
                    if (currentPage.value < 5) ...[
                      const SizedBox(height: 8),
                      PlainAdaptiveButton(
                        onPressed: skip,
                        child: Text(
                          context.l10n.skipNow,
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    ],
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

class _PreAuthCurrencyStep extends ConsumerWidget {
  const _PreAuthCurrencyStep({
    required this.selectedCurrency,
    required this.onSelected,
  });

  final String selectedCurrency;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final upper = selectedCurrency.toUpperCase();
    final flagPath = getCurrencyFlagPath(upper);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding1.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.selectCurrencyForDailySpending,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We will personalize your budget and suggestions around this currency.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: GestureDetector(
              onTap: () async {
                await showCurrencySelectorModal(
                  context,
                  ref,
                  showAllByDefault: true,
                );
                final selected = ref
                    .read(homeFilterProvider)
                    .selectedCurrency
                    ?.toUpperCase();
                if (selected != null && selected.isNotEmpty) {
                  onSelected(selected);
                }
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colorScheme.selectedStateBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.controlBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (flagPath != null)
                      ClipOval(
                        child: Image.asset(
                          flagPath,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (flagPath != null) const SizedBox(width: 8),
                    Text(
                      upper,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      text: monthlyBudget.toStringAsFixed(0),
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
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.border),
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
                    color: colorScheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.4),
                    ),
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
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.border),
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
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: inviteExpiresInDays,
                decoration: InputDecoration(
                  labelText: 'Invite expires in',
                  filled: true,
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.border),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
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
              context.l10n.pocketsIntroTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
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
          const SizedBox(height: 10),
          Text(
            'We will set everything up automatically based on your answers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
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
