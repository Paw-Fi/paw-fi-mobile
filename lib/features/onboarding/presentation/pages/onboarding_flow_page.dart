// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/moneko_rich_text.dart';
import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/onboarding/data/onboarding_preauth_draft_store.dart';
import 'package:moneko/features/onboarding/domain/preauth_budget_profile.dart';
import 'package:moneko/features/onboarding/domain/budget_recommender.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:'; // per-user
const _kNotificationsPromptedPrefix = 'notifications_prompted:'; // per-user
const _kReturnToOrbitPageKey = 'onboarding_return_to_orbit_once';

String _importSourceLabel(ImportSourceApp source) {
  switch (source) {
    case ImportSourceApp.ynab:
      return 'YNAB';
    case ImportSourceApp.monarch:
      return 'Monarch';
    case ImportSourceApp.copilot:
      return 'Copilot';
    case ImportSourceApp.pocketGuard:
      return 'PocketGuard';
    case ImportSourceApp.splitwise:
      return 'Splitwise';
    case ImportSourceApp.everyDollar:
      return 'EveryDollar';
    case ImportSourceApp.cashew:
      return 'Cashew';
    case ImportSourceApp.mint:
      return 'Mint';
    case ImportSourceApp.goodbudget:
      return 'Goodbudget';
    case ImportSourceApp.spendee:
      return 'Spendee';
    case ImportSourceApp.other:
      return 'Other';
  }
}

String _guestIntroPageId() => 'onboarding_intro';

String _authenticatedOnboardingPageId(int stepIndex) {
  switch (stepIndex) {
    case 0:
      return 'onboarding_setup_notifications';
    case 1:
      return 'onboarding_setup_import';
    case 2:
      return 'onboarding_setup_ai_log';
    default:
      return 'onboarding_setup_unknown';
  }
}

String _authenticatedOnboardingStepKey(int stepIndex) {
  switch (stepIndex) {
    case 0:
      return 'notifications';
    case 1:
      return 'import';
    case 2:
      return 'ai_log';
    default:
      return 'unknown';
  }
}

