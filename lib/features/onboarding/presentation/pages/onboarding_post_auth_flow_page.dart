import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/analytics/onboarding_flow_analytics_service.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_actions.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:';
const _kOnboardingReviewPromptShownKey = 'onboarding_review_prompt_shown';
const _kTotalSteps = 3;

Future<void> _maybeShowOnboardingReviewPrompt(
  WidgetRef ref, {
  required bool fromSettings,
}) async {
  if (fromSettings) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final hasPrompted = prefs.getBool(_kOnboardingReviewPromptShownKey) ?? false;
  if (hasPrompted) return;

  final inAppReview = InAppReview.instance;
  final isAvailable = await inAppReview.isAvailable();
  if (!isAvailable) return;

  await prefs.setBool(_kOnboardingReviewPromptShownKey, true);
  try {
    await inAppReview.requestReview();
  } catch (_) {}
}

String _postAuthPageId(int stepIndex) {
  switch (stepIndex) {
    case 0:
      return 'post_auth_log_expense';
    case 1:
      return 'post_auth_import';
    case 2:
      return 'post_auth_notifications';
    default:
      return 'post_auth_unknown';
  }
}

String _postAuthStepKey(int stepIndex) {
  switch (stepIndex) {
    case 0:
      return 'log_expense';
    case 1:
      return 'import';
    case 2:
      return 'notifications';
    default:
      return 'unknown';
  }
}

class OnboardingPostAuthFlowPage extends HookConsumerWidget {
  const OnboardingPostAuthFlowPage({
    super.key,
    this.fromSettings = false,
  });

  final bool fromSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    final notificationFlowStarted = useState(false);
    final notificationFlowCompleted = useState(false);
    final selectedImportApp = useState<String>('YNAB');
    final selectedExpenseSource = useState(_ExpenseCaptureSource.textAudio);
    final loggedExpensePreview =
        useState<OnboardingLoggedExpensePreview?>(null);
    final isPrimaryBusy = useState(false);
    final analytics = ref.read(onboardingFlowAnalyticsServiceProvider);

    useEffect(() {
      unawaited(
        analytics.beginPage(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(currentPage.value),
          stepIndex: currentPage.value,
          enableTracking: !fromSettings,
          properties: <String, Object?>{
            'from_settings': fromSettings,
            'step_group': 'post_auth',
            'step_key': _postAuthStepKey(currentPage.value),
          },
        ),
      );
      return null;
    }, [currentPage.value, fromSettings]);

    useEffect(() {
      unawaited(
          _maybeShowOnboardingReviewPrompt(ref, fromSettings: fromSettings));
      return null;
    }, [fromSettings]);

