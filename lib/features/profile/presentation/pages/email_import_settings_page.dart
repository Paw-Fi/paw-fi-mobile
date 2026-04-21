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
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
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
        AppToast.success(context, 'Email address copied');
      }
    }

    void showHowItWorks() {
      MonekoBottomSheet.show<void>(
        context: context,
        title: context.l10n.howItWorksTitle,
        isScrollControlled: true,
        onClose: () => Navigator.of(context).pop(),
        builder: (_) => _HowItWorksSheet(
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

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.emailFileImport),
        body: Material(
          child: Container(
            color: colorScheme.appBackground,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: getSubPageTopPadding(context) + 16,
                  left: 24,
                  right: 24,
                  bottom: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroIntro(
                      title: context.l10n.emailFileImport,
                      description: context.l10n.emailFileImportDescription,
                      onHowItWorks: showHowItWorks,
                    ),
                    const SizedBox(height: 28),
                    _SettingsSurface(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.emailFileImportEnableSwitchTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context
                                      .l10n.emailFileImportEnableSwitchSubtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.mutedForeground,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          AdaptiveSwitch(
                            value: current.enabled,
                            onChanged: isSaving.value ? null : toggleEnabled,
                          ),
                        ],
                      ),
                    ),
                    if (current.enabled) ...[
                      const SizedBox(height: 22),
                      _SettingsSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                              title: 'Send files here',
                              subtitle: 'Forward bank exports or receipts.',
                            ),
                            const SizedBox(height: 16),
                            _ImportAddressCard(
                              email: emailImportInboundAddress,
                              onCopy: copyInboundAddress,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SettingsSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                              title: 'Save imported transactions to',
                              subtitle: 'Choose the space and wallet once.',
                            ),
                            const SizedBox(height: 18),
                            _MinimalPickerRow(
                              icon: current.isPortfolio
                                  ? Icons.business_center_rounded
                                  : current.scopeId == 'personal'
                                      ? Icons.person_rounded
                                      : Icons.group_rounded,
                              label: context.l10n.destinationSpace,
                              value: current.scopeName,
                              onTap:
                                  isSaving.value ? null : pickDestinationSpace,
                            ),
                            const SizedBox(height: 14),
                            _MinimalPickerRow(
                              icon: Icons.account_balance_wallet_rounded,
                              label: context.l10n.wallet,
                              value: selectedWalletLabel(),
                              onTap:
                                  isSaving.value ? null : pickDestinationWallet,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SettingsSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              title: context.l10n.emailFileImportAllowedSenders,
                              subtitle:
                                  'Only these inboxes can trigger imports.',
                            ),
                            const SizedBox(height: 18),
                            _SenderEmailColumn(
                              emails: senderEmails,
                              removableEmails: current.whitelistEmails,
                              pendingDeleteEmail: pendingDeleteEmail.value,
                              onRemoveEmail: removeWhitelistEmail,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed:
                                    isSaving.value ? null : addWhitelistEmail,
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.foreground,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  context.l10n.emailFileImportAddSender,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    required this.title,
    required this.description,
    required this.onHowItWorks,
  });

  final String title;
  final String description;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colorScheme.foreground,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.mutedForeground,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: onHowItWorks,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.foreground,
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: Text(context.l10n.howItWorksTitle),
        ),
      ],
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.mutedForeground,
            height: 1.35,
          ),
        ),
      ],
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

class _MinimalPickerRow extends StatelessWidget {
  const _MinimalPickerRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 19, color: colorScheme.foreground),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final email in emails) ...[
          _SenderEmailLine(
            email: email,
            isBusy: pendingDeleteEmail == email,
            canRemove: removableLookup.containsKey(email),
            onRemove: () => onRemoveEmail(email),
          ),
          if (email != emails.last) const SizedBox(height: 12),
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

    return Row(
      children: [
        Expanded(
          child: Text(
            email,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImportAddressCard(
            email: inboundEmail,
            onCopy: onCopyEmail,
          ),
          const SizedBox(height: 26),
          const _HowItWorksStep(
            number: '1',
            title: 'Forward a file',
            description:
                'Send a PDF, CSV, or Excel export to the Moneko email address.',
          ),
          const SizedBox(height: 20),
          const _HowItWorksStep(
            number: '2',
            title: 'Moneko reads it',
            description:
                'We extract transactions only when the sender is allowed.',
          ),
          const SizedBox(height: 20),
          const _HowItWorksStep(
            number: '3',
            title: 'Review your imports',
            description:
                'Captured transactions land in your selected space and wallet.',
          ),
          const SizedBox(height: 22),
          Text(
            'Tip: add every sender inbox you use for bank statements.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.muted,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
