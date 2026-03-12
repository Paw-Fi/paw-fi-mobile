import 'package:flutter/material.dart';
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
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

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
          appBar: const AdaptiveAppBar(title: 'Wallet Link'),
          body: Container(
            color: colorScheme.appBackground,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ));
    }

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Wallet Link'),
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
                        _SettingsGroup(
                          title: 'Configuration',
                          children: [
                            _SettingsTile(
                              icon: Icons.power_settings_new_rounded,
                              iconColor: Colors.white,
                              iconBackgroundColor: config.value.enabled
                                  ? colorScheme.success
                                  : colorScheme.mutedForeground,
                              title: 'Enable Wallet Link',
                              trailing: AdaptiveSwitch(
                                value: config.value.enabled,
                                onChanged: toggleEnabled,
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
                        _buildHowItWorks(colorScheme),
                        const SizedBox(height: 36),
                        _buildPrivacyFooter(colorScheme),
                        const SizedBox(
                            height: 80), // Extra padding for bottom bar
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context, colorScheme, isSyncing.value,
                    openShortcuts, syncCredentials),
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
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Wallet Link',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect Apple Wallet to Moneko so Apple Pay transactions can be logged into your chosen space automatically.',
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
          icon: Icons.auto_awesome_rounded,
          title: 'Create an Automation',
          description:
              'In the Shortcuts app, create a new Personal Automation with a "Transaction" trigger.',
        ),
        const _FeatureItem(
          icon: Icons.add_circle_outline_rounded,
          title: 'Add the Moneko Action',
          description:
              'Search for "Log Wallet Transaction" in the actions list and add it to your automation.',
        ),
        const _FeatureItem(
          icon: Icons.bolt_rounded,
          title: 'Run Immediately',
          description:
              'Turn on "Run Immediately" so the automation runs silently without asking.',
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
      bool isSyncing, VoidCallback onOpen, VoidCallback onSync) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: PrimaryAdaptiveButton(
                onPressed: isSyncing ? null : onOpen,
                child: isSyncing
                    ? const CircularProgressIndicator.adaptive()
                    : const Text(
                        'Open Apple Shortcuts',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: isSyncing ? null : onSync,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sync Credentials Only',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
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