class _GuestOnboardingFlow extends HookConsumerWidget {
  const _GuestOnboardingFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final prefs = ref.read(sharedPreferencesProvider);
    final shouldReturnToOrbitFromPrefs =
        prefs.getBool(_kReturnToOrbitPageKey) ?? false;
    final initialShowOrbit =
        GoRouterState.of(context).uri.queryParameters['entry'] == 'orbit' ||
            shouldReturnToOrbitFromPrefs;
    final isBusy = useState(false);
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);
    final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS;
    final introSlides = [
      (
        imagePath: 'lib/assets/images/onboarding/ready/ready1.png',
        title: context.l10n.onboardingIntroCarouselSlide1Title,
        body: context.l10n.onboardingIntroCarouselSlide1Body,
      ),
      (
        imagePath: 'lib/assets/images/onboarding/ready/ready2.png',
        title: context.l10n.onboardingIntroCarouselSlide2Title,
        body: context.l10n.onboardingIntroCarouselSlide2Body,
      ),
      (
        imagePath: 'lib/assets/images/onboarding/ready/ready3.png',
        title: context.l10n.onboardingIntroCarouselSlide3Title,
        body: context.l10n.onboardingIntroCarouselSlide3Body,
      ),
      (
        imagePath: 'lib/assets/images/onboarding/ready/ready4.png',
        title: context.l10n.onboardingIntroCarouselSlide4Title,
        body: context.l10n.onboardingIntroCarouselSlide4Body,
      ),
      (
        imagePath: 'lib/assets/images/onboarding/ready/ready5.png',
        title: context.l10n.onboardingIntroSlide5Title,
        body: isApplePlatform
            ? context.l10n.onboardingIntroSlide5AppleBody
            : context.l10n.onboardingIntroSlide5AndroidBody,
      ),
    ];

    final pageController = usePageController();
    final carouselIndex = useState(0);
    final showOrbitPage = useState(initialShowOrbit);

    useEffect(() {
      if (!shouldReturnToOrbitFromPrefs) return null;
      unawaited(prefs.remove(_kReturnToOrbitPageKey));
      return null;
    }, const []);

    useEffect(() {
      unawaited(
        analytics.beginPage(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex:
              showOrbitPage.value ? introSlides.length : carouselIndex.value,
          properties: <String, Object?>{'entry_path': 'guest_intro'},
        ),
      );
      return null;
    }, [carouselIndex.value, showOrbitPage.value]);

    Future<void> goToPreAuthQuestions() async {
      if (isBusy.value) return;
      isBusy.value = true;
      try {
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex:
              showOrbitPage.value ? introSlides.length : carouselIndex.value,
          actionId: 'intro_completed',
          result: 'used',
          properties: const <String, Object?>{'step_group': 'guest_intro'},
        );
        await analytics.endPage(
          reason: 'intro_completed',
          transitionTo: 'preauth_housing_situation',
        );
        final store = ref.read(onboardingPreauthDraftStoreProvider);
        final current = store.load();
        await store.save(current.copyWith(currentStep: 0));
        if (!context.mounted) return;
        context.go('/onboarding?stage=pre');
      } finally {
        if (context.mounted) {
          isBusy.value = false;
        }
      }
    }

    Future<void> goToPreviewMode() async {
      if (isBusy.value) return;
      isBusy.value = true;
      try {
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex:
              showOrbitPage.value ? introSlides.length : carouselIndex.value,
          actionId: 'preview_app_tapped',
          result: 'used',
          properties: const <String, Object?>{
            'step_group': 'guest_intro',
            'preview_entry_point': 'get_started',
          },
        );
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex:
              showOrbitPage.value ? introSlides.length : carouselIndex.value,
          actionId: 'intro_preview_app',
          result: 'used',
          properties: const <String, Object?>{
            'step_group': 'guest_intro',
            'preview_entry_point': 'get_started',
          },
        );
        await analytics.endPage(
          reason: 'intro_preview_app',
          transitionTo: '/dashboard',
        );
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool(kPreviewModeActiveKey, true);
        await prefs.setBool(kPreviewReturnToPreauthKey, false);
        await prefs.setString(kPreviewExitRouteKey, '/onboarding?entry=orbit');
        await prefs.setBool(_kReturnToOrbitPageKey, true);
        ref.read(previewModeProvider.notifier).enable();
        if (!context.mounted) return;
        context.go('/dashboard');
      } finally {
        if (context.mounted) {
          isBusy.value = false;
        }
      }
    }

    Future<void> goToLogin() async {
      if (isBusy.value) return;
      isBusy.value = true;
      try {
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex:
              showOrbitPage.value ? introSlides.length : carouselIndex.value,
          actionId: 'intro_sign_in_tapped',
          result: 'used',
          properties: const <String, Object?>{'step_group': 'guest_intro'},
        );
        await analytics.endPage(
          reason: 'intro_sign_in',
          transitionTo: '/login',
        );
        if (!context.mounted) return;
        context.go('/login');
      } finally {
        if (context.mounted) {
          isBusy.value = false;
        }
      }
    }

    void goNext() {
      if (showOrbitPage.value) {
        unawaited(goToPreAuthQuestions());
        return;
      }
      unawaited(
        analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex: carouselIndex.value,
          actionId: 'intro_next',
          result: 'used',
          properties: const <String, Object?>{'step_group': 'guest_intro'},
        ),
      );
      if (carouselIndex.value >= introSlides.length - 1) {
        showOrbitPage.value = true;
        return;
      }
      final nextPage = carouselIndex.value + 1;
      if (pageController.hasClients) {
        unawaited(pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        ));
      } else {
        carouselIndex.value = nextPage;
      }
    }

    void goBack() {
      if (showOrbitPage.value) {
        showOrbitPage.value = false;
        if (pageController.hasClients) {
          pageController.jumpToPage(introSlides.length - 1);
        } else {
          carouselIndex.value = introSlides.length - 1;
        }
        return;
      }
      if (carouselIndex.value <= 0) return;
      unawaited(
        analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _guestIntroPageId(),
          stepIndex: carouselIndex.value,
          actionId: 'intro_back',
          result: 'used',
          properties: const <String, Object?>{'step_group': 'guest_intro'},
        ),
      );
      final previousPage = carouselIndex.value - 1;
      if (pageController.hasClients) {
        unawaited(pageController.animateToPage(
          previousPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        ));
      } else {
        carouselIndex.value = previousPage;
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: null,
      body: Material(
        color: colorScheme.appBackground,
        child: Stack(
          children: [
            const _OnboardingHeroBackground(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                (showOrbitPage.value || carouselIndex.value > 0)
                                    ? goBack
                                    : null,
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Debug back',
                          ),
                          IconButton(
                            onPressed: goNext,
                            icon: const Icon(Icons.skip_next_rounded),
                            tooltip: 'Debug next',
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                context.go('/onboarding?stage=post&debug=post'),
                            child: const Text('Debug post'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: showOrbitPage.value
                        ? _GuestOrbitPage(
                            onNext: goNext,
                            onPreview: () => unawaited(goToPreviewMode()),
                            onSignIn: () => unawaited(goToLogin()),
                          )
                        : _GuestCarouselPage(
                            slides: introSlides,
                            controller: pageController,
                            currentIndex: carouselIndex.value,
                            onPageChanged: (index) =>
                                carouselIndex.value = index,
                            onNext: goNext,
                          ),
                  ),
                  SizedBox(height: 16 + bottomPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _OnboardingHeroBackground extends StatelessWidget {
  const _OnboardingHeroBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'lib/assets/images/paywall/background-gradient.svg',
        width: MediaQuery.sizeOf(context).width,
        fit: BoxFit.cover,
      ),
    );
  }
}

String? _colorToHex(Color? color) {
  if (color == null) return null;
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

class _GuestCarouselPage extends StatelessWidget {
  const _GuestCarouselPage({
    required this.slides,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onNext,
  });

  final List<({String imagePath, String title, String body})> slides;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            context.l10n.onboardingIntroCarouselTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colorScheme.foreground,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.onboardingIntroCarouselSubtitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: onPageChanged,
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index];
                return _GuestCarouselItem(
                  imagePath: slide.imagePath,
                  title: slide.title,
                  body: slide.body,
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (index) {
              final isActive = index == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: isActive ? 18 : 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: PrimaryAdaptiveButton(
              onPressed: onNext,
              child: Text(context.l10n.next),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestCarouselItem extends StatelessWidget {
  const _GuestCarouselItem({
    required this.imagePath,
    required this.title,
    required this.body,
  });

  final String imagePath;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            imagePath,
            height: 320,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonekoRichText(
                text: title,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
                highlightStyle: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  body,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestOrbitPage extends StatelessWidget {
  const _GuestOrbitPage({
    required this.onNext,
    required this.onPreview,
    required this.onSignIn,
  });

  final VoidCallback onNext;
  final VoidCallback onPreview;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 20, 28, 20 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.topLeft,
            child: MonekoRichText(
              text: context.l10n.onboardingIntroSlide4Title,
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                height: 1.375,
                letterSpacing: 0,
              ),
              highlightStyle: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                height: 1.375,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(child: _OnboardingOrbitHero()),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: PrimaryAdaptiveButton(
              onPressed: onNext,
              child: Text(context.l10n.onboardingIntroGetMyPlan),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onPreview,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.border),
              ),
              child: Text(
                context.l10n.onboardingPreAuthSaveBudgetPreview,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: onSignIn,
              child: Text(
                context.l10n.onboardingIntroAlreadyHaveAccount,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroSlide extends HookWidget {
  const _IntroSlide({
    required this.title,
    required this.body,
    required this.imagePath,
    required this.currentIndex,
    required this.totalSlides,
    required this.indicatorSteps,
    required this.isFinalSlide,
    required this.onNext,
    required this.onPreview,
  });

  final String title;
  final String body;
  final String? imagePath;
  final int currentIndex;
  final int totalSlides;
  final int indicatorSteps;
  final bool isFinalSlide;
  final VoidCallback onNext;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // Staggered entrance animation
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 650),
    );

    useEffect(() {
      animationController.forward(from: 0.0);
      return null;
    }, [currentIndex]);

    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    final slideAnim =
        Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    final actionFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    final actionSlideAnim =
        Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(28, 20, 28, 20 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isFinalSlide)
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.onboardingIntroCarouselTitle,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colorScheme.foreground,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.onboardingIntroCarouselSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          if (!isFinalSlide)
            Expanded(
              child: FadeTransition(
                opacity: fadeAnim,
                child: SlideTransition(
                  position: slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imagePath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            imagePath!,
                            height: 320,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonekoRichText(
                                text: title,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                                highlightStyle: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Content column for final slide
            Expanded(
              child: FadeTransition(
                opacity: fadeAnim,
                child: SlideTransition(
                  position: slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title text
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: MonekoRichText(
                            text: context.l10n.onboardingIntroSlide4Title,
                            style: TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.foreground,
                              height: 1.375,
                              letterSpacing: 0,
                            ),
                            highlightStyle: TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              height: 1.375,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Orbit circle (takes remaining space)
                      Expanded(
                        child: FadeTransition(
                          opacity: actionFadeAnim,
                          child: SlideTransition(
                            position: actionSlideAnim,
                            child: const _OnboardingOrbitHero(),
                          ),
                        ),
                      ),
                      // Final slide actions
                      FadeTransition(
                        opacity: actionFadeAnim,
                        child: SlideTransition(
                          position: actionSlideAnim,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24, top: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: PrimaryAdaptiveButton(
                                    onPressed: onNext,
                                    child: Text(
                                      context.l10n.onboardingIntroGetMyPlan,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: onPreview,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colorScheme.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.border,
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n
                                          .onboardingPreAuthSaveBudgetPreview,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: GestureDetector(
                                    onTap: () => context.go('/login'),
                                    child: Text(
                                      context.l10n
                                          .onboardingIntroAlreadyHaveAccount,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!isFinalSlide)
            FadeTransition(
              opacity: actionFadeAnim,
              child: SlideTransition(
                position: actionSlideAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(indicatorSteps, (index) {
                          final isActive = index == currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: isActive ? 18 : 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.border.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: PrimaryAdaptiveButton(
                          onPressed: onNext,
                          child: Text(context.l10n.next),
                        ),
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

class _OnboardingOrbitHero extends HookWidget {
  const _OnboardingOrbitHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useAnimationController(
      duration: const Duration(seconds: 40),
    )..repeat();

    final innerBubbles = [
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleExpense1,
        icon: Icons.mic_rounded,
        baseAngle: 0,
      ),
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleExpense2,
        icon: Icons.account_balance_wallet_rounded,
        baseAngle: 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleExpense3,
        icon: Icons.family_restroom_rounded,
        baseAngle: 4 * math.pi / 3,
      ),
    ];

    final outerBubbles = [
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleInsight1,
        icon: Icons.pie_chart_rounded,
        baseAngle: math.pi / 6,
      ),
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleInsight2,
        icon: Icons.chat_rounded,
        baseAngle: math.pi / 6 + 2 * math.pi / 3,
      ),
      _OrbitBubbleData(
        text: context.l10n.orbitBubbleInsight3,
        icon: Icons.event_repeat_rounded,
        baseAngle: math.pi / 6 + 4 * math.pi / 3,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) - 50;
        final center = Offset(constraints.maxWidth / 2, size / 2 + 20);
        final innerRadius = size * 0.28;
        final outerRadius = size * 0.45;
        const avatarSize = 60.0;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final innerAngleOffset = t * 2 * math.pi;
            final outerAngleOffset = -t * 2 * math.pi;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Inner rings
                Positioned.fill(
                  child: CustomPaint(
                    painter: _OrbitRingsPainter(
                      innerRadius: innerRadius,
                      outerRadius: outerRadius,
                      ringColor: colorScheme.border.withValues(alpha: 0.2),
                      centerOffset: center,
                    ),
                  ),
                ),

                // Inner orbit bubbles
                ...innerBubbles.map((bubble) {
                  final angle = bubble.baseAngle + innerAngleOffset;
                  final x = center.dx + innerRadius * math.cos(angle);
                  final y = center.dy + innerRadius * math.sin(angle);
                  return _buildBubble(
                    x: x,
                    y: y,
                    bubble: bubble,
                    colorScheme: colorScheme,
                  );
                }),

                // Outer orbit bubbles
                ...outerBubbles.map((bubble) {
                  final angle = bubble.baseAngle + outerAngleOffset;
                  final x = center.dx + outerRadius * math.cos(angle);
                  final y = center.dy + outerRadius * math.sin(angle);
                  return _buildBubble(
                    x: x,
                    y: y,
                    bubble: bubble,
                    colorScheme: colorScheme,
                  );
                }),

                // Center avatar/icon
                Positioned(
                  left: center.dx - avatarSize / 2,
                  top: center.dy - avatarSize / 2,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.card,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'lib/assets/mascots/moneko-avatar.gif',
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Positioned _buildBubble({
    required double x,
    required double y,
    required _OrbitBubbleData bubble,
    required ColorScheme colorScheme,
  }) {
    return Positioned(
      left: x - 65,
      top: y - 20,
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bubble.icon,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                bubble.text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({
    required this.innerRadius,
    required this.outerRadius,
    required this.ringColor,
    required this.centerOffset,
  });

  final double innerRadius;
  final double outerRadius;
  final Color ringColor;
  final Offset centerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(centerOffset, innerRadius, paint);
    canvas.drawCircle(centerOffset, outerRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.innerRadius != innerRadius ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.centerOffset != centerOffset;
}

class _OrbitBubbleData {
  const _OrbitBubbleData({
    required this.text,
    required this.icon,
    required this.baseAngle,
  });

  final String text;
  final IconData icon;
  final double baseAngle;
}

class OnboardingFlowPage extends HookConsumerWidget {
  const OnboardingFlowPage({
    super.key,
    this.fromSettings = false,
    this.debugForcePostFlow = false,
  });

  final bool fromSettings;
  final bool debugForcePostFlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.isEmpty && !debugForcePostFlow) {
      return const _GuestOnboardingFlow();
    }

    final pageController = usePageController();
    final currentPage = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    final notificationFlowStarted = useState(false);
    final notificationFlowCompleted = useState(false);
    final selectedImportSource = useState<ImportSourceApp?>(null);
    final aiLogSuccess = useState<AiLogSuccess?>(null);
    final isPrimaryBusy = useState(false);
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);
    const totalSteps = 3;

    useEffect(() {
      unawaited(
        analytics.beginPage(
          flowName: 'onboarding_funnel',
          pageId: _authenticatedOnboardingPageId(currentPage.value),
          stepIndex: currentPage.value,
          enableTracking: !fromSettings,
          properties: <String, Object?>{
            'from_settings': fromSettings,
            'step_key': _authenticatedOnboardingStepKey(currentPage.value),
          },
        ),
      );
      return null;
    }, [currentPage.value, fromSettings]);

    void goToPage(int targetPage) {
      if (!context.mounted) return;
      void go() {
        unawaited(pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ));
      }

      if (pageController.hasClients) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (!pageController.hasClients) return;
          go();
        });
      }
    }

    Future<void> showFinishPage() async {
      if (!context.mounted) return;
      await _completeOnboarding(context, ref);
    }

    void next() {
      if (!context.mounted) return;
      if (currentPage.value < totalSteps - 1) {
        final targetPage = currentPage.value + 1;
        goToPage(targetPage);
      } else {
        unawaited(showFinishPage());
      }
    }

    Future<void> trackSkipAction() async {
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _authenticatedOnboardingPageId(currentPage.value),
        stepIndex: currentPage.value,
        actionId:
            '${_authenticatedOnboardingStepKey(currentPage.value)}_skipped',
        result: 'skipped',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'authenticated_onboarding',
          'step_key': _authenticatedOnboardingStepKey(currentPage.value),
          if (selectedImportSource.value != null)
            'selected_import_source':
                _importSourceLabel(selectedImportSource.value!),
        },
      );
    }

    void skip() {
      unawaited(trackSkipAction());
      next();
    }

    Future<void> handleNotificationsFlow() async {
      if (!context.mounted) return;
      if (notificationFlowStarted.value || notificationFlowCompleted.value) {
        if (notificationFlowCompleted.value) {
          next();
        }
        return;
      }

      notificationFlowStarted.value = true;
      final uid = ref.read(authProvider).uid;
      final prefs = ref.read(sharedPreferencesProvider);
      final deviceRegistration = ref.read(deviceRegistrationServiceProvider);
      try {
        final promptedKey = '$_kNotificationsPromptedPrefix$uid';
        final prompted = prefs.getBool(promptedKey) ?? false;
        if (!prompted) {
          await prefs.setBool(promptedKey, true);
        }

        if (!context.mounted) return;

        try {
          await deviceRegistration.initialize();
        } catch (_) {}

        if (!context.mounted) return;

        notificationFlowCompleted.value = true;
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _authenticatedOnboardingPageId(0),
          stepIndex: 0,
          actionId: 'notifications_enabled',
          result: 'used',
          enableTracking: !fromSettings,
          properties: const <String, Object?>{
            'step_group': 'authenticated_onboarding',
            'step_key': 'notifications',
          },
        );
        next();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> primary() async {
      if (isPrimaryBusy.value) return;
      isPrimaryBusy.value = true;
      try {
        if (currentPage.value == 0) {
          await handleNotificationsFlow();
          return;
        }

        if (currentPage.value == 1) {
          final source = selectedImportSource.value;
          if (source == null) {
            await analytics.trackAction(
              flowName: 'onboarding_funnel',
              pageId: _authenticatedOnboardingPageId(1),
              stepIndex: 1,
              actionId: 'import_skipped_no_source',
              result: 'skipped',
              enableTracking: !fromSettings,
              properties: const <String, Object?>{
                'step_group': 'authenticated_onboarding',
                'step_key': 'import',
              },
            );
            next();
            return;
          }

          await analytics.trackAction(
            flowName: 'onboarding_funnel',
            pageId: _authenticatedOnboardingPageId(1),
            stepIndex: 1,
            actionId: 'import_started',
            result: 'used',
            enableTracking: !fromSettings,
            properties: <String, Object?>{
              'step_group': 'authenticated_onboarding',
              'step_key': 'import',
              'selected_import_source': _importSourceLabel(source),
            },
          );

          final imported = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ImportWizardPage(
                lockPersonalTarget: true,
                sourceApp: source,
              ),
            ),
          );

          if (!context.mounted) return;
          if (imported == true) {
            await analytics.trackAction(
              flowName: 'onboarding_funnel',
              pageId: _authenticatedOnboardingPageId(1),
              stepIndex: 1,
              actionId: 'import_completed',
              result: 'success',
              enableTracking: !fromSettings,
              properties: <String, Object?>{
                'step_group': 'authenticated_onboarding',
                'step_key': 'import',
                'selected_import_source': _importSourceLabel(source),
              },
            );
            next();
            return;
          }
          await analytics.trackAction(
            flowName: 'onboarding_funnel',
            pageId: _authenticatedOnboardingPageId(1),
            stepIndex: 1,
            actionId: 'import_cancelled',
            result: 'cancelled',
            enableTracking: !fromSettings,
            properties: <String, Object?>{
              'step_group': 'authenticated_onboarding',
              'step_key': 'import',
              'selected_import_source': _importSourceLabel(source),
            },
          );
          return;
        }

        if (currentPage.value == 2) {
          if (aiLogSuccess.value != null) {
            next();
            return;
          }

          await handleAiFreeFormText(
            context,
            ref,
            onSuccess: (success) {
              aiLogSuccess.value = success;
              unawaited(
                analytics.trackAction(
                  flowName: 'onboarding_funnel',
                  pageId: _authenticatedOnboardingPageId(2),
                  stepIndex: 2,
                  actionId: 'ai_log_completed',
                  result: 'success',
                  enableTracking: !fromSettings,
                  properties: const <String, Object?>{
                    'step_group': 'authenticated_onboarding',
                    'step_key': 'ai_log',
                  },
                ),
              );
            },
          );
          return;
        }

        // Default: advance to next step
        next();
      } finally {
        if (context.mounted) {
          isPrimaryBusy.value = false;
        }
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: currentPage.value > 0
                            ? () => goToPage(currentPage.value - 1)
                            : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Debug back',
                      ),
                      IconButton(
                        onPressed: currentPage.value < totalSteps - 1
                            ? () => goToPage(currentPage.value + 1)
                            : () => unawaited(showFinishPage()),
                        icon: const Icon(Icons.skip_next_rounded),
                        tooltip: 'Debug next',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    // IMPORTANT: Only build the current step.
                    // PageView keeps offstage pages alive; building all steps
                    // can trigger heavy providers/services during tests and
                    // early onboarding frames.
                    currentPage.value == 0
                        ? const _NotificationsStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 1
                        ? _DataImportSourceStep(
                            selected: selectedImportSource.value,
                            onSelected: (value) {
                              selectedImportSource.value = value;
                              unawaited(
                                analytics.trackAction(
                                  flowName: 'onboarding_funnel',
                                  pageId: _authenticatedOnboardingPageId(1),
                                  stepIndex: 1,
                                  actionId: 'import_source_selected',
                                  result: 'used',
                                  enableTracking: !fromSettings,
                                  properties: <String, Object?>{
                                    'step_group': 'authenticated_onboarding',
                                    'step_key': 'import',
                                    'selected_import_source':
                                        _importSourceLabel(value),
                                  },
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                    currentPage.value == 2
                        ? _AiLogStep(
                            onSuccess: (success) =>
                                aiLogSuccess.value = success,
                            lastSuccess: aiLogSuccess.value,
                          )
                        : const SizedBox.shrink(),
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
                        onPressed: isPrimaryBusy.value
                            ? null
                            : () {
                                // Fire-and-forget call to async handler to avoid type mismatch
                                // and ensure reliable button taps
                                unawaited(primary());
                              },
                        child: Text(
                          currentPage.value == 0
                              ? context.l10n.turnOnNotifications
                              : currentPage.value == 1
                                  ? (selectedImportSource.value == null
                                      ? context.l10n.continueAction
                                      : 'Import and continue')
                                  : (aiLogSuccess.value != null
                                      ? context.l10n.continueAction
                                      : context.l10n.tryNow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlainAdaptiveButton(
                      onPressed:
                          (currentPage.value == 2 && aiLogSuccess.value != null)
                              ? null
                              : skip,
                      child: Text(
                        context.l10n.skipNow,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _markOnboardingCompleted(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final uid = ref.read(authProvider).uid;
    await prefs.setBool('$_kOnboardingCompletedPrefix$uid', true);
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    await _markOnboardingCompleted(ref);
    if (!context.mounted) return;
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);
    if (fromSettings) {
      await analytics.endPage(
        reason: 'settings_onboarding_closed',
        transitionTo: '/settings',
      );
      Navigator.of(context).pop();
    } else {
      await analytics.completeSession(
        flowName: 'onboarding_funnel',
        pageId: _authenticatedOnboardingPageId(2),
        stepIndex: 2,
        properties: const <String, Object?>{
          'completion_target': 'dashboard',
        },
      );
      context.go('/dashboard');
    }
  }
}

class _CurrencyStep extends HookConsumerWidget {
  const _CurrencyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase() ?? 'USD';
    final flagPath = getCurrencyFlagPath(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            context.l10n.selectCurrencyForDailySpending,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding1.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.currency,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await showCurrencySelectorModal(
                        context,
                        ref,
                        showAllByDefault: true,
                      );
                      final user = ref.read(authProvider);
                      if (user.uid.isNotEmpty) {
                        ref.read(analyticsProvider.notifier).refresh(user.uid);

                        final currentView = ref.read(viewModeProvider);
                        final selectedHousehold =
                            ref.read(selectedHouseholdProvider);
                        final householdId =
                            currentView.mode == ViewMode.household
                                ? selectedHousehold.householdId
                                : null;
                        ref
                            .read(recurringTransactionsProvider(householdId)
                                .notifier)
                            .refresh(user.uid);
                        ref.invalidate(pocketsProvider);
                      }
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.selectedStateBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colorScheme.controlBorder,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.spotlightShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (flagPath != null) ...[
                            ClipOval(
                              child: Image.asset(
                                flagPath,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          if (flagPath != null) const SizedBox(width: 8),
                          Text(
                            selected,
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
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
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends HookConsumerWidget {
  const _BudgetStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Personal current month scope
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final scopeParams = PocketsScopeParams(
        scope: PocketsScopeType.personal, periodMonth: monthStart);
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);

    final currency =
        (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    final total = state.totalBudget;
    final prev = state.previousBudget;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.createSpendingLimitForCategory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding2.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          PocketsHeaderCard(
            totalBudget: total,
            totalAllocated: state.saved
                .fold<double>(0.0, (s, p) => s + (p.budgetAmountCents / 100.0)),
            totalSpent: state.totalSpent,
            periodMonth: state.periodMonth,
            previousBudget: prev,
            onReusePrevious:
                prev > 0 ? () => notifier.reusePreviousBudget(prev) : null,
            colorScheme: colorScheme,
            onTotalChanged: notifier.updateTotalBudget,
            onSave: () async => notifier.saveChanges(),
            currency: currency,
            onDateSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

class _NotificationsStep extends HookConsumerWidget {
  const _NotificationsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.getNotifiedBeforeSpendingLimit,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding3.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          // Sample notification card (visual only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.border.withValues(alpha: 0.06), width: 1),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.newMessage,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground)),
                      const SizedBox(height: 2),
                      Text(context.l10n.closeToSpendingLimit,
                          style: TextStyle(color: colorScheme.mutedForeground)),
                    ],
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

class _DataImportSourceStep extends StatelessWidget {
  const _DataImportSourceStep({
    required this.selected,
    required this.onSelected,
  });

  final ImportSourceApp? selected;
  final ValueChanged<ImportSourceApp> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Are you currently using other app?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick your source to see exactly which file to upload. We import into your personal account in the next step.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.mutedForeground,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          for (final source in importSourceSpecs) ...[
            _ImportSourceCard(
              spec: source,
              selected: selected == source.app,
              onTap: () => onSelected(source.app),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ImportSourceCard extends StatelessWidget {
  const _ImportSourceCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final ImportSourceSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : colorScheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.border.withValues(alpha: 0.2),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.cardSurface.withValues(alpha: 0.9),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.import_export_rounded,
                  size: 16,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _importSourceLabel(spec.app),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
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

class _HouseholdStep extends HookConsumerWidget {
  const _HouseholdStep({required this.name, required this.onNameChanged});

  final String name;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(text: name);
    useEffect(() {
      void listener() => onNameChanged(controller.text);
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
              context.l10n.inviteOthersToShareBudget,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SvgPicture.asset(
                'lib/assets/images/onboarding/onboarding4.svg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            // Visual create-a-space card with editable name
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.06),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.createSpace,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: context.l10n.householdNameHint,
                      hintStyle: TextStyle(
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: colorScheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme.border.withValues(alpha: 0.12),
                            width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme.border.withValues(alpha: 0.12),
                            width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PocketsIntroStep extends HookConsumerWidget {
  const _PocketsIntroStep({
    required this.didCreateSpace,
    required this.pocketCreated,
  });

  final bool didCreateSpace;
  final bool pocketCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currency =
        (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    // Watch pockets state for success detection
    final selectedHousehold = ref.watch(selectedHouseholdProvider);
    final monthStart = DateTime(now.year, now.month, 1);
    final scopeParams = didCreateSpace && selectedHousehold.householdId != null
        ? PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: selectedHousehold.householdId,
            periodMonth: monthStart,
          )
        : PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
          );
    final pocketsState = ref.watch(pocketsProvider(scopeParams));

    // Staggered animation for mock cards
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      animController.forward();
      return null;
    }, []);

    final draft = derivePreauthBudgetProfile(
      ref.read(onboardingPreauthDraftStoreProvider).load(),
    );
    final recommendation = BudgetRecommender.recommend(context, draft);
    final previewTotal = draft.monthlyBudget > 0 ? draft.monthlyBudget : 1.0;
    final previewPockets = recommendation.pockets
        .map(
          (item) => PocketEnvelope(
            id: 'preview-${item.name}',
            name: item.name,
            budgetAmountCents: (item.weight * previewTotal * 100).round(),
            spent: 0,
            currency: currency,
            icon: item.iconName,
            color: _colorToHex(item.color),
            budgetId: null,
            householdId: null,
            lastUpdated: now,
          ),
        )
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
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
            // Subtitle
            Text(
              context.l10n.pocketsIntroSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Benefit chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BenefitChip(
                    icon: Icons.category_rounded,
                    label: context.l10n.pocketsIntroBenefitTrack,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _BenefitChip(
                    icon: Icons.shield_rounded,
                    label: context.l10n.pocketsIntroBenefitLimit,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _BenefitChip(
                    icon: Icons.bar_chart_rounded,
                    label: context.l10n.pocketsIntroBenefitVisual,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recommender pocket grid with staggered animation
            if (!pocketCreated)
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(previewPockets.length, (index) {
                  final interval = Interval(
                    index * 0.15,
                    (index * 0.15 + 0.5).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic,
                  );
                  return AnimatedBuilder(
                    animation: animController,
                    builder: (context, child) {
                      final value = interval.transform(animController.value);
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: IgnorePointer(
                      child: PocketCard(
                        pocket: previewPockets[index],
                        currency: currency,
                        colorScheme: colorScheme,
                        totalBudget: previewTotal,
                        envelopeMode: true,
                      ),
                    ),
                  );
                }),
              ),

            // Success state: show real pockets
            if (pocketCreated && pocketsState.editing.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.successSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.successBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: colorScheme.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pocketsState.editing.length} pocket${pocketsState.editing.length > 1 ? 's' : ''} created!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expands [ParsedExpense] items so that each breakdown line becomes its own
/// display entry. Items without a breakdown are kept as-is.
List<ParsedExpense> _expandBreakdownItems(List<ParsedExpense> items) {
  final result = <ParsedExpense>[];
  final amountRe = RegExp(r'[\d]+[.,]?\d*');

  for (final item in items) {
    final breakdown = item.breakdown;
    if (breakdown == null || breakdown.length < 2) {
      result.add(item);
      continue;
    }

    for (final line in breakdown) {
      // Try to extract amount from the breakdown string (e.g. "burger €5.00")
      final match = amountRe.allMatches(line).lastOrNull;
      final amount = match != null
          ? double.tryParse(match.group(0)!.replaceAll(',', '.'))
          : null;

      // Description is everything before the amount match, stripped of
      // currency symbols and whitespace.
      final desc = match != null
          ? line
              .substring(0, match.start)
              .replaceAll(RegExp(r'[€\$£¥₹]'), '')
              .trim()
          : line.trim();

      result.add(item.copyWith(
        description: desc.isNotEmpty ? desc : item.description,
        amount: amount ?? item.amount / breakdown.length,
        breakdown: null,
      ));
    }
  }
  return result;
}

class _AiLogStep extends HookConsumerWidget {
  const _AiLogStep({required this.onSuccess, required this.lastSuccess});

  final ValueChanged<AiLogSuccess> onSuccess;
  final AiLogSuccess? lastSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final success = lastSuccess;
    final items = success != null
        ? _expandBreakdownItems(success.items)
        : const <ParsedExpense>[];
    final hasSuccess = success != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: hasSuccess
                  ? const SizedBox.shrink()
                  : Column(
                      key: const ValueKey('ai-log-intro'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    colorScheme.border.withValues(alpha: 0.4),
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'lib/assets/mascots/moneko-avatar.gif',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.tryAiLoggingTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          context.l10n.tryAiLoggingSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 35),
                        Text(
                          context.l10n.aiPromptExamplesTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.homeCardSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.homeCardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.homeCardShadow,
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample1,
                                  ),
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample2,
                                  ),
                                  _AiPromptChip(
                                    text: context.l10n.aiPromptExample3,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Text(
                          context.l10n.aiPromptExamplesDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (success != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: colorScheme.successSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.successBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.success.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.celebration_rounded,
                          color: colorScheme.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.aiFirstLogCongratsTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.aiFirstLogCongratsBody(
                      items.length,
                      success.targetLabel,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.aiLogSummaryTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.homeCardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.homeCardBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.homeCardShadow,
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (int i = 0; i < items.take(5).length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 56,
                        color: colorScheme.border.withValues(alpha: 0.08),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TransactionListTile(
                        category: items[i].category,
                        title:
                            getCategoryTranslation(context, items[i].category),
                        description: items[i].description,
                        subtitle: DateFormat.yMMMd(
                          intlSafeLocaleName(Localizations.localeOf(context)),
                        ).format(items[i].date),
                        amount: items[i].amount,
                        currency: items[i].currency,
                        isIncome: items[i].isIncome,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.aiLogSummaryMore(items.length - 5),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: colorScheme.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.aiCapabilitiesHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AiPromptChip extends StatelessWidget {
  const _AiPromptChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        '"$text"',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
        ),
      ),
    );
  }
}

class _AiActionChip extends StatelessWidget {
  const _AiActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiActionRow extends StatelessWidget {
  const _AiActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.border.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
