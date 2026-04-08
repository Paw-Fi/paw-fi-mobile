import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/import/presentation/widgets/import_edit_row_sheet.dart';
import 'package:moneko/features/import/presentation/widgets/import_shared_widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

/// The third wizard step: transaction preview and import trigger.
class PreviewStep extends ConsumerWidget {
  const PreviewStep({
    super.key,
    required this.state,
    required this.lockPersonalTarget,
  });

  final ImportWizardState state;
  final bool lockPersonalTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final importableRows = state.parsedRows
        .where(
            (row) => row.isValid && (!state.skipDuplicates || !row.isDuplicate))
        .length;
    final canImport = importableRows > 0 && !state.isImporting;

    final rowsToDisplay = state.parsedRows;

    // +1 for auto-skip banner when applicable
    final hasAutoSkipBanner = state.didAutoSkipMapping;
    final headerCount = hasAutoSkipBanner ? 4 : 3;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: rowsToDisplay.length + headerCount,
            itemBuilder: (context, index) {
              // Auto-skip banner (shown first when mapping was auto-skipped)
              if (hasAutoSkipBanner && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AutoSkipBanner(
                    onReviewMapping: () => notifier.goBackToMapColumns(),
                  ),
                );
              }

              final adjustedIndex = hasAutoSkipBanner ? index - 1 : index;

