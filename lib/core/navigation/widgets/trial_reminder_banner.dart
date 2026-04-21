import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';

String _trialReminderDismissedMilestoneKey({
  required String userId,
  required int trialEndMs,
}) =>
    'trial_reminder_banner_dismissed_milestone:$userId:$trialEndMs';

int? _computeTrialDaysLeft(DateTime? trialEndAt) {
  if (trialEndAt == null) return null;

  final nowUtc = DateTime.now().toUtc();
  final endUtc = trialEndAt.toUtc();
  if (!endUtc.isAfter(nowUtc)) return null;

  final remaining = endUtc.difference(nowUtc);
  return (remaining.inMilliseconds / Duration.millisecondsPerDay).ceil();
}

int? _trialReminderMilestoneForDaysLeft(int? daysLeft) {
  if (daysLeft == null || daysLeft <= 0) return null;
  if (daysLeft <= 1) return 1;
  if (daysLeft <= 3) return 3;
  if (daysLeft <= 7) return 7;
  return null;
}

class TrialReminderBannerGate extends HookConsumerWidget {
  const TrialReminderBannerGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewState = ref.watch(previewModeProvider);
    final auth = ref.watch(authProvider);
    final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
    final subscription = subscriptionAsync.valueOrNull;
    final isSubscriptionResolved =
        subscriptionAsync.hasValue || subscriptionAsync.hasError;
    final subscriptionManagementAsync =
        ref.watch(subscriptionManagementProvider);
    final managedSubscription =
        subscriptionManagementAsync.valueOrNull?.subscription;

    final hasPaidAccessFromPrimary = (subscription?.isSubscribed ?? false) &&
        subscription?.status?.toLowerCase() != 'trialing';
    final hasPaidAccessFromManagement =
        (managedSubscription?.isSubscribed ?? false) &&
            managedSubscription?.status?.toLowerCase() != 'trialing';
    final hasConfirmedPaidAccess =
        hasPaidAccessFromPrimary || hasPaidAccessFromManagement;

    final trialEndsAt = subscription?.status?.toLowerCase() == 'trialing'
        ? subscription?.currentPeriodEnd
        : null;
    final computedTrialDaysLeft = _computeTrialDaysLeft(trialEndsAt);
    final effectiveTrialDaysLeft =
        kDebugMode ? (computedTrialDaysLeft ?? 7) : computedTrialDaysLeft;
    final trialReminderMilestone =
        _trialReminderMilestoneForDaysLeft(effectiveTrialDaysLeft);

    final trialEndMs = trialEndsAt?.toUtc().millisecondsSinceEpoch;
    final trialReminderDismissKey = !kDebugMode &&
            auth.uid.isNotEmpty &&
            trialEndMs != null &&
            trialReminderMilestone != null
        ? _trialReminderDismissedMilestoneKey(
            userId: auth.uid,
            trialEndMs: trialEndMs,
          )
        : null;

    final trialReminderDismissedMilestone = useState<int?>(null);
    final hasResolvedTrialReminderVisibility = useState(false);

    useEffect(() {
      if (kDebugMode) {
        hasResolvedTrialReminderVisibility.value = true;
        return null;
      }

      var disposed = false;
      hasResolvedTrialReminderVisibility.value = false;

      Future<void> resolveTrialReminderVisibility() async {
        if (trialReminderDismissKey == null || trialReminderMilestone == null) {
          if (disposed) return;
          trialReminderDismissedMilestone.value = null;
          hasResolvedTrialReminderVisibility.value = true;
          return;
        }

        final prefs = ref.read(sharedPreferencesProvider);
        final dismissedMilestone = prefs.getInt(trialReminderDismissKey);

        if (disposed) return;
        trialReminderDismissedMilestone.value = dismissedMilestone;
        hasResolvedTrialReminderVisibility.value = true;
      }

      unawaited(resolveTrialReminderVisibility());
      return () {
        disposed = true;
      };
    }, [trialReminderDismissKey, trialReminderMilestone]);

    useEffect(() {
      final lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          if (state != AppLifecycleState.resumed || auth.uid.isEmpty) return;
          unawaited(ref.read(subscriptionNotifierProvider.notifier).refresh());
          unawaited(
              ref.read(subscriptionManagementProvider.notifier).refresh());
        },
      );
      return lifecycle.dispose;
    }, [auth.uid]);

    final shouldShowTrialReminderBanner = !previewState.isActive &&
        isSubscriptionResolved &&
        !hasConfirmedPaidAccess &&
        effectiveTrialDaysLeft != null &&
        trialReminderMilestone != null &&
        hasResolvedTrialReminderVisibility.value &&
        (kDebugMode ||
            trialReminderDismissedMilestone.value == null ||
            trialReminderMilestone < trialReminderDismissedMilestone.value!);

    if (!shouldShowTrialReminderBanner) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _TrialEndingReminderBanner(
        daysLeft: effectiveTrialDaysLeft,
        onManageTap: () {
          unawaited(() async {
            await context.push('/plan-selection?mode=resubscribe');
            if (auth.uid.isEmpty) return;

            Future<void> refreshSubscriptionState() async {
              await ref.read(subscriptionNotifierProvider.notifier).refresh();
              await ref.read(subscriptionManagementProvider.notifier).refresh();
            }

            await refreshSubscriptionState();

            for (var attempt = 0; attempt < 3; attempt++) {
              final primary =
                  ref.read(subscriptionNotifierProvider).valueOrNull;
              final managed = ref
                  .read(subscriptionManagementProvider)
                  .valueOrNull
                  ?.subscription;
              final hasPaidAccessFromPrimary =
                  (primary?.isSubscribed ?? false) &&
                      primary?.status?.toLowerCase() != 'trialing';
              final hasPaidAccessFromManagement =
                  (managed?.isSubscribed ?? false) &&
                      managed?.status?.toLowerCase() != 'trialing';

              if (hasPaidAccessFromPrimary || hasPaidAccessFromManagement) {
                break;
              }

              await Future<void>.delayed(const Duration(milliseconds: 800));
              await refreshSubscriptionState();
            }
          }());
        },
        onDismissTap: () {
          if (kDebugMode) {
            // In debug mode this banner is intentionally always visible.
            return;
          }

          if (trialReminderDismissKey == null) {
            return;
          }

          final dismissedMilestone = trialReminderMilestone;
          trialReminderDismissedMilestone.value = dismissedMilestone;
          unawaited(() async {
            final prefs = ref.read(sharedPreferencesProvider);
            await prefs.setInt(
              trialReminderDismissKey,
              dismissedMilestone,
            );
          }());
        },
      ),
    );
  }
}

class _TrialEndingReminderBanner extends StatelessWidget {
  const _TrialEndingReminderBanner({
    required this.daysLeft,
    required this.onManageTap,
    required this.onDismissTap,
  });

  final int? daysLeft;
  final VoidCallback onManageTap;
  final VoidCallback onDismissTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeDaysLeft = daysLeft == null || daysLeft! <= 0 ? 1 : daysLeft!;
    final daysLeftLabel = safeDaysLeft == 1
        ? context.l10n.dayLeft(safeDaysLeft)
        : context.l10n.daysLeft(safeDaysLeft);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: colorScheme.infoSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '${context.l10n.freeTrial}: $daysLeftLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.info,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onManageTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: colorScheme.info,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              context.l10n.viewPlans,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDismissTap,
            icon: Icon(
              Icons.close,
              size: 18,
              color: colorScheme.mutedForeground,
            ),
            tooltip: context.l10n.dismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
