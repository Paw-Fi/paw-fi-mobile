import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_bottom_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/presentation/pages/android_notification_capture_page.dart';
import 'package:moneko/features/profile/presentation/pages/ios_wallet_capture_page.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';

final walletCaptureEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authProvider);
  if (user.isEmpty) return false;

  try {
    final response = await Supabase.instance.client
        .from('user_contacts')
        .select('wallet_capture_enabled')
        .eq('user_id', user.uid)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return (response?['wallet_capture_enabled'] as bool?) ?? false;
  } catch (error) {
    debugPrint('Error checking wallet capture state: $error');
    return false;
  }
});

const double _bannerCardWidth = 195;
const double _bannerCardHeight = 185;
const String dismissedChecklistStepsStorageKey =
    'home_connect_social_dismissed_steps_v1';

final dismissedChecklistStepsProvider = Provider<Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final stored =
      prefs.getStringList(dismissedChecklistStepsStorageKey) ?? const [];
  return stored.toSet();
});

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message) {
  if (kDebugMode && _enableDebugLogs) {
    debugPrint(message);
  }
}

class ConnectSocialBanner extends ConsumerWidget {
  const ConnectSocialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(previewModeProvider).isActive) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final hasTransactionsAsync =
        ref.watch(dashboardHasLoggedTransactionsProvider);
    final whatsappAsync = ref.watch(whatsAppBindingProvider);
    final telegramAsync = ref.watch(telegramBindingProvider);
    final walletCaptureAsync = ref.watch(walletCaptureEnabledProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final dismissedStepIds = ref.watch(dismissedChecklistStepsProvider);

    final recurringHouseholdId = switch (householdScope.activeAccountType) {
      ActiveWalletType.personal => null,
      ActiveWalletType.portfolio => householdScope.activeAccountHouseholdId,
      ActiveWalletType.household => householdScope.selectedHouseholdId,
    };

    final recurringState =
        ref.watch(recurringTransactionsProvider(recurringHouseholdId));
    final recurringExpensesAsync =
        ref.watch(recurringExpensesProvider(recurringHouseholdId));

    final shouldTriggerPreviewLoad = ref.watch(previewModeProvider).isActive &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading;

    if ((authState.uid.isNotEmpty || shouldTriggerPreviewLoad) &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(recurringHouseholdId).notifier)
            .loadRecurringTransactions(
              authState.uid.isNotEmpty
                  ? authState.uid
                  : PreviewMockData.contact.userId ?? 'preview-user',
            );
      });
    }

    final isBannerReady = !hasTransactionsAsync.isLoading &&
        !whatsappAsync.isLoading &&
        !telegramAsync.isLoading &&
        !walletCaptureAsync.isLoading &&
        recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading;

    if (!isBannerReady) {
      _debugPrint(
        '[ConnectSocialBanner] waiting hasTransactionsLoading=${hasTransactionsAsync.isLoading} '
        'whatsappLoading=${whatsappAsync.isLoading} '
        'telegramLoading=${telegramAsync.isLoading} '
        'walletLoading=${walletCaptureAsync.isLoading} '
        'recurringLoaded=${recurringState.hasLoadedOnce} '
        'recurringLoading=${recurringState.data.isLoading}',
      );
      return const SizedBox.shrink();
    }

    final whatsappConnected = whatsappAsync.valueOrNull ?? false;
    final telegramConnected = telegramAsync.valueOrNull ?? false;
    final messagingConnected = whatsappConnected || telegramConnected;
    final walletCaptureEnabled = walletCaptureAsync.valueOrNull ?? false;

    final steps = _buildSteps(
      context: context,
      authState: authState,
      hasTransactionLogged: hasTransactionsAsync.valueOrNull ?? false,
      recurringExpensesAsync: recurringExpensesAsync,
      messagingConnected: messagingConnected,
      walletCaptureEnabled: walletCaptureEnabled,
      onCreateAccount: () => _openRegister(context),
      onLogExpense: () => handleAiFreeFormText(context, ref),
      onRecurringExpense: () => showAddRecurringSheet(
        context,
        type: 'expense',
      ),
      onConnectMessaging: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
        builder: (context) => const ConnectSocialBottomSheet(),
      ),
      onEnableCapture: () => _openCaptureFlow(context, ref),
    );

    _debugPrint(
      '[ConnectSocialBanner] scope=$recurringHouseholdId '
      'loaded=${recurringState.hasLoadedOnce} '
      'loading=${recurringState.data.isLoading} '
      'stateCount=${recurringState.data.valueOrNull?.length ?? 0} '
      'expensesCount=${recurringExpensesAsync.valueOrNull?.length ?? 0} '
      'error=${recurringState.data.hasError}',
    );

    final visibleSteps = steps
        .where((step) => !dismissedStepIds.contains(step.id))
        .toList(growable: false);

    final incompleteCount =
        visibleSteps.where((step) => !step.completed).length;
    if (visibleSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    if (incompleteCount == 0) {
      return const SizedBox.shrink();
    }

    final orderedSteps = [...visibleSteps]..sort((a, b) {
        final completionOrder = a.completed == b.completed
            ? 0
            : a.completed
                ? 1
                : -1;
        if (completionOrder != 0) return completionOrder;
        return a.sortOrder.compareTo(b.sortOrder);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.setupChecklist,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Text(
                context.l10n.leftToDo(incompleteCount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _bannerCardHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final entry in orderedSteps.asMap().entries) ...[
                    SizedBox(
                      width: _bannerCardWidth,
                      height: _bannerCardHeight,
                      child: _ChecklistStepCard(
                        key: ValueKey('connect-social-card-${entry.value.id}'),
                        step: entry.value,
                        colorScheme: colorScheme,
                        onDismiss: () => _dismissStep(ref, entry.value.id),
                      ),
                    ),
                    if (entry.key < orderedSteps.length - 1)
                      const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  void _openCaptureFlow(BuildContext context, WidgetRef ref) {
    final target = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? const IosWalletCapturePage()
        : const AndroidNotificationCapturePage();

    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(builder: (_) => target),
    )
        .then((_) {
      ref.invalidate(walletCaptureEnabledProvider);
    });
  }

  Future<void> _dismissStep(WidgetRef ref, String stepId) async {
    final prefs = ref.read(sharedPreferencesProvider);

    try {
      final dismissed =
          prefs.getStringList(dismissedChecklistStepsStorageKey)?.toSet() ??
              <String>{};
      if (!dismissed.add(stepId)) {
        return;
      }

      final persisted = dismissed.toList()..sort();
      await prefs.setStringList(dismissedChecklistStepsStorageKey, persisted);
      ref.invalidate(dismissedChecklistStepsProvider);
    } catch (error) {
      debugPrint('Failed to dismiss checklist card: $error');
    }
  }

  List<_ChecklistStep> _buildSteps({
    required BuildContext context,
    required AppUser authState,
    required bool hasTransactionLogged,
    required AsyncValue<List<RecurringTransaction>> recurringExpensesAsync,
    required bool messagingConnected,
    required bool walletCaptureEnabled,
    required VoidCallback onCreateAccount,
    required VoidCallback onLogExpense,
    required VoidCallback onRecurringExpense,
    required VoidCallback onConnectMessaging,
    required VoidCallback onEnableCapture,
  }) {
    final hasRecurringExpense = recurringExpensesAsync.maybeWhen(
      data: (transactions) => transactions.isNotEmpty,
      orElse: () => false,
    );
    final createAccountCompleted = authState.uid.isNotEmpty;
    final captureTitle = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? context.l10n.applePayIntegration
        : context.l10n.autoCapture;

    return [
      _ChecklistStep(
        id: 'create_account',
        sortOrder: 0,
        title: context.l10n.createAccount,
        description: context.l10n.createAccountDescription,
        buttonLabel: context.l10n.getStarted,
        completed: createAccountCompleted,
        icon: Icons.person_add_alt_1_rounded,
        onTap: createAccountCompleted ? null : onCreateAccount,
      ),
      _ChecklistStep(
        id: 'log_expense',
        sortOrder: 1,
        title: context.l10n.logExpense,
        description: context.l10n.logExpenseDescription,
        buttonLabel: context.l10n.logNow,
        completed: hasTransactionLogged,
        icon: Icons.receipt_long_rounded,
        onTap: hasTransactionLogged ? null : onLogExpense,
      ),
      _ChecklistStep(
        id: 'set_recurring',
        sortOrder: 2,
        title: context.l10n.setRecurring,
        description: context.l10n.setRecurringDescription,
        buttonLabel: context.l10n.setUp,
        completed: hasRecurringExpense,
        icon: Icons.repeat_rounded,
        onTap: hasRecurringExpense ? null : onRecurringExpense,
      ),
      _ChecklistStep(
        id: 'connect_chat',
        sortOrder: 3,
        title: context.l10n.connectChat,
        description: context.l10n.connectChatDescription,
        buttonLabel: context.l10n.connect,
        completed: messagingConnected,
        icon: Icons.chat_bubble_outline_rounded,
        onTap: messagingConnected ? null : onConnectMessaging,
      ),
      _ChecklistStep(
        id: 'enable_capture',
        sortOrder: 4,
        title: captureTitle,
        description: Platform.isIOS
            ? context.l10n.autoCaptureDescriptionIos
            : context.l10n.autoCaptureDescriptionAndroid,
        buttonLabel: context.l10n.enable,
        completed: walletCaptureEnabled,
        icon: defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS
            ? Icons.account_balance_wallet_outlined
            : Icons.notifications_active_outlined,
        onTap: walletCaptureEnabled ? null : onEnableCapture,
      ),
    ];
  }
}

class _ChecklistStep {
  const _ChecklistStep({
    required this.id,
    required this.sortOrder,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.completed,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final int sortOrder;
  final String title;
  final String description;
  final String buttonLabel;
  final bool completed;
  final IconData icon;
  final VoidCallback? onTap;
}

class _ChecklistStepCard extends StatelessWidget {
  const _ChecklistStepCard({
    super.key,
    required this.step,
    required this.colorScheme,
    required this.onDismiss,
  });

  final _ChecklistStep step;
  final ColorScheme colorScheme;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.homeCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: step.completed
                        ? colorScheme.surface.withValues(alpha: 0.5)
                        : colorScheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: step.completed
                            ? colorScheme.border.withValues(alpha: 0.5)
                            : colorScheme.border,
                        width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    step.completed ? Icons.check_rounded : step.icon,
                    size: 22,
                    color: step.completed
                        ? colorScheme.mutedForeground
                        : colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: step.completed
                        ? colorScheme.mutedForeground
                        : colorScheme.foreground,
                    height: 1.08,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  step.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.mutedForeground,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: step.completed
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    colorScheme.border.withValues(alpha: 0.5),
                                width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor:
                                colorScheme.surface.withValues(alpha: 0.5),
                          ),
                          child: Text(
                            context.l10n.done,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            step.onTap?.call();
                            HapticFeedback.lightImpact();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.primaryForeground,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: Text(
                            step.buttonLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () {
                onDismiss();
                HapticFeedback.selectionClick();
              },
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: colorScheme.mutedForeground,
              ),
              splashRadius: 16,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            ),
          ),
        ],
      ),
    );
  }
}
