import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/presentation/pages/register_screen.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';

class OnboardingSaveBudgetPage extends HookConsumerWidget {
  const OnboardingSaveBudgetPage({super.key});

  Future<void> _exploreAppInPreview(BuildContext context, WidgetRef ref) async {
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);

    await analytics.trackAction(
      flowName: 'onboarding_funnel',
      pageId: 'onboarding_save_budget',
      stepIndex: 14,
      actionId: 'try_demo',
      result: 'used',
      properties: const <String, Object?>{
        'step_group': 'preauth',
        'step_key': 'create_account',
      },
    );

    await analytics.endPage(
      reason: 'try_demo',
      transitionTo: '/dashboard',
    );

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(kPreviewModeActiveKey, true);
    await prefs.setBool(kPreviewReturnToPreauthKey, true);
    await prefs.setString(
        kPreviewExitRouteKey, '/onboarding?stage=save_budget');
    ref.read(previewModeProvider.notifier).enable();
    if (!context.mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);

    useEffect(() {
      analytics.beginPage(
        flowName: 'onboarding_funnel',
        pageId: 'onboarding_save_budget',
        stepIndex: 14,
        properties: const <String, Object?>{
          'step_group': 'preauth',
          'step_key': 'create_account',
        },
      );
      return null;
    }, const []);

    final header = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Text(
            context.l10n.onboardingPreAuthSaveBudgetTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: theme.colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.onboardingPreAuthSaveBudgetSubtitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.mutedForeground,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final footer = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${context.l10n.alreadyHaveAccount} ',
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                context.l10n.signInLower,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: Material(
            color: theme.colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _exploreAppInPreview(context, ref),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.border),
                ),
                child: Text(
                  context.l10n.onboardingPreAuthSaveBudgetPreview,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return RegisterScreen(
      header: header,
      footer: footer,
    );
  }
}
