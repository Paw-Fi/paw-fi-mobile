import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/services/wallet_capture_service.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/profile/presentation/widgets/wallet_sync_setup_sheet.dart';

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
    // The PK of the user's user_contacts row — used for targeted updates.
    final contactId = useState<String?>(null);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);

    // Load config on mount — merges iOS native config with Supabase flag.
    useEffect(() {
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

      loadConfig();
      return null;
    }, []);

    Future<void> syncCredentials() async {
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
              'Sign in again to sync wallet capture credentials.',
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

    Future<void> openShortcuts() async {
      await syncCredentials();
      if (!context.mounted) return;

      try {
        final launched = await launchUrl(
          Uri.parse('shortcuts://'),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          AppToast.error(context, 'Could not open Shortcuts app');
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, 'Could not open Shortcuts app');
        }
      }
    }

    void showSetupSheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
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

      try {
        // Write to iOS native layer.
        debugPrint('[WalletCapture] Writing to iOS native...');
        await WalletCaptureService.instance.setConfig(updated);
        debugPrint('[WalletCapture] iOS native write succeeded');

        // Write to Supabase via the update-wallet-capture-setting edge function
        // (service role bypass RLS — same pattern as update-preferred-currency).
        debugPrint('[WalletCapture] Calling edge function...');
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
            '[WalletCapture] Edge function OK — contactId=${contactId.value}');
      } catch (e, st) {
        debugPrint('[WalletCapture] toggleEnabled error: $e');
        debugPrint('[WalletCapture] Stack trace: $st');
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
        await WalletCaptureService.instance.setConfig(updated);
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, 'Failed to update destination');
        }
      }
    }

    if (isLoading.value) {
      return AdaptiveScaffold(
          appBar: const AdaptiveAppBar(title: 'Apple Pay Integration'),
          body: Container(
            color: colorScheme.appBackground,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ));
    }

    final cardDecoration = BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: isDark ? Border.all(color: colorScheme.surfaceBorder) : null,
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );

    final isEnabled = config.value.enabled;

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(
        title: 'Apple Pay Integration',
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
                  'Automatically track Apple Pay purchases and sync them to your account.',
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
                            'Log Transactions To',
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
                                    : colorScheme.surfaceVariant
                                        .withOpacity(0.3),
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
                                        'Turn On Apple Pay Integration',
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
                                  'Your transactions are added automatically',
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: PrimaryAdaptiveButton(
                            onPressed: showSetupSheet,
                            child: const Text(
                              'Set Up Apple Pay Sync',
                              style: TextStyle(
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
                        'Your transaction data is stored securely in your account and is never sold or shared with third parties.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