              if (adjustedIndex == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildOverviewCard(
                    context,
                    ref,
                    lockPersonalTarget: lockPersonalTarget,
                  ),
                );
              }
              if (adjustedIndex == 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildOptionsCard(context, ref, scheme),
                );
              }
              if (adjustedIndex == 2) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.transactions.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: scheme.mutedForeground,
                    ),
                  ),
                );
              }

              final row = rowsToDisplay[adjustedIndex - 3];
              final isFirst = adjustedIndex == 3;
              final isLast = adjustedIndex == rowsToDisplay.length + 2;

              return TransactionPreviewTile(
                row: row,
                isFirst: isFirst,
                isLast: isLast,
                onTap: state.isImporting
                    ? null
                    : () => _openEditRowSheet(context, ref, row),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.border)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedAdaptiveButton(
                    onPressed: () => notifier.setStep(ImportStep.mapColumns),
                    child: Text(context.l10n.back),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: canImport ? () => notifier.importRows() : null,
                    child: Text(
                      state.isImporting
                          ? context.l10n.importing
                          : '${context.l10n.importConfirm} ($importableRows)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    WidgetRef ref, {
    required bool lockPersonalTarget,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GroupedSectionCard(
      title: context.l10n.summary.toUpperCase(),
      children: [
        lockPersonalTarget
            ? _buildPersonalTargetRow(context, scheme)
            : _buildSpaceSelectorRow(context, ref, scheme),
        _buildFinancialAccountRow(context, ref, scheme),
        MetricRow(
          leftLabel: context.l10n.rows,
          leftValue: '${state.totalRows}',
          rightLabel: context.l10n.valid,
          rightValue: '${state.validRows}',
        ),
        MetricRow(
          leftLabel: context.l10n.errors,
          leftValue: '${state.errorRows}',
          rightLabel: context.l10n.duplicates,
          rightValue: '${state.duplicateRows}',
        ),
      ],
    );
  }

  Widget _buildPersonalTargetRow(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.importInto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.foreground,
              ),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            decoration: BoxDecoration(
              color: scheme.cardSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              'Personal account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceSelectorRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
  ) {
    final notifier = ref.read(importWizardProvider.notifier);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final households = householdsAsync.valueOrNull ?? const [];
    final selectedHouseholdId = state.targetHouseholdId;

    Household? selectedHousehold;
    if (selectedHouseholdId != null) {
      for (final household in households) {
        if (household.id == selectedHouseholdId) {
          selectedHousehold = household;
          break;
        }
      }
    }

    final selectedLabel = selectedHouseholdId == null
        ? userLabel(user, shortenEmail: false)
        : (selectedHousehold?.name ?? context.l10n.forUs);
    final pillLabel = truncateMenuLabel(selectedLabel, maxLength: 18);
    final personalLabel =
        truncateMenuLabel(userLabel(user, shortenEmail: true));

    final items = <AdaptivePopupMenuItem>[
      AdaptivePopupMenuItem(
        label: personalLabel,
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'person.crop.circle.fill'
            : Icons.account_circle,
        value: 'personal',
      ),
      ...households.map(
        (household) => AdaptivePopupMenuItem(
          label: truncateMenuLabel(household.name),
          icon: household.isPortfolio
              ? (PlatformInfo.isIOS26OrHigher()
                  ? 'person.crop.circle.fill'
                  : Icons.person)
              : (PlatformInfo.isIOS26OrHigher()
                  ? 'person.2.fill'
                  : Icons.group),
          value: 'household:${household.id}',
        ),
      ),
    ];

    final selector = AdaptivePopupMenuButton.widget(
      items: items,
      onSelected: (index, item) {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);

        if (item.value == 'personal') {
          notifier.setTargetAccount(householdId: null, isPortfolio: false);
          return;
        }

        if (item.value is String &&
            (item.value as String).startsWith('household:')) {
          final householdId = (item.value as String).split(':').last;
          Household? picked;
          for (final household in households) {
            if (household.id == householdId) {
              picked = household;
              break;
            }
          }
          notifier.setTargetAccount(
            householdId: householdId,
            isPortfolio: picked?.isPortfolio ?? false,
          );
        }
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: scheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 150,
              ),
              child: Text(
                pillLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: scheme.mutedForeground,
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.importInto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.foreground,
              ),
            ),
          ),
          selector,
        ],
      ),
    );
  }

  Widget _buildFinancialAccountRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
  ) {
    final notifier = ref.read(importWizardProvider.notifier);
    final targetHouseholdId = state.targetHouseholdId;
    final accountsAsync =
        ref.watch(walletsByHouseholdIdProvider(targetHouseholdId));
    final allAccounts = accountsAsync.valueOrNull ?? const <WalletEntity>[];
    final accounts = allAccounts
        .where((account) => !account.isArchived)
        .toList(growable: false);

    final selectedAccountId = state.targetAccountId?.trim();
    WalletEntity? selectedAccount;
    if (selectedAccountId != null) {
      for (final account in accounts) {
        if (account.id == selectedAccountId) {
          selectedAccount = account;
          break;
        }
      }
    }

    final hasExplicitSelection =
        selectedAccountId != null && selectedAccountId.isNotEmpty;

    if (accounts.isNotEmpty &&
        selectedAccount == null &&
        !hasExplicitSelection) {
      final preferredAccountId = _resolvePreferredDefaultAccountId(accounts);
      if (preferredAccountId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifier.setTargetFinancialAccount(preferredAccountId);
        });
      }
    }

    final selectedLabel = selectedAccount?.name ?? 'Spending';
    final pillLabel = truncateMenuLabel(selectedLabel, maxLength: 18);

    final items = <AdaptivePopupMenuItem>[
      ...accounts.map(
        (account) => AdaptivePopupMenuItem(
          label: truncateMenuLabel(account.name, maxLength: 26),
          icon: Icons.account_balance_wallet_outlined,
          value: 'account:${account.id}',
        ),
      ),
      AdaptivePopupMenuItem(
        label: context.l10n.createAccount,
        icon: Icons.add_circle_outline_rounded,
        value: 'create_account',
      ),
    ];

    final selector = accountsAsync.when(
      loading: () => Container(
        height: 36,
        width: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        decoration: BoxDecoration(
          color: scheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          'Spending',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.foreground,
          ),
        ),
      ),
      data: (_) => AdaptivePopupMenuButton.widget(
        items: items,
        onSelected: (index, item) {
          HapticFeedback.selectionClick();
          SystemSound.play(SystemSoundType.click);
          if (item.value == 'create_account') {
            _handleCreateAccount(context, ref);
            return;
          }

          final raw = item.value;
          if (raw is String && raw.startsWith('account:')) {
            final accountId = raw.replaceFirst('account:', '').trim();
            notifier.setTargetFinancialAccount(accountId);
          }
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          decoration: BoxDecoration(
            color: scheme.cardSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  pillLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: scheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.wallet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.foreground,
              ),
            ),
          ),
          selector,
        ],
      ),
    );
  }

  Future<void> _handleCreateAccount(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(importWizardProvider.notifier);
    final result = await showCreateEditWalletSheet(context);
    if (result == null) return;

    try {
      final createdId = await notifier.createAccountForTarget(
        name: result.name,
        icon: result.icon,
        color: result.color,
        openingBalanceCents: result.openingBalanceCents,
        goalAmountCents: result.goalAmountCents,
        isDefault: result.isDefault,
      );
      if (createdId != null && createdId.isNotEmpty) {
        notifier.setTargetFinancialAccount(createdId);
      }
      if (context.mounted) {
        AppToast.success(context, context.l10n.save);
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }
  }

  Widget _buildOptionsCard(
      BuildContext context, WidgetRef ref, ColorScheme scheme) {
    final notifier = ref.read(importWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSectionCard(
          title: context.l10n.options.toUpperCase(),
          children: [
            StandardTile(
              leadingIcon: Icons.copy_rounded,
              title: context.l10n.skipDuplicates,
              trailing: AdaptiveSwitch(
                value: state.skipDuplicates,
                onChanged: (value) => notifier.setSkipDuplicates(value),
              ),
            ),
          ],
        ),
        if (state.isImporting) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
        ],
        if (state.importedCount > 0 || state.failedCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${context.l10n.imported}: ${state.importedCount} · ${context.l10n.failed}: ${state.failedCount}',
            style: TextStyle(color: scheme.mutedForeground),
          ),
        ],
      ],
    );
  }

  Future<void> _openEditRowSheet(
    BuildContext context,
    WidgetRef ref,
    ImportParsedRow row,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(importWizardProvider.notifier);
    final result = await MonekoBottomSheet.show<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.sheetBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                color: scheme.sheetBorder.withValues(alpha: 0.4),
              ),
            ),
            child: EditRowSheet(row: row),
          ),
        );
      },
    );

    if (result == 'delete') {
      notifier.deleteParsedRow(row.index);
    } else if (result is ImportParsedRow) {
      notifier.updateParsedRow(result);
    }
  }
}

