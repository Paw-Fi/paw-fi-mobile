import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';

class AndroidNotificationCapturePage extends HookConsumerWidget {
  const AndroidNotificationCapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);

    // Local state
    final config =
        useState<NotificationCaptureConfig>(NotificationCaptureConfig.disabled);
    final isLoading = useState(true);
    final isSyncing = useState(false);
    final hasAccess = useState(false);
    final recentApps = useState<List<RecentNotificationApp>>([]);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);

    // Load config + access status on mount
    useEffect(() {
      Future<void> loadAll() async {
        try {
          final svc = NotificationCaptureService.instance;
          final loaded = await svc.getConfig();
          final access = await svc.checkNotificationAccess();
          final apps = await svc.getRecentApps();
          config.value = loaded;
          hasAccess.value = access;
          recentApps.value = apps;
        } catch (e) {
          debugPrint('Failed to load notification capture config: $e');
        } finally {
          isLoading.value = false;
        }
      }
      loadAll();
      return null;
    }, []);

    // Re-check notification access when app resumes (user may have just granted it)
    useOnAppLifecycleStateChange((previous, current) {
      if (current == AppLifecycleState.resumed) {
        Future<void> recheck() async {
          try {
            final svc = NotificationCaptureService.instance;
            final access = await svc.checkNotificationAccess();
            hasAccess.value = access;
            if (access) {
              final apps = await svc.getRecentApps();
              recentApps.value = apps;
            }
          } catch (_) {}
        }
        recheck();
      }
    });

    Future<void> syncCredentials() async {
      isSyncing.value = true;
      try {
        final session = Supabase.instance.client.auth.currentSession;
        await NotificationCaptureService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: session?.accessToken ?? '',
          refreshToken: session?.refreshToken ?? '',
          userId: session?.user.id ?? '',
          expiresAt: session?.expiresAt ?? 0,
        );
        if (context.mounted) {
          AppToast.success(context, 'Credentials synced successfully');
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, 'Failed to sync credentials: $e');
        }
      } finally {
        isSyncing.value = false;
      }
    }

    Future<void> toggleEnabled(bool enabled) async {
      final previous = config.value;
      config.value = config.value.copyWith(enabled: enabled);
      try {
        await NotificationCaptureService.instance.setConfig(enabled: enabled);
        // Sync credentials when enabling for the first time
        if (enabled) await syncCredentials();
      } catch (e) {
        config.value = previous;
        if (context.mounted) {
          AppToast.error(context, 'Failed to update setting');
        }
      }
    }

    Future<void> pickDestinationSpace() async {
      final households = householdsAsync.valueOrNull ?? [];

      final actions = <MonekoActionSheetAction<Map<String, dynamic>>>[
        MonekoActionSheetAction(
          label: 'Personal',
          value: {
            'scopeId': 'personal',
            'scopeName': 'Personal',
            'isPortfolio': false,
          },
          icon: Icons.person_rounded,
        ),
        ...households.map(
          (h) => MonekoActionSheetAction<Map<String, dynamic>>(
            label: h.name,
            value: {
              'scopeId': h.id,
              'scopeName': h.name,
              'isPortfolio': h.isPortfolio,
            },
            icon: h.isPortfolio
                ? Icons.business_center_rounded
                : Icons.group_rounded,
          ),
        ),
      ];

      final result = await MonekoActionSheet.show<Map<String, dynamic>>(
        context: context,
        title: 'Destination Space',
        message: 'Choose where auto-captured transactions will be saved.',
        actions: actions,
        cancelAction: MonekoActionSheetAction(
          label: 'Cancel',
          value: {'cancelled': true},
        ),
      );

      if (result == null || result['cancelled'] == true) return;

      final updated = config.value.copyWith(
        scopeId: result['scopeId'] as String,
        scopeName: result['scopeName'] as String,
        isPortfolio: result['isPortfolio'] as bool,
      );
      config.value = updated;
      try {
        await NotificationCaptureService.instance.setDestinationScope(
          scopeId: result['scopeId'] as String,
          scopeName: result['scopeName'] as String,
          isPortfolio: result['isPortfolio'] as bool,
        );
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, 'Failed to update destination');
        }
      }
    }

    Future<void> grantNotificationAccess() async {
      await syncCredentials();
      try {
        await NotificationCaptureService.instance.openNotificationSettings();
      } catch (e) {
        if (context.mounted) {
          AppToast.error(
              context, 'Could not open notification settings');
        }
      }
    }

    Future<void> toggleAppEnabled(String packageName, bool enabled) async {
      // Optimistic update
      recentApps.value = recentApps.value
          .map((a) => a.packageName == packageName
              ? RecentNotificationApp(
                  packageName: a.packageName,
                  appLabel: a.appLabel,
                  lastSeenAt: a.lastSeenAt,
                  enabled: enabled,
                )
              : a)
          .toList();

      try {
        await NotificationCaptureService.instance.setPackageEnabled(
          packageName: packageName,
          enabled: enabled,
        );
      } catch (e) {
        // Revert on failure
        recentApps.value = recentApps.value
            .map((a) => a.packageName == packageName
                ? RecentNotificationApp(
                    packageName: a.packageName,
                    appLabel: a.appLabel,
                    lastSeenAt: a.lastSeenAt,
                    enabled: !enabled,
                  )
                : a)
            .toList();
        if (context.mounted) {
          AppToast.error(context, 'Failed to update app setting');
        }
      }
    }

    if (isLoading.value) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: 'Notification Capture'),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Notification Capture'),
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                _SectionCard(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.monekoPrimary,
                              AppTheme.monekoSecondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      material.Text(
                        'Notification Capture',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      material.Text(
                        'Automatically log transactions from your banking app notifications. Moneko reads the notification, extracts the amount and merchant — then AI categorizes it for you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Notification Access ───
                _SectionTitle(title: 'Notification Access'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: hasAccess.value
                                  ? colorScheme.success
                                      .withValues(alpha: 0.12)
                                  : colorScheme.error
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasAccess.value
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_rounded,
                              size: 22,
                              color: hasAccess.value
                                  ? colorScheme.success
                                  : colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                material.Text(
                                  hasAccess.value
                                      ? 'Access Granted'
                                      : 'Access Required',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                material.Text(
                                  hasAccess.value
                                      ? 'Moneko can read your notifications.'
                                      : 'Grant notification access so Moneko can detect transactions.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.mutedForeground,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!hasAccess.value) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryButton(
                            onPressed: grantNotificationAccess,
                            icon: Icons.settings_rounded,
                            label: 'Grant Notification Access',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Configuration ───
                _SectionTitle(title: 'Configuration'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Column(
                    children: [
                      // Enable toggle
                      Row(
                        children: [
                          Icon(
                            Icons.power_settings_new_rounded,
                            size: 20,
                            color: config.value.enabled
                                ? colorScheme.success
                                : colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: material.Text(
                              'Enable Notification Capture',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          AdaptiveSwitch(
                            value: config.value.enabled,
                            onChanged: hasAccess.value
                                ? (v) => toggleEnabled(v)
                                : null,
                          ),
                        ],
                      ),
                      Divider(
                        height: 24,
                        thickness: 0.5,
                        color: colorScheme.border,
                      ),
                      // Destination space
                      InkWell(
                        onTap: pickDestinationSpace,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 20,
                                color: colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    material.Text(
                                      'Destination Space',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    material.Text(
                                      config.value.scopeName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: colorScheme.mutedForeground,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Banking Apps ───
                _SectionTitle(title: 'Banking Apps'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: recentApps.value.isEmpty
                      ? Column(
                          children: [
                            Icon(
                              Icons.apps_rounded,
                              size: 36,
                              color: colorScheme.mutedForeground
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            material.Text(
                              hasAccess.value
                                  ? 'No banking apps detected yet. They\'ll appear here as notifications arrive.'
                                  : 'Grant notification access first, then banking apps will appear here as their notifications arrive.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                                height: 1.5,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            material.Text(
                              'Toggle which apps Moneko should monitor for transactions. New apps appear automatically as their notifications arrive.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...recentApps.value.asMap().entries.map((entry) {
                              final index = entry.key;
                              final app = entry.value;
                              return Column(
                                children: [
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: colorScheme.border,
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.account_balance_rounded,
                                            size: 18,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              material.Text(
                                                app.appLabel,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              material.Text(
                                                app.packageName,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colorScheme
                                                      .mutedForeground,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        AdaptiveSwitch(
                                          value: app.enabled,
                                          onChanged: (v) => toggleAppEnabled(
                                              app.packageName, v),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                ),

                const SizedBox(height: 24),

                // ─── How it Works ───
                _SectionTitle(title: 'How it Works'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Column(
                    children: const [
                      _StepItem(
                        step: 1,
                        title: 'Grant Notification Access',
                        description:
                            'Allow Moneko to read notifications from your device. This is required for detecting banking transaction alerts.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 2,
                        title: 'Enable Banking Apps',
                        description:
                            'As banking notifications arrive, the sending apps appear in the list above. Toggle on the ones you want Moneko to monitor.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 3,
                        title: 'Transactions are Captured',
                        description:
                            'When a matching notification arrives, Moneko extracts the merchant, amount, and currency, then sends it to the cloud for AI categorization.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 4,
                        title: 'Review in Moneko',
                        description:
                            'Captured transactions appear in your timeline just like manually-added ones. You can edit the category or details anytime.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Privacy Notice ───
                _SectionTitle(title: 'Privacy'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 20,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: material.Text(
                          'Moneko only processes notifications from the apps you enable above. Notification content is analyzed on-device to extract transaction details, then sent securely to Moneko\'s servers for AI categorization. No other notification data is stored or transmitted.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Sync Credentials Button ───
                SizedBox(
                  width: double.infinity,
                  child: _SecondaryButton(
                    onPressed: isSyncing.value ? null : syncCredentials,
                    icon: Icons.sync_rounded,
                    label: isSyncing.value
                        ? 'Syncing...'
                        : 'Sync Credentials',
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(color: colorScheme.surfaceBorder)
            : null,
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.step,
    required this.title,
    required this.description,
  });

  final int step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.monekoPrimary, AppTheme.monekoSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.monekoPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
