import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

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
    // The PK of the user's user_contacts row — used for targeted updates.
    final contactId = useState<String?>(null);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);

    // Load config + access status on mount — merges native config with Supabase flag.
    useEffect(() {
      Future<void> loadAll() async {
        try {
          final svc = NotificationCaptureService.instance;

          // 1. Load local Android config (enabled, scopeId, scopeName, etc.).
          final loaded = await svc.getConfig();
          final access = await svc.checkNotificationAccess();
          final apps = await svc.getRecentApps();

          // 2. Fetch the authoritative enabled flag from Supabase.
          bool remoteEnabled = false;
          if (authState.uid.isNotEmpty) {
            final response = await Supabase.instance.client
                .from('user_contacts')
                .select('id, wallet_capture_enabled')
                .eq('user_id', authState.uid)
                .maybeSingle();
            if (response != null) {
              contactId.value = response['id'] as String?;
              remoteEnabled =
                  (response['wallet_capture_enabled'] as bool?) ?? false;
              debugPrint(
                  '[NotificationCapture] loadAll: contactId=${contactId.value} remoteEnabled=$remoteEnabled');
            } else {
              debugPrint(
                  '[NotificationCapture] loadAll: no user_contacts row found for uid=${authState.uid}');
            }
          }

          // Reconcile: trust Supabase for enabled, native for the rest.
          config.value = loaded.copyWith(enabled: remoteEnabled);
          hasAccess.value = access;
          recentApps.value = apps;

          // Keep native config in sync with Supabase value.
          await svc.setConfig(enabled: remoteEnabled);
        } catch (e) {
          debugPrint('Failed to load notification capture config: $e');
        } finally {
          isLoading.value = false;
        }
      }

      loadAll();
      return null;
    }, []);

    // Re-check notification access when app resumes
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
      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken ?? '';
      final refreshToken = session?.refreshToken ?? '';
      final userId = session?.user.id ?? '';
      final expiresAt = session?.expiresAt ?? 0;

      if (accessToken.isEmpty || refreshToken.isEmpty || userId.isEmpty) {
        if (context.mounted) {
          AppToast.error(
            context,
            'Sign in again to sync notification capture credentials.',
          );
        }
        return;
      }

      isSyncing.value = true;
      try {
        await NotificationCaptureService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          expiresAt: expiresAt,
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

    /// Persists the enabled flag to both Android native (SharedPreferences)
    /// and Supabase (user_contacts.wallet_capture_enabled).
    Future<void> toggleEnabled(bool enabled) async {
      final previous = config.value;
      config.value = config.value.copyWith(enabled: enabled);

      debugPrint(
          '[NotificationCapture] toggleEnabled called: enabled=$enabled uid=${authState.uid} contactId=${contactId.value}');

      try {
        // Write to Android native layer.
        debugPrint('[NotificationCapture] Writing to Android native...');
        await NotificationCaptureService.instance.setConfig(enabled: enabled);
        debugPrint('[NotificationCapture] Android native write succeeded');

        // Write to Supabase via the update-wallet-capture-setting edge function
        // (service role bypasses RLS — same pattern as iOS wallet capture).
        debugPrint('[NotificationCapture] Calling edge function...');
        final fnResponse = await Supabase.instance.client.functions.invoke(
          'update-wallet-capture-setting',
          body: {'enabled': enabled},
        );
        if (fnResponse.status != 200) {
          throw Exception(
              'Edge function returned ${fnResponse.status}: ${fnResponse.data}');
        }
        final newContactId = fnResponse.data?['contactId'] as String?;
        if (newContactId != null) {
          contactId.value = newContactId;
        }
        debugPrint(
            '[NotificationCapture] Edge function OK — contactId=${contactId.value}');

        if (enabled) await syncCredentials();
      } catch (e, st) {
        debugPrint('[NotificationCapture] toggleEnabled error: $e');
        debugPrint('[NotificationCapture] Stack trace: $st');
        // Roll back optimistic update on failure.
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
          AppToast.error(context, 'Could not open notification settings');
        }
      }
    }

    Future<void> toggleAppEnabled(String packageName, bool enabled) async {
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
          appBar: const AdaptiveAppBar(title: 'Notification Capture'),
          body: Container(
            color: colorScheme.appBackground,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ));
    }

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Notification Capture'),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: getSubPageTopPadding(context),
                      left: 20,
                      right: 20,
                      bottom: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(colorScheme),
                        if (!config.value.hasAuthStorage) ...[
                          _buildAuthStorageWarning(colorScheme),
                          const SizedBox(height: 16),
                        ],
                        if (!hasAccess.value) ...[
                          _buildAccessWarning(
                              colorScheme, grantNotificationAccess),
                          const SizedBox(height: 32),
                        ],
                        _SettingsGroup(
                          title: 'Configuration',
                          children: [
                            _SettingsTile(
                              icon: Icons.power_settings_new_rounded,
                              iconColor: Colors.white,
                              iconBackgroundColor: config.value.enabled
                                  ? colorScheme.success
                                  : colorScheme.mutedForeground,
                              title: 'Enable Auto-Capture',
                              trailing: AdaptiveSwitch(
                                value: config.value.enabled,
                                onChanged: hasAccess.value &&
                                        config.value.hasAuthStorage
                                    ? toggleEnabled
                                    : null,
                              ),
                            ),
                            _SettingsTile(
                              icon: Icons.folder_rounded,
                              iconColor: Colors.white,
                              iconBackgroundColor: colorScheme.primary,
                              title: 'Destination Space',
                              subtitle: config.value.scopeName,
                              trailing: Icon(Icons.chevron_right_rounded,
                                  color: colorScheme.mutedForeground, size: 20),
                              onTap: pickDestinationSpace,
                              showDivider: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _SettingsGroup(
                          title: 'Supported Apps',
                          children: recentApps.value.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.notifications_off_rounded,
                                              size: 48,
                                              color: colorScheme.mutedForeground
                                                  .withValues(alpha: 0.4)),
                                          const SizedBox(height: 16),
                                          Text(
                                            hasAccess.value
                                                ? 'Waiting for notifications...'
                                                : 'Grant access to see apps here.',
                                            style: TextStyle(
                                                color:
                                                    colorScheme.mutedForeground,
                                                fontSize: 15),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ]
                              : [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 8),
                                    child: Text(
                                      'Toggle which apps Moneko should monitor. New apps appear automatically when they send a notification.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.mutedForeground,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  ...recentApps.value
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final app = entry.value;
                                    return _AppToggleTile(
                                      appLabel: app.appLabel,
                                      packageName: app.packageName,
                                      enabled: app.enabled,
                                      onChanged: (v) =>
                                          toggleAppEnabled(app.packageName, v),
                                      showDivider:
                                          index < recentApps.value.length - 1,
                                    );
                                  }),
                                ],
                        ),
                        const SizedBox(height: 36),
                        _buildHowItWorks(colorScheme),
                        const SizedBox(height: 36),
                        _buildPrivacyFooter(colorScheme),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(
                  context,
                  colorScheme,
                  isSyncing.value,
                  config.value.hasAuthStorage,
                  syncCredentials,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.monekoPrimary, AppTheme.monekoSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.monekoPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Auto-Capture',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect supported notification apps to Moneko so transaction alerts can be logged into your chosen space automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessWarning(ColorScheme colorScheme, VoidCallback onGrant) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.warning_rounded, color: colorScheme.error, size: 32),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Access Required',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: colorScheme.foreground,
                        letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text('Grant notification access to detect alerts.',
                    style: TextStyle(
                        color: colorScheme.foreground.withValues(alpha: 0.8),
                        fontSize: 15)),
              ])),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onGrant,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Grant',
                style: TextStyle(fontWeight: FontWeight.w600)),
          )
        ]));
  }

  Widget _buildAuthStorageWarning(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sd_card_alert_rounded,
              color: colorScheme.warning, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Storage Unavailable',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: colorScheme.foreground,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Moneko cannot securely store background sync credentials on this device, so notification capture will not stay connected.',
                  style: TextStyle(
                    color: colorScheme.foreground.withValues(alpha: 0.8),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 16),
          child: Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const _FeatureItem(
          icon: Icons.check_circle_outline_rounded,
          title: 'Grant access',
          description:
              'Allow Moneko to securely read notifications on your device.',
        ),
        const _FeatureItem(
          icon: Icons.app_registration_rounded,
          title: 'Enable trusted apps',
          description:
              'Turn on monitoring for specific banking or wallet apps as they appear.',
        ),
        const _FeatureItem(
          icon: Icons.auto_awesome_rounded,
          title: 'Automatic capture',
          description:
              'Moneko extracts merchant, amount, and currency when alerts arrive.',
        ),
      ],
    );
  }

  Widget _buildPrivacyFooter(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded,
              size: 20, color: colorScheme.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only you can access it. Moneko never sells or shares your financial data.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme,
      bool isSyncing, bool canSync, VoidCallback onSync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: PrimaryAdaptiveButton(
            onPressed: isSyncing || !canSync ? null : onSync,
            child: isSyncing
                ? const CircularProgressIndicator.adaptive()
                : const Text(
                    'Sync Credentials',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border:
                isDark ? Border.all(color: colorScheme.surfaceBorder) : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.foreground,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    return Column(
      children: [
        content,
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(context).colorScheme.border),
          ),
      ],
    );
  }
}

class _AppToggleTile extends StatelessWidget {
  final String appLabel;
  final String packageName;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _AppToggleTile({
    required this.appLabel,
    required this.packageName,
    required this.enabled,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.foreground,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      packageName,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AdaptiveSwitch(
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child:
                Divider(height: 1, thickness: 0.5, color: colorScheme.border),
          ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.mutedForeground,
                    height: 1.4,
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
