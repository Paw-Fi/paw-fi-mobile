import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/services/wallet_capture_service.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';

class IosWalletCapturePage extends HookConsumerWidget {
  const IosWalletCapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);

    // Local state
    final config = useState<WalletCaptureConfig>(WalletCaptureConfig.disabled);
    final isLoading = useState(true);
    final isSyncing = useState(false);

    // Load households
    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);

    // Load config on mount
    useEffect(() {
      Future<void> loadConfig() async {
        try {
          final loaded = await WalletCaptureService.instance.getConfig();
          config.value = loaded;
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
        await SiriShortcutAuthService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: session?.accessToken,
          refreshToken: session?.refreshToken,
          userId: session?.user.id,
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

    Future<void> toggleEnabled(bool enabled) async {
      final updated = config.value.copyWith(enabled: enabled);
      config.value = updated;
      try {
        await WalletCaptureService.instance.setConfig(updated);
      } catch (e) {
        config.value = config.value.copyWith(enabled: !enabled);
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

    if (isLoading.value) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: 'Wallet Link'),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Wallet Link'),
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding:  EdgeInsets.fromLTRB(16, 16+getSubPageTopPadding(context),16,16),
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
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      material.Text(
                        'Wallet Link',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      material.Text(
                        'Connect Apple Wallet to Moneko so Apple Pay transactions can be logged into your chosen space automatically.',
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
                              'Enable Wallet Link',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          AdaptiveSwitch(
                            value: config.value.enabled,
                            onChanged: (v) => toggleEnabled(v),
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

                // ─── Connect ───
                _SectionTitle(title: 'Connect'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        'Tap the button below to sync your credentials and open the Shortcuts app. You\'ll need to create an automation that uses the "Log Wallet Transaction" action.',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _PrimaryButton(
                          onPressed: isSyncing.value ? null : openShortcuts,
                          icon: Icons.launch_rounded,
                          label: isSyncing.value
                              ? 'Syncing...'
                              : 'Open Apple Shortcuts',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _SecondaryButton(
                          onPressed: isSyncing.value ? null : syncCredentials,
                          icon: Icons.sync_rounded,
                          label: 'Sync Credentials Only',
                        ),
                      ),
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
                        title: 'Create an Automation',
                        description:
                            'In the Apple Shortcuts app, tap the Automations tab, then tap "+" to create a new Personal Automation.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 2,
                        title: 'Choose "Transaction" Trigger',
                        description:
                            'Select "Transaction" as the trigger type. You can choose to run it for all cards or filter by a specific card in your Wallet.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 3,
                        title: 'Add the Moneko Action',
                        description:
                            'Tap "New Blank Automation", then search for "Log Wallet Transaction" in the actions list. Select it to add it to your automation.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 4,
                        title: 'Enable "Run Immediately"',
                        description:
                            'Important: Turn on "Run Immediately" (or "Run Without Asking") so the automation runs silently in the background without requiring confirmation each time.',
                      ),
                      SizedBox(height: 16),
                      _StepItem(
                        step: 5,
                        title: 'You\'re All Set!',
                        description:
                            'Every Apple Pay transaction will now be automatically logged in Moneko. AI will categorize each transaction based on the merchant name.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
                          'Only you can access it. Moneko never sells or shares your financial data.',
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
        border:
            isDarkMode ? Border.all(color: colorScheme.surfaceBorder) : null,
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
