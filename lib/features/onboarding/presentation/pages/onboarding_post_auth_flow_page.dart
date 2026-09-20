import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_actions.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/trial_welcome_dialog.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:';
const _kOnboardingReviewPromptShownKey = 'onboarding_review_prompt_shown';
const _kTotalSteps = 4;
const _kSubscriptionRefreshTimeout = Duration(seconds: 10);
const _kTrialGrantTimeout = Duration(seconds: 20);

Future<void> _maybeShowOnboardingReviewPrompt(
  WidgetRef ref, {
  required bool fromSettings,
}) async {
  if (fromSettings) {
    return;
  }

  final prefs = ref.read(sharedPreferencesProvider);
  final hasPrompted = prefs.getBool(_kOnboardingReviewPromptShownKey) ?? false;
  if (hasPrompted) {
    return;
  }

  final inAppReview = InAppReview.instance;
  final isAvailable = await inAppReview.isAvailable();
  if (!isAvailable) {
    return;
  }

  await prefs.setBool(_kOnboardingReviewPromptShownKey, true);

  try {
    await inAppReview.requestReview();
  } catch (_) {}
}

Future<bool?> _hasSubscriptionRow(String userId) async {
  try {
    final row = await supabase
        .from('subscriptions')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    return row != null;
  } catch (error, stackTrace) {
    debugPrint(
      '[OnboardingPostAuth] Subscription row check failed: $error\n$stackTrace',
    );
    return null;
  }
}