    void goToPage(int targetPage) {
      if (!context.mounted) return;
      void go() {
        unawaited(
          pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        );
      }

      if (pageController.hasClients) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || !pageController.hasClients) return;
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
      if (currentPage.value < _kTotalSteps - 1) {
        goToPage(currentPage.value + 1);
      } else {
        unawaited(showFinishPage());
      }
    }

    void skip() {
      unawaited(
        analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(currentPage.value),
          stepIndex: currentPage.value,
          actionId: '${_postAuthStepKey(currentPage.value)}_skipped',
          result: 'skipped',
          enableTracking: !fromSettings,
          properties: <String, Object?>{
            'step_group': 'post_auth',
            'step_key': _postAuthStepKey(currentPage.value),
          },
        ),
      );
      if (currentPage.value == _kTotalSteps - 1) {
        unawaited(showFinishPage());
        return;
      }
      next();
    }

    Future<void> handleNotificationsFlow() async {
      if (!context.mounted) return;
      if (notificationFlowStarted.value || notificationFlowCompleted.value) {
        if (notificationFlowCompleted.value) {
          await showFinishPage();
        }
        return;
      }

      notificationFlowStarted.value = true;
      final uid = ref.read(authProvider).uid;
      try {
        await ref.read(onboardingPostAuthNotificationsActionProvider)(ref, uid);

        if (!context.mounted) return;

        notificationFlowCompleted.value = true;
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(2),
          stepIndex: 2,
          actionId: 'notifications_enabled',
          result: 'used',
          enableTracking: !fromSettings,
          properties: const <String, Object?>{
            'step_group': 'post_auth',
            'step_key': 'notifications',
          },
        );
        await showFinishPage();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> handleLogExpense() async {
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _postAuthPageId(0),
        stepIndex: 0,
        actionId: 'log_expense_started',
        result: 'used',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'post_auth',
          'step_key': 'log_expense',
          'capture_source': selectedExpenseSource.value.name,
        },
      );
      final preview =
          await ref.read(onboardingPostAuthLogExpenseActionProvider)(
        context,
        ref,
        selectedExpenseSource.value.getLabel(context),
      );
      if (!context.mounted) return;
      if (preview != null) {
        loggedExpensePreview.value = preview;
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(0),
          stepIndex: 0,
          actionId: 'log_expense_completed',
          result: 'success',
          enableTracking: !fromSettings,
          properties: <String, Object?>{
            'step_group': 'post_auth',
            'step_key': 'log_expense',
            'capture_source': selectedExpenseSource.value.name,
            'item_count': preview.items.length,
          },
        );
        await _showLoggedExpenseResultSheet(context, preview);
        return;
      }
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _postAuthPageId(0),
        stepIndex: 0,
        actionId: 'log_expense_cancelled',
        result: 'cancelled',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'post_auth',
          'step_key': 'log_expense',
          'capture_source': selectedExpenseSource.value.name,
        },
      );
    }

    Future<void> handleImportExpenses() async {
      final notUsingAnApp = context.l10n.notUsingAnApp;
      if (selectedImportApp.value == notUsingAnApp) {
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(1),
          stepIndex: 1,
          actionId: 'import_skipped',
          result: 'skipped',
          enableTracking: !fromSettings,
          properties: const <String, Object?>{
            'step_group': 'post_auth',
            'step_key': 'import',
          },
        );
        next();
        return;
      }

      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _postAuthPageId(1),
        stepIndex: 1,
        actionId: 'import_started',
        result: 'used',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'post_auth',
          'step_key': 'import',
          'selected_import_app': selectedImportApp.value,
        },
      );

      ref.read(importWizardProvider.notifier).resetAfterImport();
      final imported = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ImportWizardPage(
            lockPersonalTarget: true,
            sourceApp: _mapImportSourceApp(selectedImportApp.value),
          ),
        ),
      );

      if (!context.mounted) return;
      if (imported == true) {
        await analytics.trackAction(
          flowName: 'onboarding_funnel',
          pageId: _postAuthPageId(1),
          stepIndex: 1,
          actionId: 'import_completed',
          result: 'success',
          enableTracking: !fromSettings,
          properties: <String, Object?>{
            'step_group': 'post_auth',
            'step_key': 'import',
            'selected_import_app': selectedImportApp.value,
          },
        );
        next();
        return;
      }
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _postAuthPageId(1),
        stepIndex: 1,
        actionId: 'import_cancelled',
        result: 'cancelled',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'post_auth',
          'step_key': 'import',
          'selected_import_app': selectedImportApp.value,
        },
      );
    }

    Future<void> primary() async {
      if (isPrimaryBusy.value) return;
      isPrimaryBusy.value = true;
      try {
        switch (currentPage.value) {
          case 0:
            if (loggedExpensePreview.value != null) {
              next();
            } else {
              await handleLogExpense();
            }
            return;
          case 1:
            await handleImportExpenses();
            return;
          case 2:
            await handleNotificationsFlow();
            return;
          default:
            next();
        }
      } finally {
        if (context.mounted) {
          isPrimaryBusy.value = false;
        }
      }
    }

    Future<void> handleSourceSelection(_ExpenseCaptureSource value) async {
      if (isPrimaryBusy.value) return;
      selectedExpenseSource.value = value;
      await analytics.trackAction(
        flowName: 'onboarding_funnel',
        pageId: _postAuthPageId(0),
        stepIndex: 0,
        actionId: 'expense_source_selected',
        result: 'used',
        enableTracking: !fromSettings,
        properties: <String, Object?>{
          'step_group': 'post_auth',
          'step_key': 'log_expense',
          'capture_source': value.name,
        },
      );
      await primary();
    }

    final primaryLabel = switch (currentPage.value) {
      0 => loggedExpensePreview.value == null
          ? context.l10n.addExpense
          : context.l10n.continueAction,
      1 => selectedImportApp.value == context.l10n.notUsingAnApp
          ? context.l10n.continueAction
          : context.l10n.importExpenses,
      2 => context.l10n.turnOnNotifications,
      _ => context.l10n.continueAction,
    };

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    _LogExpenseStep(
                      selectedSource: selectedExpenseSource.value,
                      onSourceChanged: (value) =>
                          unawaited(handleSourceSelection(value)),
                      loggedExpensePreview: loggedExpensePreview.value,
                      onViewResult: loggedExpensePreview.value == null
                          ? null
                          : () => unawaited(
                                _showLoggedExpenseResultSheet(
                                  context,
                                  loggedExpensePreview.value!,
                                ),
                              ),
                    ),
                    _ImportExpensesStep(
                      selectedApp: selectedImportApp.value,
                      onAppChanged: (value) {
                        selectedImportApp.value = value;
                        unawaited(
                          analytics.trackAction(
                            flowName: 'onboarding_funnel',
                            pageId: _postAuthPageId(1),
                            stepIndex: 1,
                            actionId: 'import_app_selected',
                            result: 'used',
                            enableTracking: !fromSettings,
                            properties: <String, Object?>{
                              'step_group': 'post_auth',
                              'step_key': 'import',
                              'selected_import_app': value,
                            },
                          ),
                        );
                      },
                    ),
                    const _NotificationsStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_kTotalSteps, (i) {
                        final active = currentPage.value == i;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 18 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? colorScheme.primary
                                : colorScheme.mutedForeground
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: PrimaryAdaptiveButton(
                        onPressed: isPrimaryBusy.value
                            ? null
                            : () => unawaited(primary()),
                        child: isPrimaryBusy.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(primaryLabel),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlainAdaptiveButton(
                      onPressed: skip,
                      child: Text(
                        context.l10n.onboardingPostAuthSkipLater,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
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
      return;
    }
    await analytics.trackAction(
      flowName: 'onboarding_funnel',
      pageId: _postAuthPageId(_kTotalSteps - 1),
      stepIndex: _kTotalSteps - 1,
      actionId: 'post_auth_completed',
      result: 'success',
      properties: const <String, Object?>{
        'step_group': 'post_auth',
        'step_key': 'notifications',
        'next_route': '/dashboard',
      },
    );
    await analytics.endPage(
      reason: 'post_auth_completed',
      transitionTo: 'dashboard',
    );
    context.go('/dashboard');
  }
}

ImportSourceApp _mapImportSourceApp(String app) {
  return switch (app) {
    'YNAB' => ImportSourceApp.ynab,
    'Monarch' => ImportSourceApp.monarch,
    'Copilot' => ImportSourceApp.copilot,
    'PocketGuard' => ImportSourceApp.pocketGuard,
    'Splitwise' => ImportSourceApp.splitwise,
    _ => ImportSourceApp.other,
  };
}

enum _ExpenseCaptureSource {
  textAudio('Audio / Text', Icons.graphic_eq_rounded),
  takePhoto('Take photo', Icons.camera_alt_outlined);

  const _ExpenseCaptureSource(this.labelKey, this.icon);

  final String labelKey;
  final IconData icon;

  String getLabel(BuildContext context) {
    return switch (labelKey) {
      'Audio / Text' => context.l10n.onboardingPostAuthSourceAudioText,
      'Take photo' => context.l10n.onboardingPostAuthSourceTakePhoto,
      _ => labelKey,
    };
  }
}

Future<void> _showLoggedExpenseResultSheet(
  BuildContext context,
  OnboardingLoggedExpensePreview preview,
) {
  final colorScheme = Theme.of(context).colorScheme;

  // Calculate total amount if there are multiple items
  final totalAmount = preview.items.isNotEmpty
      ? preview.items.fold<double>(0, (sum, item) => sum + item.amount)
      : preview.amount;

  final totalAmountLabel =
      '${resolveCurrencySymbol(preview.currency)}${NumberFormat('#,##0.00').format(totalAmount)}';

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: colorScheme.sheetBackground,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.onboardingPostAuthExpenseCaptured,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview.items.length > 1
                              ? context.l10n
                                  .onboardingPostAuthExpenseExtractedMultiple(
                                      preview.items.length)
                              : context.l10n
                                  .onboardingPostAuthExpenseExtractedSingle,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.mutedForeground,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (preview.items.length <= 1) ...[
                // Single item view (Original detailed design)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.analysisResult,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ExtractedDetailRow(
                        label: context.l10n.amount,
                        value: totalAmountLabel,
                        isHighlight: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(
                          height: 1,
                          color: colorScheme.border.withValues(alpha: 0.3),
                        ),
                      ),
                      _ExtractedDetailRow(
                        label: context.l10n.category,
                        value: _capitalize(preview.category),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(
                          height: 1,
                          color: colorScheme.border.withValues(alpha: 0.3),
                        ),
                      ),
                      _ExtractedDetailRow(
                        label: context.l10n.description,
                        value: preview.description,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(
                          height: 1,
                          color: colorScheme.border.withValues(alpha: 0.3),
                        ),
                      ),
                      _ExtractedDetailRow(
                        label: context.l10n.inputSource,
                        value: preview.sourceLabel,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Multiple items view
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n
                                    .onboardingPostAuthAiExtractionCount(
                                        preview.items.length),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            totalAmountLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: colorScheme.border.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: preview.items.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(
                              height: 1,
                              color: colorScheme.border.withValues(alpha: 0.2),
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final item = preview.items[index];
                            final itemAmount =
                                '${item.currencySymbol}${NumberFormat('#,##0.00').format(item.amount)}';
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.description ??
                                            context.l10n.unknown,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _capitalize(item.category),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  itemAmount,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: PrimaryAdaptiveButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.looksGood),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _ExtractedDetailRow extends StatelessWidget {
  const _ExtractedDetailRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.only(top: isHighlight ? 4 : 0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 22 : 15,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogExpenseStep extends StatelessWidget {
  const _LogExpenseStep({
    required this.selectedSource,
    required this.onSourceChanged,
    required this.loggedExpensePreview,
    required this.onViewResult,
  });

  final _ExpenseCaptureSource selectedSource;
  final ValueChanged<_ExpenseCaptureSource> onSourceChanged;
  final OnboardingLoggedExpensePreview? loggedExpensePreview;
  final VoidCallback? onViewResult;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // We render the main view normally. The bottom sheet is shown via handleLogExpense.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
            child: Text(
              context.l10n.onboardingPostAuthLogExpenseTitle,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Text(
              context.l10n.onboardingPostAuthLogExpenseSubtitle,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 36),
          SvgPicture.asset(
            'lib/assets/images/onboarding/onboarding1.svg',
            height: 180,
          ),
          const SizedBox(height: 28),
          if (loggedExpensePreview == null) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: _ExpenseCaptureSource.values.map((source) {
                return _SourceOptionTile(
                  label: source.getLabel(context),
                  icon: source.icon,
                  selected: source == selectedSource,
                  onTap: () => onSourceChanged(source),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 20),
          ],
          // Also show the inline summary so users can see the result if they close the sheet
          if (loggedExpensePreview != null)
            _LoggedExpenseInlineSummary(
              preview: loggedExpensePreview!,
              onViewResult: onViewResult,
            ),
        ],
      ),
    );
  }
}

class _LoggedExpenseInlineSummary extends StatelessWidget {
  const _LoggedExpenseInlineSummary({
    required this.preview,
    required this.onViewResult,
  });

  final OnboardingLoggedExpensePreview preview;
  final VoidCallback? onViewResult;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final totalAmount = preview.items.isNotEmpty
        ? preview.items.fold<double>(0, (sum, item) => sum + item.amount)
        : preview.amount;

    final amountLabel =
        '${resolveCurrencySymbol(preview.currency)}${NumberFormat('#,##0.00').format(totalAmount)}';

    final itemCount = preview.items.length;
    final subtitleText = itemCount > 1
        ? context.l10n.onboardingPostAuthExpenseExtractedMultiple(itemCount)
        : preview.description;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.success.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.success.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: colorScheme.success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.onboardingPostAuthExpenseLoggedInline,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amountLabel,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryAdaptiveButton(
              onPressed: onViewResult,
              child: Text(context.l10n.onboardingPostAuthViewExtractionDetails),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportExpensesStep extends StatelessWidget {
  const _ImportExpensesStep({
    required this.selectedApp,
    required this.onAppChanged,
  });

  final String selectedApp;
  final ValueChanged<String> onAppChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
            child: Text(
              context.l10n.onboardingPostAuthImportTitle,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SvgPicture.asset(
            'lib/assets/images/onboarding/onboarding5.svg',
            height: 180,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  context.l10n.onboardingPostAuthImportQuestion,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: colorScheme.surface.withValues(alpha: 0.0),
                  child: InkWell(
                    onTap: () {
                      MonekoActionSheet.show<String>(
                        context: context,
                        title: context.l10n.selectApp,
                        actions: _kImportApps(context)
                            .map(
                              (app) => MonekoActionSheetAction(
                                label: app,
                                value: app,
                              ),
                            )
                            .toList(growable: false),
                      ).then((app) {
                        if (app != null) {
                          onAppChanged(app);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.appBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedApp,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: colorScheme.foreground,
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

class _NotificationsStep extends StatelessWidget {
  const _NotificationsStep();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
            child: Text(
              context.l10n.onboardingPostAuthNotificationsTitle,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SvgPicture.asset(
            'lib/assets/images/onboarding/onboarding3.svg',
            height: 180,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.08),
                width: 1,
              ),
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
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.onboardingPostAuthNotificationExampleTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context
                            .l10n.onboardingPostAuthNotificationExampleSubtitle,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
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

class _SourceOptionTile extends StatelessWidget {
  const _SourceOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.18)
                : colorScheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.border.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: colorScheme.foreground),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _kImportApps(BuildContext context) => <String>[
      'YNAB',
      'Monarch',
      'Copilot',
      'PocketGuard',
      'Splitwise',
      context.l10n.other,
      context.l10n.notUsingAnApp,
    ];
