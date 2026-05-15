import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/profile/data/email_import_settings_service.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class EmailImportSettingsPage extends HookConsumerWidget {
  const EmailImportSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final service = useMemoized(() => EmailImportSettingsService());
    final settings = useState<EmailImportSettings?>(
        EmailImportSettings.disabled(defaultEmail: authState.email));
    final isLoading = useState(true);
    final isSaving = useState(false);
    final pendingDeleteEmail = useState<String?>(null);

    final householdsAsync = authState.uid.isNotEmpty
        ? ref.watch(userHouseholdsProvider(authState.uid))
        : const AsyncValue<List<Household>>.data([]);
    final selectedScopeHouseholdId =
        settings.value?.scopeId == 'personal' ? null : settings.value?.scopeId;
    final walletsAsync =
        ref.watch(walletsByHouseholdIdProvider(selectedScopeHouseholdId));

    useEffect(() {
      Future<void> loadSettings() async {
        try {
          settings.value = await service.getSettings();
        } catch (error) {
          if (context.mounted) {
            AppToast.error(context, error.toString());
          }
        } finally {
          isLoading.value = false;
        }
      }

      loadSettings();
      return null;
    }, const []);

    String? resolveDefaultWalletId(List<WalletEntity> wallets) {
      for (final wallet in wallets) {
        if (wallet.isDefault) return wallet.id;
      }
      return wallets.isNotEmpty ? wallets.first.id : null;
    }

    String selectedWalletLabel() {
      return walletsAsync.when(
        data: (wallets) {
          if (wallets.isEmpty) return context.l10n.tapToSet;
          final selectedId = settings.value?.accountId;
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

    Future<void> persistSettings({
      required bool enabled,
      required String scopeId,
      required bool isPortfolio,
      String? accountId,
    }) async {
      isSaving.value = true;
      try {
        settings.value = await service.updateSettings(
          enabled: enabled,
          scopeId: scopeId,
          isPortfolio: isPortfolio,
          accountId: accountId,
        );
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, error.toString());
        }
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> toggleEnabled(bool enabled) async {
      final current = settings.value;
      if (current == null) return;
      await persistSettings(
        enabled: enabled,
        scopeId: current.scopeId,
        isPortfolio: current.isPortfolio,
        accountId: current.accountId,
      );
    }

    Future<void> pickDestinationSpace() async {
      final current = settings.value;
      if (current == null) return;

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
          (household) => MonekoActionSheetAction<Map<String, dynamic>>(
            label: household.name,
            value: {
              'scopeId': household.id,
              'scopeName': household.name,
              'isPortfolio': household.isPortfolio,
            },
            icon: household.isPortfolio
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

      await persistSettings(
        enabled: current.enabled,
        scopeId: result['scopeId'] as String,
        isPortfolio: result['isPortfolio'] as bool,
        accountId: null,
      );
    }

    Future<void> pickDestinationWallet() async {
      final current = settings.value;
      if (current == null) return;

      final wallets = walletsAsync.valueOrNull ?? const <WalletEntity>[];
      if (wallets.isEmpty) return;

      final selected = await MonekoActionSheet.show<WalletEntity?>(
        context: context,
        title: context.l10n.wallet,
        actions: wallets
            .map(
              (wallet) => MonekoActionSheetAction<WalletEntity?>(
                label: wallet.name,
                value: wallet,
                icon: Icons.account_balance_wallet_rounded,
              ),
            )
            .toList(growable: false),
        cancelAction: MonekoActionSheetAction(
          label: context.l10n.cancel,
          value: null,
        ),
      );

      if (selected == null) return;

      await persistSettings(
        enabled: current.enabled,
        scopeId: current.scopeId,
        isPortfolio: current.isPortfolio,
        accountId: selected.id,
      );
    }

    Future<void> addWhitelistEmail() async {
      final result = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.emailFileImportAddSenderTitle,
        description: context.l10n.emailFileImportAddSenderDescription,
        confirmLabel: context.l10n.confirm,
        cancelLabel: context.l10n.cancel,
        inputConfig: MonekoAlertDialogInputConfig(
          placeholder: "name@example.com",
          isRequired: true,
          keyboardType: TextInputType.emailAddress,
          validationPattern: RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$'),
          validationMessage: context.l10n.emailFileImportInvalidEmail,
        ),
      );

      if (result?.confirmed != true) return;

      final normalized = normalizeWhitelistEmail(result?.text ?? '');
      if (normalized == null) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.emailFileImportInvalidEmail);
        }
        return;
      }

      final current = settings.value;
      if (current != null &&
          (normalized == current.defaultEmail.toLowerCase() ||
              current.whitelistEmails
                  .map((entry) => entry.normalizedEmail)
                  .contains(normalized))) {
        if (context.mounted) {
          AppToast.info(context, context.l10n.emailFileImportEmailAlreadyAdded);
        }
        return;
      }

      isSaving.value = true;
      try {
        settings.value = await service.addWhitelistEmail(normalized);
        if (context.mounted) {
          AppToast.success(context, context.l10n.emailFileImportEmailAdded);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, error.toString());
        }
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> removeWhitelistEmail(String email) async {
      final confirmed = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.emailFileImportRemoveSenderTitle,
        description: context.l10n.emailFileImportRemoveSenderDescription(email),
        confirmLabel: context.l10n.delete,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );

      if (confirmed?.confirmed != true) return;

      pendingDeleteEmail.value = email;
      try {
        settings.value = await service.removeWhitelistEmail(email);
        if (context.mounted) {
          AppToast.success(context, context.l10n.emailFileImportEmailRemoved);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, error.toString());
        }
      } finally {
        pendingDeleteEmail.value = null;
      }
    }

    Future<void> copyInboundAddress() async {
      await Clipboard.setData(
        const ClipboardData(text: emailImportInboundAddress),
      );
      if (context.mounted) {
        AppToast.success(context, context.l10n.emailAddressCopied);
      }
    }

    void showHowItWorks() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: colorScheme.sheetBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (modalContext) => _HowItWorksSheet(
          inboundEmail: emailImportInboundAddress,
          onCopyEmail: copyInboundAddress,
        ),
      );
    }

    if (isLoading.value || settings.value == null) {
      return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
          appBar: AdaptiveAppBar(title: context.l10n.emailFileImport),
          body: Container(
            color: colorScheme.appBackground,
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      );
    }

    final current = settings.value!;
    final senderEmails = [
      current.defaultEmail,
      ...current.whitelistEmails.map((entry) => entry.email),
    ];
    final destinationIcon = current.isPortfolio
        ? Icons.business_center_rounded
        : current.scopeId == 'personal'
            ? Icons.person_rounded
            : Icons.group_rounded;

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.emailFileImport),
        body: Material(
          child: Container(
            color: colorScheme.appBackground,
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: getSubPageTopPadding(context) - 20,
                  left: 20,
                  right: 20,
                  bottom: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroIntro(
                      description: context.l10n.emailFileImportDescription,
                      onHowItWorks: showHowItWorks,
                    ),
                    _SettingsGroup(
                      title: context.l10n.setup,
                      children: [
                        _SettingsTile(
                          icon: Icons.power_settings_new_rounded,
                          iconColor: current.enabled
                              ? colorScheme.success
                              : colorScheme.mutedForeground,
                          iconBackgroundColor: colorScheme.muted,
                          title: context.l10n.emailFileImportEnableSwitchTitle,
                          trailing: AdaptiveSwitch(
                            value: current.enabled,
                            onChanged: isSaving.value ? null : toggleEnabled,
                          ),
                        ),
                        _SettingsTile(
                          icon: destinationIcon,
                          iconColor: colorScheme.foreground,
                          iconBackgroundColor: colorScheme.muted,
                          title: context.l10n.defaultSpace,
                          subtitle: current.scopeName,
                          enabled: current.enabled,
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.mutedForeground,
                            size: 20,
                          ),
                          onTap: current.enabled && !isSaving.value
                              ? pickDestinationSpace
                              : null,
                        ),
                        _SettingsTile(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: colorScheme.foreground,
                          iconBackgroundColor: colorScheme.muted,
                          title: context.l10n.defaultWallet,
                          subtitle: selectedWalletLabel(),
                          enabled: current.enabled,
                          trailing: walletsAsync.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.mutedForeground,
                                  size: 20,
                                ),
                          onTap: current.enabled && !isSaving.value
                              ? pickDestinationWallet
                              : null,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    _SettingsGroup(
                      title: context.l10n.forwarding,
                      children: [
                        _SettingsTile(
                          icon: Icons.alternate_email_rounded,
                          iconColor: colorScheme.foreground,
                          iconBackgroundColor: colorScheme.muted,
                          title: context.l10n.forwardingEmail,
                          subtitle: emailImportInboundAddress,
                          trailing: IconButton(
                            onPressed: copyInboundAddress,
                            icon: Icon(
                              Icons.copy_rounded,
                              color: colorScheme.mutedForeground,
                              size: 20,
                            ),
                            tooltip: context.l10n.copyLink,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.attach_file_rounded,
                          iconColor: colorScheme.foreground,
                          iconBackgroundColor: colorScheme.muted,
                          title: context.l10n.supportedFiles,
                          subtitle: context.l10n.supportedFileTypes,
                          showDivider: false,
                        ),
                      ],
                    ),
                    if (current.enabled) ...[
                      const SizedBox(height: 36),
                      _SettingsGroup(
                        title: context.l10n.emailFileImportAllowedSenders,
                        children: [
                          _SenderEmailColumn(
                            emails: senderEmails,
                            removableEmails: current.whitelistEmails,
                            pendingDeleteEmail: pendingDeleteEmail.value,
                            onRemoveEmail: removeWhitelistEmail,
                          ),
                          _AddSenderRow(
                            onPressed:
                                isSaving.value ? null : addWhitelistEmail,
                            label: context.l10n.add,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 36),
                    const _PrivacyFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({
    required this.description,
    required this.onHowItWorks,
  });

  final String description;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.homeCardShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              color: colorScheme.foreground,
              size: 38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onHowItWorks,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.homeCardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.howItWorksTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.help_outline,
                      size: 14,
                      color: colorScheme.foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportAddressCard extends StatelessWidget {
  const _ImportAddressCard({
    required this.email,
    required this.onCopy,
  });

  final String email;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: colorScheme.inputBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              email,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onCopy,
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: colorScheme.mutedForeground,
            ),
            tooltip: context.l10n.copyLink,
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.homeCardShadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
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

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveForeground =
        enabled ? colorScheme.foreground : colorScheme.mutedForeground;
    final effectiveSubtitle =
        enabled ? colorScheme.mutedForeground : colorScheme.mutedForeground;
    final effectiveIconColor =
        enabled ? iconColor : colorScheme.mutedForeground;
    final effectiveIconBackground =
        enabled ? iconBackgroundColor : colorScheme.muted;

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
                color: effectiveIconBackground,
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
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: effectiveSubtitle,
                        height: 1.25,
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
              color: colorScheme.border,
            ),
          ),
      ],
    );
  }
}

class _SenderEmailColumn extends StatelessWidget {
  const _SenderEmailColumn({
    required this.emails,
    required this.removableEmails,
    required this.pendingDeleteEmail,
    required this.onRemoveEmail,
  });

  final List<String> emails;
  final List<EmailImportWhitelistEntry> removableEmails;
  final String? pendingDeleteEmail;
  final ValueChanged<String> onRemoveEmail;

  @override
  Widget build(BuildContext context) {
    final removableLookup = {
      for (final entry in removableEmails) entry.email: entry,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final email in emails) ...[
          _SenderEmailLine(
            email: email,
            isBusy: pendingDeleteEmail == email,
            canRemove: removableLookup.containsKey(email),
            onRemove: () => onRemoveEmail(email),
          ),
          if (email != emails.last)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(context).colorScheme.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _SenderEmailLine extends StatelessWidget {
  const _SenderEmailLine({
    required this.email,
    required this.canRemove,
    required this.isBusy,
    required this.onRemove,
  });

  final String email;
  final bool canRemove;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              email,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.foreground,
                height: 1.25,
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: isBusy ? null : onRemove,
              icon: isBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.mutedForeground,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.close_rounded,
                      color: colorScheme.mutedForeground,
                    ),
              tooltip: context.l10n.emailFileImportRemoveSenderTitle,
            ),
        ],
      ),
    );
  }
}