Future<bool> _ensurePostAuthTrial(ProviderContainer container) async {
  final userId = container.read(authProvider).uid;
  if (userId.isEmpty) return false;

  try {
    await container
        .read(subscriptionManagementProvider.notifier)
        .refresh()
        .timeout(_kSubscriptionRefreshTimeout, onTimeout: () {
      debugPrint(
        '[OnboardingPostAuth] subscriptionManagement refresh timed out after $_kSubscriptionRefreshTimeout',
      );
    });
    await container
        .read(subscriptionNotifierProvider.notifier)
        .refresh()
        .timeout(_kSubscriptionRefreshTimeout, onTimeout: () {
      debugPrint(
        '[OnboardingPostAuth] subscriptionNotifier refresh timed out after $_kSubscriptionRefreshTimeout',
      );
    });

    final subscriptionDetails =
        container.read(subscriptionManagementProvider).valueOrNull;
    if (subscriptionDetails?.hasActiveSubscription ?? false) {
      return true;
    }

    final hasSubscription = await _hasSubscriptionRow(userId);
    if (hasSubscription == true) return true;
    if (hasSubscription == null) return false;

    debugPrint(
      '[OnboardingPostAuth] No subscription detected; retrying onboarding free trial activation',
    );
    await container
        .read(subscriptionManagementProvider.notifier)
        .grantPaywallReturnTrial()
        .timeout(_kTrialGrantTimeout);
    await container
        .read(subscriptionManagementProvider.notifier)
        .refresh()
        .timeout(_kSubscriptionRefreshTimeout);
    await container
        .read(subscriptionNotifierProvider.notifier)
        .refresh()
        .timeout(_kSubscriptionRefreshTimeout);

    final granted = await _hasSubscriptionRow(userId) == true;
    if (granted) {
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setBool(trialWelcomePendingKey(userId), true);
    }
    return granted;
  } catch (error, stackTrace) {
    debugPrint(
      '[OnboardingPostAuth] Free trial activation failed: $error\n$stackTrace',
    );
    return await _hasSubscriptionRow(userId) == true;
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
    final recordedImportApp = useState<String?>(null);
    final selectedExpenseSource = useState(_ExpenseCaptureSource.textAudio);
    final loggedExpensePreview =
        useState<OnboardingLoggedExpensePreview?>(null);
    final isPrimaryBusy = useState(false);
    final hasShownLoggedExpenseResult = useRef(false);

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
        final notificationsAction =
            ref.read(onboardingPostAuthNotificationsActionProvider);
        unawaited(
          notificationsAction(ref, uid).catchError((error, stackTrace) {
            debugPrint(
              '[OnboardingPostAuth] Notification setup failed: $error\n$stackTrace',
            );
          }),
        );
        notificationFlowCompleted.value = true;
        next();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> handleSubscriptionFlow() async {
      await PlusLockedSheet.show(
        context,
        highlightedFeature: PlusFeature.spaceCreation,
      );
      if (!context.mounted) return;

      final subscription =
          ref.read(subscriptionManagementProvider).valueOrNull?.subscription;
      if (subscription?.isSubscribed ?? false) {
        await showFinishPage();
      }
    }

    Future<void> showLoggedExpenseResult(
      OnboardingLoggedExpensePreview preview,
    ) async {
      if (hasShownLoggedExpenseResult.value || !context.mounted) return;
      hasShownLoggedExpenseResult.value = true;
      loggedExpensePreview.value = preview;
      ref.read(onboardingPostAuthLogExpenseSuccessProvider.notifier).state =
          null;
      await _showLoggedExpenseResultSheet(context, preview);
    }

    Future<void> handleLogExpense() async {
      ref.read(onboardingPostAuthLogExpenseSuccessProvider.notifier).state =
          (preview) => unawaited(showLoggedExpenseResult(preview));
      final preview =
          await ref.read(onboardingPostAuthLogExpenseActionProvider)(
        context,
        ref,
        selectedExpenseSource.value.getLabel(context),
      );
      if (!context.mounted) return;
      if (preview != null) {
        await showLoggedExpenseResult(preview);
        return;
      }
    }

    Future<void> handleImportExpenses() async {
      final notUsingAnApp = context.l10n.notUsingAnApp;
      final appName = selectedImportApp.value;
      if (recordedImportApp.value != appName) {
        try {
          await supabase.from('onboarding_heard_about_responses').insert({
            'source': 'budgeting_app_import',
            'source_label': appName,
            'other_text': null,
          });
          recordedImportApp.value = appName;
        } catch (error, stackTrace) {
          debugPrint(
            '[OnboardingPostAuth] Import app selection tracking failed: $error\n$stackTrace',
          );
        }
      }

      if (selectedImportApp.value == notUsingAnApp) {
        next();
        return;
      }

      if (!context.mounted) return;
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
        next();
        return;
      }
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
          case 3:
            await handleSubscriptionFlow();
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
      3 => context.l10n.viewPlans,
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
                      },
                    ),
                    const _NotificationsStep(),
                    const _SubscriptionStep(),
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
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await _markOnboardingCompleted(ref);
    } catch (error, stackTrace) {
      debugPrint(
        '[OnboardingPostAuth] Completion failed: $error\n$stackTrace',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.onboardingPreparingBodyErrorRetry)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/dashboard');
    unawaited(_ensurePostAuthTrial(container).then((granted) {
      if (!granted) {
        debugPrint(
          '[OnboardingPostAuth] Trial setup did not complete; subscription state will retry through normal app refreshes',
        );
      }
    }));
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

const _kMonekoSaveGif = 'lib/assets/gifs/moneko-save-smooth-v2.gif';

String? _merchantLabelOf(ParsedExpense? item) {
  if (item == null) return null;
  final raw = item.merchant?.trim();
  if (raw != null && raw.isNotEmpty) return raw;
  final structured = item.merchantStructuredName?.trim();
  if (structured != null && structured.isNotEmpty) return structured;
  return null;
}

Future<void> _showLoggedExpenseResultSheet(
  BuildContext context,
  OnboardingLoggedExpensePreview preview,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  final localeName = Localizations.localeOf(context).toString();
  final items = preview.items;
  final firstItem = items.isEmpty ? null : items.first;

  // Calculate total amount if there are multiple items
  final totalAmount = items.isNotEmpty
      ? items.fold<double>(0, (sum, item) => sum + item.amount)
      : preview.amount;

  final totalAmountLabel =
      '${resolveCurrencySymbol(preview.currency)}${NumberFormat('#,##0.00').format(totalAmount)}';

  final merchantName = _merchantLabelOf(firstItem);
  final subtitle = items.length > 1
      ? l10n.onboardingPostAuthExpenseExtractedMultiple(items.length)
      : (merchantName ?? preview.description);
  final descriptionText = preview.description.trim();
  final showDescriptionRow = descriptionText.isNotEmpty &&
      descriptionText != subtitle &&
      descriptionText != preview.sourceLabel;

  unawaited(HapticFeedback.mediumImpact());

  return MonekoBottomSheet.show<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final detailRows = <Widget>[
        if (merchantName != null && firstItem != null)
          _ResultDetailRow(
            leading: _MerchantLogoBadge(
              item: firstItem,
              fallbackIcon: Icons.storefront_outlined,
              fallbackColor: colorScheme.mutedForeground,
            ),
            label: l10n.merchant,
            value: merchantName,
          ),
        _ResultDetailRow(
          leading: _CategoryIconBadge(
            category: firstItem?.category ?? preview.category,
          ),
          label: l10n.category,
          value: _capitalize(firstItem?.category ?? preview.category),
        ),
        if (firstItem != null)
          _ResultDetailRow(
            leading: const _ResultIconBadge(
              icon: Icons.calendar_today_rounded,
            ),
            label: l10n.date,
            value: DateFormat.yMMMd(localeName).format(firstItem.date),
          ),
        if (showDescriptionRow)
          _ResultDetailRow(
            leading: const _ResultIconBadge(icon: Icons.notes_rounded),
            label: l10n.description,
            value: descriptionText,
          ),
      ];

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetReveal(
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.10),
                              colorScheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      Image.asset(
                        _kMonekoSaveGif,
                        height: 150,
                        semanticLabel: 'Moneko mascot',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _SheetReveal(
                delay: const Duration(milliseconds: 90),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.onboardingPostAuthExpenseCaptured,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      totalAmountLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        letterSpacing: -1.4,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: _SheetReveal(
                  delay: const Duration(milliseconds: 180),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.sheetElementBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.35),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(sheetContext).size.height * 0.34,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount:
                            items.length > 1 ? items.length : detailRows.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 64,
                          endIndent: 16,
                          color: colorScheme.border.withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) => items.length > 1
                            ? _LoggedItemRow(
                                item: items[index],
                                localeName: localeName,
                              )
                            : detailRows[index],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SheetReveal(
                delay: const Duration(milliseconds: 250),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: PrimaryAdaptiveButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.looksGood),
                  ),
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

class _SheetReveal extends StatefulWidget {
  const _SheetReveal({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_SheetReveal> createState() => _SheetRevealState();
}

class _SheetRevealState extends State<_SheetReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class _ResultDetailRow extends StatelessWidget {
  const _ResultDetailRow({
    required this.leading,
    required this.label,
    required this.value,
  });

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultIconBadge extends StatelessWidget {
  const _ResultIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: colorScheme.mutedForeground),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  const _CategoryIconBadge({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final color = getCategoryColor(category, context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(getCategoryIcon(category), size: 19, color: color),
    );
  }
}

class _MerchantLogoBadge extends StatelessWidget {
  const _MerchantLogoBadge({
    required this.item,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final ParsedExpense item;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: MerchantLogo(
        merchantId: item.merchantId,
        domain: item.merchantDomain,
        logoUrl: item.merchantLogoUrl,
        fallback: Center(
          child: Icon(fallbackIcon, size: 19, color: fallbackColor),
        ),
      ),
    );
  }
}

class _LoggedItemRow extends StatelessWidget {
  const _LoggedItemRow({
    required this.item,
    required this.localeName,
  });

  final ParsedExpense item;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedDescription = item.description?.trim() ?? '';
    final title = trimmedDescription.isNotEmpty
        ? trimmedDescription
        : (_merchantLabelOf(item) ?? _capitalize(item.category));
    final subtitle =
        '${_capitalize(item.category)} · ${DateFormat.MMMd(localeName).format(item.date)}';
    final amountLabel =
        '${item.currencySymbol}${NumberFormat('#,##0.00').format(item.amount)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          _MerchantLogoBadge(
            item: item,
            fallbackIcon: getCategoryIcon(item.category),
            fallbackColor: getCategoryColor(item.category, context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amountLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
        ],
      ),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: loggedExpensePreview == null
                ? const SizedBox.shrink(key: ValueKey('no-preview'))
                : _LoggedExpenseInlineSummary(
                    key: const ValueKey('preview'),
                    preview: loggedExpensePreview!,
                    onViewResult: onViewResult,
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoggedExpenseInlineSummary extends StatelessWidget {
  const _LoggedExpenseInlineSummary({
    super.key,
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
          Center(
            child: Image.asset(
              _kMonekoSaveGif,
              height: 92,
              semanticLabel: 'Moneko mascot',
            ),
          ),
          const SizedBox(height: 12),
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

class _SubscriptionStep extends StatelessWidget {
  const _SubscriptionStep();

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
              context.l10n.plusPlan,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              context.l10n.plusLockedDescription,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'lib/assets/images/household/budget-together.png',
              height: 190,
              fit: BoxFit.contain,
              semanticLabel: context.l10n.paywallBenefit0,
            ),
          ),
          const SizedBox(height: 18),
          _SubscriptionBenefitTile(
            icon: Icons.family_restroom_rounded,
            label: context.l10n.paywallBenefit0,
          ),
          const SizedBox(height: 10),
          _SubscriptionBenefitTile(
            icon: Icons.group_work_rounded,
            label: context.l10n.plusLockedSharedBudgets,
          ),
          const SizedBox(height: 10),
          _SubscriptionBenefitTile(
            icon: Icons.account_balance_wallet_rounded,
            label: context.l10n.walletCreation,
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBenefitTile extends StatelessWidget {
  const _SubscriptionBenefitTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: colorScheme.primary,
            size: 20,
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
