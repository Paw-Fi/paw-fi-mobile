import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/wallet_capture_service.dart';
import 'package:moneko/core/services/wallet_capture_debug_service.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/profile/presentation/widgets/wallet_sync_setup_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class IosWalletCapturePage extends HookConsumerWidget {
  const IosWalletCapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    // Local state
    final config = useState<WalletCaptureConfig>(WalletCaptureConfig.disabled);
    final isLoading = useState(true);
    final isSyncing = useState(false);
    final isLoadingDebugReport = useState(false);
    final hasNotificationPermission = useState(true);
    // The PK of the user's user_contacts row — used for targeted updates.
    final contactId = useState<String?>(null);
    final debugReport = useState<WalletCaptureDebugReport?>(null);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);
    final captureScopeHouseholdId =
        config.value.scopeId == 'personal' ? null : config.value.scopeId;
    final walletsAsync =
        ref.watch(walletsByHouseholdIdProvider(captureScopeHouseholdId));

    String? resolveDefaultWalletId(List<WalletEntity> wallets) {
      for (final wallet in wallets) {
        if (wallet.isDefault) return wallet.id;
      }
      return wallets.isNotEmpty ? wallets.first.id : null;
    }

    String selectedWalletLabel(AsyncValue<List<WalletEntity>> state) {
      return state.when(
        data: (wallets) {
          if (wallets.isEmpty) return context.l10n.tapToSet;
          final selectedId = config.value.accountId;
          if (selectedId != null) {
            for (final wallet in wallets) {
              if (wallet.id == selectedId) return wallet.name;
            }
          }
          final fallbackId = resolveDefaultWalletId(wallets);
          if (fallbackId != null) {
            for (final wallet in wallets) {
              if (wallet.id == fallbackId) return wallet.name;
            }
          }
          return wallets.first.name;
        },
        loading: () => context.l10n.loading,
        error: (_, __) => context.l10n.tapToSet,
      );
    }

    // Load config on mount — merges iOS native config with Supabase flag.
    Future<void> loadDebugReport() async {
      isLoadingDebugReport.value = true;
      try {
        debugReport.value =
            await WalletCaptureDebugService.instance.getReport();
      } catch (e) {
        debugPrint('Failed to load wallet capture debug report: $e');
      } finally {
        isLoadingDebugReport.value = false;
      }
    }

    Future<void> recordDebugEntry({
      required String action,
      required String message,
      Map<String, dynamic> details = const <String, dynamic>{},
    }) async {
      try {
        await WalletCaptureDebugService.instance.appendEntry(
          source: 'flutter',
          action: action,
          message: message,
          details: details,
        );
      } catch (e) {
        debugPrint('Failed to append wallet capture debug entry: $e');
      }
    }

    useEffect(() {
      Future<void> checkNotificationPermission() async {
        final status = await Permission.notification.status;
        hasNotificationPermission.value = status.isGranted;
      }

      Future<void> loadConfig() async {
        try {
          // 1. Load local iOS config (scopeId, scopeName, isPortfolio).
          final loaded = await WalletCaptureService.instance.getConfig();

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
                  '[WalletCapture] loadConfig: contactId=${contactId.value} remoteEnabled=$remoteEnabled');
            } else {
              debugPrint(
                  '[WalletCapture] loadConfig: no user_contacts row found for uid=${authState.uid}');
            }
          }

          // Reconcile: trust Supabase for enabled, iOS native for the rest.
          config.value = loaded.copyWith(enabled: remoteEnabled);

          // Keep iOS native in sync with Supabase value.
          await WalletCaptureService.instance.setConfig(config.value);
        } catch (e) {
          debugPrint('Failed to load wallet capture config: $e');
        } finally {
          isLoading.value = false;
        }
      }

      Future<void> initAll() async {
        await checkNotificationPermission();
        await loadConfig();
        await loadDebugReport();
      }

      initAll();
      return null;
    }, []);

    useOnAppLifecycleStateChange((previous, current) {
      if (current == AppLifecycleState.resumed) {
        Future<void> recheck() async {
          final status = await Permission.notification.status;
          hasNotificationPermission.value = status.isGranted;
        }

        recheck();
      }
    });

    Future<void> syncCredentials({bool showSuccessToast = true}) async {
      isSyncing.value = true;
      try {
        final session = Supabase.instance.client.auth.currentSession;
        final accessToken = session?.accessToken ?? '';
        final refreshToken = session?.refreshToken ?? '';
        final userId = session?.user.id ?? '';

        if (accessToken.isEmpty || refreshToken.isEmpty || userId.isEmpty) {
          if (context.mounted) {
            AppToast.error(
              context,
              context.l10n.signInAgainToSyncWalletCaptureCredentials,
            );
          }
          return;
        }

        await SiriShortcutAuthService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          expiresAt: session?.expiresAt,
        );
        await loadDebugReport();
        if (context.mounted && showSuccessToast) {
          AppToast.success(context, context.l10n.credentialsSyncedSuccessfully);
        }
      } catch (e) {
        await loadDebugReport();
        if (context.mounted) {
          AppToast.error(
              context, '${context.l10n.failedToSyncCredentials}: $e');
        }
      } finally {
        isSyncing.value = false;
      }
    }

    Future<void> openShortcuts() async {
      await syncCredentials();
      if (!context.mounted) return;

      try {
        final launched = await launchUrl(
          Uri.parse('shortcuts://'),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          AppToast.error(context, context.l10n.couldNotOpenShortcutsApp);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.couldNotOpenShortcutsApp);
        }
      }
    }

    void showSetupSheet() {
      showModalBottomSheet(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        enableDrag: false,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) {
          return WalletSyncSetupSheet(
            isSyncing: isSyncing.value,
            onFinish: () {
              Navigator.of(context).pop();
              openShortcuts();
            },
          );
        },
      );
    }

    /// Persists the enabled flag to both iOS native (UserDefaults/Keychain)
    /// and Supabase (user_contacts.wallet_capture_enabled).
    Future<void> toggleEnabled(bool enabled) async {
      final previous = config.value;
      final updated = previous.copyWith(enabled: enabled);
      config.value = updated;

      debugPrint(
          '[WalletCapture] toggleEnabled called: enabled=$enabled uid=${authState.uid} contactId=${contactId.value}');
      await recordDebugEntry(
        action: 'toggle-start',
        message: 'Wallet capture switch toggled from the UI.',
        details: {
          'enabled': enabled,
          'uid': authState.uid,
          'contactId': contactId.value,
        },
      );

      try {
        // Write to iOS native layer.
        debugPrint('[WalletCapture] Writing to iOS native...');
        await WalletCaptureService.instance.setConfig(updated);
        debugPrint('[WalletCapture] iOS native write succeeded');
        await recordDebugEntry(
          action: 'toggle-native-write-success',
          message: 'Wallet capture config was written to the iOS shared store.',
          details: {
            'enabled': updated.enabled,
            'scopeId': updated.scopeId,
            'scopeName': updated.scopeName,
            'isPortfolio': updated.isPortfolio,
          },
        );

        // Write to Supabase via the update-wallet-capture-setting edge function
        // (service role bypass RLS — same pattern as update-preferred-currency).
        debugPrint('[WalletCapture] Calling edge function...');
        await recordDebugEntry(
          action: 'toggle-function-invoke-start',
          message: 'Invoking update-wallet-capture-setting.',
          details: {
            'enabled': enabled,
          },
        );
        final fnResponse = await Supabase.instance.client.functions.invoke(
          'update-wallet-capture-setting',
          body: {'enabled': enabled},
        );
        await recordDebugEntry(
          action: 'toggle-function-invoke-finished',
          message: 'update-wallet-capture-setting returned a response.',
          details: {
            'status': fnResponse.status,
            'data': fnResponse.data?.toString() ?? '<null>',
          },
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
            '[WalletCapture] Edge function OK — contactId=${contactId.value}');
        await loadDebugReport();
      } catch (e, st) {
        debugPrint('[WalletCapture] toggleEnabled error: $e');
        debugPrint('[WalletCapture] Stack trace: $st');
        // Roll back optimistic update on failure.
        config.value = previous;
        try {
          await WalletCaptureService.instance.setConfig(previous);
        } catch (rollbackError) {
          debugPrint(
              'Failed to roll back native wallet capture config: $rollbackError');
        }
        await recordDebugEntry(
          action: 'toggle-error',
          message: 'Wallet capture toggle failed before completion.',
          details: {
            'error': e.toString(),
            'rolledBackEnabled': previous.enabled,
          },
        );
        await loadDebugReport();
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

      final updated = config.value.copyWith(
        scopeId: result['scopeId'] as String,
        scopeName: result['scopeName'] as String,
        isPortfolio: result['isPortfolio'] as bool,
        clearAccountSelection: true,
      );
      config.value = updated;
      try {
        await WalletCaptureService.instance.setConfig(updated);
        await loadDebugReport();
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.failedToUpdateDestination);
        }
      }
    }

    Future<void> pickDestinationWallet() async {
      final wallets = walletsAsync.valueOrNull ?? const <WalletEntity>[];
      if (wallets.isEmpty) return;

      final actions = wallets
          .map(
            (wallet) => MonekoActionSheetAction<WalletEntity?>(
              label: wallet.name,
              value: wallet,
              icon: Icons.account_balance_wallet_rounded,
            ),
          )
          .toList(growable: true);

      final selected = await MonekoActionSheet.show<WalletEntity?>(
        context: context,
        title: context.l10n.wallet,
        actions: actions,
        cancelAction: MonekoActionSheetAction(
          label: context.l10n.cancel,
          value: null,
        ),
      );

      if (selected == null || selected.id == config.value.accountId) return;

      final previous = config.value;
      final updated = config.value.copyWith(
        accountId: selected.id,
        accountName: selected.name,
      );
      config.value = updated;
      try {
        await WalletCaptureService.instance.setConfig(updated);
        await loadDebugReport();
      } catch (e) {
        config.value = previous;
        if (context.mounted) {
          AppToast.error(context, context.l10n.failedToUpdateSetting);
        }
      }
    }

    Future<void> clearDebugReport() async {
      isLoadingDebugReport.value = true;
      try {
        await WalletCaptureDebugService.instance.clearReport();
        debugReport.value =
            await WalletCaptureDebugService.instance.getReport();
      } catch (e) {
        if (context.mounted) {
          AppToast.error(
              context, 'Failed to clear wallet capture debug log: $e');
        }
      } finally {
        isLoadingDebugReport.value = false;
      }
    }

    if (isLoading.value) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
              appBar: AdaptiveAppBar(title: context.l10n.applePayIntegration),
              body: Container(
                color: colorScheme.appBackground,
                child:
                    const Center(child: CircularProgressIndicator.adaptive()),
              )));
    }

    final cardDecoration = BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: isDark ? Border.all(color: colorScheme.surfaceBorder) : null,
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );

    final isEnabled = config.value.enabled;
    final debugSnapshot = debugReport.value?.snapshot;
    final debugEntries =
        debugReport.value?.entries ?? const <WalletCaptureDebugEntry>[];

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.applePayIntegration,
      ),
      body: Container(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: getSubPageTopPadding(context) + 16,
              left: 24,
              right: 24,
              bottom: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.autoCaptureDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Top Card: Icon + Selection — disabled until Apple Pay Integration is on.
                AnimatedOpacity(
                  opacity: isEnabled ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !isEnabled,
                    child: Container(
                      decoration: cardDecoration,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.surfaceContainer
                                    : const Color(0xFFF2F0F9),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: SvgPicture.asset(
                                'lib/assets/images/wallet_sync/apple_wallet.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            context.l10n.logTransactionsTo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          /* Dropdown Button Replica */
                          GestureDetector(
                            onTap: pickDestinationSpace,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.surfaceContainer
                                    : colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    config.value.isPortfolio
                                        ? Icons.business_center_rounded
                                        : Icons.person_rounded,
                                    size: 20,
                                    color: colorScheme.foreground,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      config.value.scopeName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: colorScheme.foreground,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.wallet,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: pickDestinationWallet,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colorScheme.surfaceContainer
                                    : colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 20,
                                    color: colorScheme.foreground,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedWalletLabel(walletsAsync),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: colorScheme.foreground,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bottom Card: Toggle + Connect Button
                Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        context.l10n.applePaySync,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: showSetupSheet,
                                      behavior: HitTestBehavior.opaque,
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n
                                      .yourTransactionsAreAddedAutomatically,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.mutedForeground,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          AdaptiveSwitch(
                            value: isEnabled,
                            onChanged: toggleEnabled,
                          ),
                        ],
                      ),
                      if (isEnabled) ...[
                        if (!hasNotificationPermission.value) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colorScheme.warning.withValues(alpha: 0.1)
                                  : colorScheme.warning.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: colorScheme.warning, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: PrimaryAdaptiveButton(
                            onPressed: showSetupSheet,
                            child: Text(
                              context.l10n.startSetup,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.transactionDataStoredSecurely,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Debug report',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reproduce the failure, then refresh this report to inspect the last native shortcut steps.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.mutedForeground,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLoadingDebugReport.value)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 160,
                            child: PrimaryAdaptiveButton(
                              onPressed: isLoadingDebugReport.value
                                  ? null
                                  : () => loadDebugReport(),
                              child: const Text('Refresh report'),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: PrimaryAdaptiveButton(
                              onPressed: isSyncing.value
                                  ? null
                                  : () =>
                                      syncCredentials(showSuccessToast: false),
                              child: Text(
                                isSyncing.value
                                    ? 'Syncing…'
                                    : 'Sync credentials',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: AdaptiveButton(
                              onPressed: isLoadingDebugReport.value
                                  ? null
                                  : () => clearDebugReport(),
                              label: 'Clear log',
                              style: AdaptiveButtonStyle.gray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (debugSnapshot != null) ...[
                        _DebugStatusRow(
                          label: 'Ready',
                          value: debugSnapshot.isReady ? 'Yes' : 'No',
                        ),
                        _DebugStatusRow(
                          label: 'Supabase config',
                          value: debugSnapshot.hasSupabaseConfig
                              ? 'Present'
                              : 'Missing',
                        ),
                        _DebugStatusRow(
                          label: 'Credentials',
                          value: debugSnapshot.hasCredentials
                              ? 'Present'
                              : 'Missing',
                        ),
                        _DebugStatusRow(
                          label: 'Wallet capture',
                          value: debugSnapshot.walletCaptureEnabled
                              ? 'Enabled'
                              : 'Disabled',
                        ),
                        _DebugStatusRow(
                          label: 'Destination',
                          value:
                              '${debugSnapshot.walletScopeName} (${debugSnapshot.walletScopeId})',
                        ),
                        _DebugStatusRow(
                          label: 'Token state',
                          value: debugSnapshot.isAccessTokenExpired
                              ? 'Expired'
                              : 'Usable',
                        ),
                        if (debugSnapshot.expiresAt > 0)
                          _DebugStatusRow(
                            label: 'Expires at',
                            value: DateTime.fromMillisecondsSinceEpoch(
                              debugSnapshot.expiresAt * 1000,
                              isUtc: true,
                            ).toIso8601String(),
                          ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Recent native events',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (debugEntries.isEmpty)
                        Text(
                          'No events recorded yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (final entry in debugEntries.reversed)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: isDark ? 0.35 : 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.surfaceBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.timestamp} • ${entry.source} / ${entry.action}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    if (entry.details.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        entry.details.entries
                                            .map((detail) =>
                                                '${detail.key}: ${detail.value}')
                                            .join('\n'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.mutedForeground,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class _DebugStatusRow extends StatelessWidget {
  const _DebugStatusRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
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
