import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_actions.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:';
const _kTotalSteps = 3;

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
        await ref.read(onboardingPostAuthNotificationsActionProvider)(ref, uid);

        if (!context.mounted) return;

        notificationFlowCompleted.value = true;
        await showFinishPage();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> handleLogExpense() async {
      final preview =
          await ref.read(onboardingPostAuthLogExpenseActionProvider)(
        context,
        ref,
        selectedExpenseSource.value.label,
      );
      if (!context.mounted) return;
      if (preview != null) {
        loggedExpensePreview.value = preview;
        await _showLoggedExpenseResultSheet(context, preview);
      }
    }

    Future<void> handleImportExpenses() async {
      final importedCount =
          await ref.read(onboardingPostAuthImportExpensesActionProvider)(
        context,
        ref,
        selectedImportApp.value,
      );
      if (importedCount != null && importedCount > 0) {
        next();
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
      0 => loggedExpensePreview.value == null ? 'Add expense' : 'Continue',
      1 => selectedImportApp.value == 'Not using an app'
          ? 'Continue'
          : 'Import expenses',
      2 => 'Turn on notifications',
      _ => 'Continue',
    };

    return AdaptiveScaffold(
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
                        'I\'ll do this later',
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
    );
  }

  Future<void> _markOnboardingCompleted(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final uid = ref.read(authProvider).uid;
    await prefs.setBool('$_kOnboardingCompletedPrefix$uid', true);
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    await _markOnboardingCompleted(ref);
    if (!context.mounted) return;
    if (fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/paywall');
  }
}

enum _ExpenseCaptureSource {
  textAudio('Audio / Text', Icons.graphic_eq_rounded),
  takePhoto('Take photo', Icons.camera_alt_outlined);

  const _ExpenseCaptureSource(this.label, this.icon);

  final String label;
  final IconData icon;
}

Future<void> _showLoggedExpenseResultSheet(
  BuildContext context,
  OnboardingLoggedExpensePreview preview,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final amountLabel =
      '${resolveCurrencySymbol(preview.currency)}${NumberFormat('#,##0.00').format(preview.amount)}';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colorScheme.sheetBackground,
    isScrollControlled: true,
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
              const SizedBox(height: 18),
              Text(
                'Expense logged',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here is the result we captured. Review it, then continue when you are ready.',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.successBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amountLabel,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview.description,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ResultChip(label: preview.sourceLabel),
                        _ResultChip(label: preview.category),
                        _ResultChip(label: preview.currency),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryAdaptiveButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log your first expense',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 36),
          SvgPicture.asset(
            'lib/assets/images/onboarding/onboarding1.svg',
            height: 180,
          ),
          const SizedBox(height: 28),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: _ExpenseCaptureSource.values.map((source) {
              return _SourceOptionTile(
                label: source.label,
                icon: source.icon,
                selected: source == selectedSource,
                onTap: () => onSourceChanged(source),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 20),
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
          Text(
            'Import your expenses\nfrom another app',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
              height: 1.15,
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
                  'Which app are you using now?',
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
                        title: 'Select app',
                        actions: _kImportApps
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
          Text(
            'Get notified before you\noverspend',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
              height: 1.15,
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
                        'New Message',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You\'re close to your spending limit',
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
    final amountLabel =
        '${resolveCurrencySymbol(preview.currency)}${NumberFormat('#,##0.00').format(preview.amount)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.successBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colorScheme.success),
              const SizedBox(width: 8),
              Text(
                'Expense logged',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$amountLabel - ${preview.description}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          PlainAdaptiveButton(
            onPressed: onViewResult,
            child: const Text('View result'),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
        ),
      ),
    );
  }
}

const _kImportApps = <String>[
  'YNAB',
  'Monarch',
  'Copilot',
  'PocketGuard',
  'Splitwise',
  'Other',
  'Not using an app',
];
