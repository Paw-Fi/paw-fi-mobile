import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/beta_pill.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';

class AndroidNotificationCapturePage extends HookConsumerWidget {
  const AndroidNotificationCapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    // Local state
    final config =
        useState<NotificationCaptureConfig>(NotificationCaptureConfig.disabled);
    final isLoading = useState(true);
    final isSyncing = useState(false);
    final isUpdatingDestination = useState(false);
    final hasAccess = useState(false);
    final hasNotificationPermission = useState(true);
    final recentApps = useState<List<RecentNotificationApp>>([]);
    // The PK of the user's user_contacts row — used for targeted updates.
    final contactId = useState<String?>(null);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);

    Future<bool> syncCredentials({bool showError = false}) async {
      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken ?? '';
      final refreshToken = session?.refreshToken ?? '';
      final userId = session?.user.id ?? '';
      final expiresAt = session?.expiresAt ?? 0;

      if (accessToken.isEmpty || refreshToken.isEmpty || userId.isEmpty) {
        if (showError && context.mounted) {
          AppToast.error(
            context,
            context.l10n.signInAgainToEnableNotificationCapture,
          );
        }
        return false;
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

        final refreshedConfig =
            await NotificationCaptureService.instance.getConfig();
        config.value = config.value.copyWith(
          hasAuthStorage: refreshedConfig.hasAuthStorage,
          hasCredentials: refreshedConfig.hasCredentials,
          isReady: refreshedConfig.isReady,
        );

        if (!refreshedConfig.isReady && showError && context.mounted) {
          AppToast.error(
            context,
            context.l10n.couldNotPrepareNotificationCaptureOnThisDevice,
          );
        }

        return refreshedConfig.isReady;
      } catch (e) {
        if (showError && context.mounted) {
          AppToast.error(
              context, '${context.l10n.failedToEnableNotificationCapture}: $e');
        }
        return false;
      } finally {
        isSyncing.value = false;
      }
    }

    // Load config + access status on mount — merges native config with Supabase flag.
    useEffect(() {
      Future<void> checkNotificationPermission() async {
        final status = await Permission.notification.status;
        hasNotificationPermission.value = status.isGranted;
      }

      Future<void> loadAll() async {
        await checkNotificationPermission();
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
                .order('updated_at', ascending: false)
                .limit(1)
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

          if (loaded.hasAuthStorage && !loaded.isReady) {
            await syncCredentials();
          }
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
            final status = await Permission.notification.status;
            hasNotificationPermission.value = status.isGranted;

            final svc = NotificationCaptureService.instance;
            final access = await svc.checkNotificationAccess();
            hasAccess.value = access;
            if (access) {
              final apps = await svc.getRecentApps();
              recentApps.value = apps;
            }

            final refreshedConfig = await svc.getConfig();
            config.value = config.value.copyWith(
              hasAuthStorage: refreshedConfig.hasAuthStorage,
              hasCredentials: refreshedConfig.hasCredentials,
              isReady: refreshedConfig.isReady,
            );

            if (refreshedConfig.hasAuthStorage && !refreshedConfig.isReady) {
              await syncCredentials();
            }
          } catch (_) {}
        }

        recheck();
      }
    });

    /// Persists the enabled flag to both Android native (SharedPreferences)
    /// and Supabase (user_contacts.wallet_capture_enabled).
    Future<void> toggleEnabled(bool enabled) async {
      final previous = config.value;
      final previousEnabled = previous.enabled;
      config.value = config.value.copyWith(enabled: enabled);

      debugPrint(
          '[NotificationCapture] toggleEnabled called: enabled=$enabled uid=${authState.uid} contactId=${contactId.value}');

      try {
        if (enabled) {
          final didSync = config.value.isReady
              ? true
              : await syncCredentials(showError: true);
          if (!didSync) {
            config.value = previous;
            return;
          }
        }

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
      } catch (e, st) {
        debugPrint('[NotificationCapture] toggleEnabled error: $e');
        debugPrint('[NotificationCapture] Stack trace: $st');
        try {
          await NotificationCaptureService.instance
              .setConfig(enabled: previousEnabled);
        } catch (_) {}
        final refreshedConfig =
            await NotificationCaptureService.instance.getConfig();
        // Roll back optimistic update on failure.
        config.value = refreshedConfig.copyWith(enabled: previousEnabled);
        if (context.mounted) {
          AppToast.error(context, context.l10n.failedToUpdateSetting);
        }
      }
    }

    Future<void> pickDestinationSpace() async {
      final households = householdsAsync.valueOrNull ?? [];

      final actions = <MonekoActionSheetAction<Map<String, dynamic>>>[
        MonekoActionSheetAction(
          label: context.l10n.personal,
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
        title: context.l10n.destinationSpace,
        message: context.l10n.chooseWhereAutoCapturedTransactionsWillBeSaved,
        actions: actions,
        cancelAction: MonekoActionSheetAction(
          label: context.l10n.cancel,
          value: {'cancelled': true},
        ),
      );

      if (result == null || result['cancelled'] == true) return;

      final previous = config.value;
      final updated = config.value.copyWith(
        scopeId: result['scopeId'] as String,
        scopeName: result['scopeName'] as String,
        isPortfolio: result['isPortfolio'] as bool,
      );
      config.value = updated;
      isUpdatingDestination.value = true;
      try {
        await NotificationCaptureService.instance.setDestinationScope(
          scopeId: result['scopeId'] as String,
          scopeName: result['scopeName'] as String,
          isPortfolio: result['isPortfolio'] as bool,
        );
      } catch (e) {
        config.value = previous;
        if (context.mounted) {
          AppToast.error(context, context.l10n.failedToUpdateDestination);
        }
      } finally {
        isUpdatingDestination.value = false;
      }
    }

    Future<void> grantNotificationAccess() async {
      try {
        await NotificationCaptureService.instance.openNotificationSettings();
      } catch (e) {
        if (context.mounted) {
          AppToast.error(
              context, context.l10n.couldNotOpenNotificationSettings);
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
          AppToast.error(context, context.l10n.failedToUpdateAppSetting);
        }
      }
    }

    if (isLoading.value) {
      return AdaptiveScaffold(
          appBar: AdaptiveAppBar(title: context.l10n.autoTransactionCapture),
          body: Container(
            color: colorScheme.appBackground,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ));
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: context.l10n.autoTransactionCapture),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: SafeArea(
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
                  _buildHero(context, colorScheme),
                  if (!config.value.hasAuthStorage) ...[
                    _buildAuthStorageWarning(context, colorScheme),
                    const SizedBox(height: 16),
                  ],
                  _SettingsGroup(
                    title: context.l10n.configuration,
                    children: [
                      _SettingsTile(
                        icon: Icons.power_settings_new_rounded,
                        iconColor: Colors.white,
                        iconBackgroundColor: config.value.enabled
                            ? colorScheme.success
                            : colorScheme.mutedForeground,
                        title: context.l10n.enableAutoCapture,
                        trailing: AdaptiveSwitch(
                          value: config.value.enabled,
                          onChanged: isSyncing.value
                              ? null
                              : (value) {
                                  if (!value) {
                                    toggleEnabled(false);
                                    return;
                                  }

                                  if (!config.value.hasAuthStorage) {
                                    AppToast.error(
                                      context,
                                      context.l10n
                                          .notificationCaptureIsUnavailableOnThisDevice,
                                    );
                                    return;
                                  }

                                  if (!hasAccess.value) {
                                    grantNotificationAccess();
                                    return;
                                  }

                                  toggleEnabled(true);
                                },
                        ),
                      ),
                      if (config.value.enabled &&
                          !hasNotificationPermission.value)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.warning.withValues(alpha: 0.1)
                                : colorScheme.warning.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: colorScheme.warning, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.enableNotificationsSummary,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? colorScheme.foreground
                                            : colorScheme.foreground
                                                .withValues(alpha: 0.8),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => openAppSettings(),
                                      behavior: HitTestBehavior.opaque,
                                      child: Text(
                                        context.l10n.openSettingsToEnable,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      _SettingsTile(
                        icon: Icons.folder_rounded,
                        iconColor: Colors.white,
                        iconBackgroundColor: colorScheme.primary,
                        title: context.l10n.destinationSpace,
                        subtitle: config.value.scopeName,
                        enabled: config.value.enabled,
                        trailing: isUpdatingDestination.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2),
                              )
                            : Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.mutedForeground,
                                size: 20,
                              ),
                        onTap: (!config.value.enabled ||
                                isUpdatingDestination.value)
                            ? null
                            : pickDestinationSpace,
                        showDivider: false,
                      ),
                    ],
                  ),
                  if (config.value.enabled) ...[
                    const SizedBox(height: 36),
                    _SettingsGroup(
                      title: context.l10n.supportedApps,
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
                                            ? context
                                                .l10n.waitingForNotifications
                                            : context
                                                .l10n.grantAccessToSeeAppsHere,
                                        style: TextStyle(
                                            color: colorScheme.mutedForeground,
                                            fontSize: 15),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ]
                          : [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  context.l10n.toggleAppsMonekoShouldMonitor,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.mutedForeground,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              ...recentApps.value.asMap().entries.map((entry) {
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
                  ],
                  const SizedBox(height: 36),
                  _buildHowItWorks(
                    context,
                    colorScheme,
                    hasAccess.value,
                    grantNotificationAccess,
                  ),
                  const SizedBox(height: 36),
                  _buildPrivacyFooter(context, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, ColorScheme colorScheme) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.autoCapture,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 10),
              const BetaPill(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.connectSupportedNotificationApps,
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

  Widget _buildAuthStorageWarning(
      BuildContext context, ColorScheme colorScheme) {
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
                  context.l10n.secureStorageUnavailable,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: colorScheme.foreground,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n
                      .monekoCannotSecurelyStoreBackgroundSyncCredentialsOnThisDevice,
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

  Widget _buildHowItWorks(
    BuildContext context,
    ColorScheme colorScheme,
    bool hasAccess,
    VoidCallback onGrant,
  ) {
    Future<void> showScreenshotGallery() async {
      const assets = [
        'lib/assets/images/wallet_sync/android_wallet_1.png',
        'lib/assets/images/wallet_sync/android_wallet_2.png',
      ];

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colorScheme.sheetBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (modalContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(modalContext).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.androidSettingsWalkthrough,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n
                      .followTheseScreensToTurnOnNotificationAccessForMoneko,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 9 / 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: assets
                      .map(
                        (asset) => _HowItWorksScreenshot(asset: asset),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 16),
          child: Text(
            context.l10n.howItWorksTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _HowItWorksCard(
          step: 1,
          title: context.l10n.grantNotificationAccess,
          description: hasAccess
              ? context.l10n.notificationAccessIsAlreadyEnabledForMoneko
              : context.l10n
                  .tapGrantAccessOrOpenAndroidSettingsSoMonekoCanReadNotificationsInTheBackground,
          action: hasAccess
              ? null
              : ElevatedButton(
                  onPressed: onGrant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    context.l10n.grantAccess,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _HowItWorksCard(
          step: 2,
          title: context.l10n.enableMonekoInsideAndroidSettings,
          description: context
              .l10n.goToSettingsNotificationsNotificationReadReplyAndControl,
          action: TextButton.icon(
            onPressed: showScreenshotGallery,
            icon: Icon(Icons.photo_library_rounded, color: colorScheme.primary),
            label: Text(
              context.l10n.showSteps,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _HowItWorksCard(
          step: 3,
          title: context.l10n.chooseWhichNotificationsToRead,
          description: context
              .l10n.afterAccessIsGrantedTurnOnOnlyTheAppsYouWantMonekoToMonitor,
        ),
        const SizedBox(height: 12),
        _HowItWorksCard(
          step: 4,
          title: context.l10n.automaticCapture,
          description: context.l10n
              .monekoExtractsMerchantAmountAndCurrencyWhenNotificationsArrive,
        ),
      ],
    );
  }

  Widget _buildPrivacyFooter(BuildContext context, ColorScheme colorScheme) {
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
              context.l10n
                  .onlyYouCanAccessItMonekoNeverSellsOrSharesYourFinancialData,
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
  final bool enabled;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveForeground = enabled
        ? colorScheme.foreground
        : colorScheme.mutedForeground.withValues(alpha: 0.6);
    final effectiveSubtitle = enabled
        ? colorScheme.mutedForeground
        : colorScheme.mutedForeground.withValues(alpha: 0.5);
    final effectiveIconBg =
        enabled ? iconBackgroundColor : colorScheme.surfaceContainerHighest;
    final effectiveIconColor =
        enabled ? iconColor : colorScheme.mutedForeground;

    Widget content = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveIconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: effectiveIconColor),
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
                      color: effectiveForeground,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 15,
                        color: effectiveSubtitle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
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

class _HowItWorksCard extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final Widget? action;

  const _HowItWorksCard({
    required this.step,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.surfaceBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.mutedForeground,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _HowItWorksScreenshot extends StatelessWidget {
  final String asset;

  const _HowItWorksScreenshot({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}