class _AddSenderRow extends StatelessWidget {
  const _AddSenderRow({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              size: 20,
              color: onPressed == null
                  ? colorScheme.mutedForeground
                  : colorScheme.foreground,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: onPressed == null
                    ? colorScheme.mutedForeground
                    : colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
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
                  color: colorScheme.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
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
        ],
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 20,
            color: colorScheme.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.privacyFooterMessage,
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

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet({
    required this.inboundEmail,
    required this.onCopyEmail,
  });

  final String inboundEmail;
  final VoidCallback onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.howItWorksTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.howItWorksSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 18),
          _ImportAddressCard(
            email: inboundEmail,
            onCopy: onCopyEmail,
          ),
          const SizedBox(height: 18),
          _HowItWorksCard(
            step: 1,
            title: context.l10n.addApprovedSender,
            description: context.l10n.addApprovedSenderDescription,
          ),
          const SizedBox(height: 18),
          _HowItWorksCard(
            step: 2,
            title: context.l10n.forwardReceiptEmail,
            description: context.l10n.forwardReceiptEmailDescription,
          ),
          const SizedBox(height: 12),
          _HowItWorksCard(
            step: 3,
            title: context.l10n.processAutomatically,
            description: context.l10n.processAutomaticallyDescription,
          ),
          const SizedBox(height: 12),
          _HowItWorksCard(
            step: 4,
            title: context.l10n.getNotifiedWhenReady,
            description: context.l10n.getNotifiedWhenReadyDescription,
          ),
        ],
      ),
    );
  }
}