String? _resolvePreferredDefaultAccountId(List<WalletEntity> accounts) {
  for (final account in accounts) {
    if (account.name.trim().toLowerCase() == 'spending') {
      return account.id;
    }
  }
  for (final account in accounts) {
    if (account.isDefault) {
      return account.id;
    }
  }
  return accounts.isNotEmpty ? accounts.first.id : null;
}

/// Banner shown when the map-columns step was auto-skipped due to high
/// confidence auto-mapping.
class _AutoSkipBanner extends StatelessWidget {
  const _AutoSkipBanner({required this.onReviewMapping});

  final VoidCallback onReviewMapping;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.successSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.successBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.importAutoMappedBanner,
              style: TextStyle(
                fontSize: 13,
                color: scheme.success,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReviewMapping,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                context.l10n.importReviewMapping,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single transaction row in the preview list.
class TransactionPreviewTile extends StatelessWidget {
  const TransactionPreviewTile({
    super.key,
    required this.row,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final ImportParsedRow row;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isError = row.errors.isNotEmpty;
    final isDuplicate = row.isDuplicate;

    final amount = (row.amountCents ?? 0) / 100.0;
    final isIncome = (row.type ?? '').toLowerCase() == 'income';

    return Container(
      decoration: BoxDecoration(
        color: scheme.homeCardSurface,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        border: Border.all(
          color: scheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: scheme.homeCardShadow,
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: TransactionListTile(
              category: row.category ?? 'uncategorized',
              title: row.description?.isNotEmpty == true
                  ? row.description!
                  : (row.category ?? 'Uncategorized'),
              date: row.date,
              amount: amount,
              currency: row.currency ?? 'USD',
              isIncome: isIncome,
              onTap: onTap,
              dense: true,
              trailingWidget: isError
                  ? StatusBadge(
                      label: _issueLabel(row),
                      color: scheme.errorAccent,
                      backgroundColor: scheme.errorSurface,
                    )
                  : isDuplicate
                      ? StatusBadge(
                          label: _duplicateLabel(row),
                          color: scheme.warning,
                          backgroundColor: scheme.warningSurface,
                        )
                      : null,
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: scheme.border.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns a specific label for the first structured issue on the row,
  /// falling back to generic "Invalid" if no [RowIssue] is present.
  // TODO: wire to l10n once ARB keys are added
  static String _issueLabel(ImportParsedRow row) {
    if (row.issues.isEmpty) return 'Invalid';
    switch (row.issues.first) {
      case RowIssue.invalidDate:
        return 'Bad date';
      case RowIssue.invalidAmount:
        return 'Bad amount';
      case RowIssue.missingCurrency:
        return 'No currency';
      case RowIssue.unknownType:
        return 'No type';
      case RowIssue.lowConfidenceMapping:
        return 'Low confidence';
      case RowIssue.duplicateInFile:
      case RowIssue.duplicateInDb:
        return 'Duplicate';
    }
  }

  /// Returns a specific duplicate badge label distinguishing in-file from
  /// in-database duplicates.
  // TODO: wire to l10n once ARB keys are added
  static String _duplicateLabel(ImportParsedRow row) {
    switch (row.duplicateReason) {
      case DuplicateReason.inFile:
        return 'Dupe (file)';
      case DuplicateReason.inDb:
        return 'Dupe (existing)';
      case DuplicateReason.none:
        return 'Duplicate';
    }
  }
}

/// A small pill badge showing a row's validation status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
