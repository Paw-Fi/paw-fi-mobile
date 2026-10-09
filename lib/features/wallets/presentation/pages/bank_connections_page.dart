import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/models/bank_account.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// Wallet-independent recovery and management surface for Plaid connections.
///
/// A connection can contain multiple bank accounts. The backend disconnect
/// operation is intentionally connection-scoped, so this page never presents
/// an account-level disconnect action.
class BankConnectionsPage extends ConsumerWidget {
  const BankConnectionsPage({super.key, this.initialConnectionId});

  final String? initialConnectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(bankConnectionsProvider);
    final accounts = ref.watch(allVisibleBankAccountsProvider);
    final cachedConnections = connections.valueOrNull;
    final isPlaidSupported = isPlaidSupportedTimezone(
      ref.watch(appPreferredTimezoneProvider),
    );
    void goToWallets() {
      ref.read(mainShellTabIndexProvider.notifier).state = 3;
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(walletsAddWalletSheetRequestProvider.notifier).state++;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bankConnections),
        actions: [
          IconButton(
            tooltip: context.l10n.retry,
            onPressed: () {
              ref.invalidate(bankConnectionsProvider);
              ref.invalidate(allVisibleBankAccountsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: connections.when(
        loading: () => cachedConnections == null
            ? const _BankConnectionsSkeleton()
            : _ConnectionContent(
                connections: cachedConnections,
                accounts: accounts.valueOrNull ?? const [],
                highlightedId: initialConnectionId,
                accountsLoading: accounts.isLoading && !accounts.hasValue,
                isPlaidSupported: isPlaidSupported,
                onGoToWallets: goToWallets,
              ),
        error: (error, _) => cachedConnections != null
            ? _ConnectionContent(
                connections: cachedConnections,
                accounts: accounts.valueOrNull ?? const [],
                highlightedId: initialConnectionId,
                errorMessage: ErrorHandler.getUserFriendlyMessage(error),
                accountsLoading: accounts.isLoading && !accounts.hasValue,
                isPlaidSupported: isPlaidSupported,
                onGoToWallets: goToWallets,
              )
            : _BankConnectionsError(
                message: ErrorHandler.getUserFriendlyMessage(error),
                onRetry: () {
                  ref.invalidate(bankConnectionsProvider);
                  ref.invalidate(allVisibleBankAccountsProvider);
                },
              ),
        data: (items) => _ConnectionContent(
          connections: items,
          accounts: accounts.valueOrNull ?? const [],
          highlightedId: initialConnectionId,
          accountsLoading: accounts.isLoading && !accounts.hasValue,
          isPlaidSupported: isPlaidSupported,
          onGoToWallets: goToWallets,
        ),
      ),
    );
  }
}

class _ConnectionContent extends StatelessWidget {
  const _ConnectionContent({
    required this.connections,
    required this.accounts,
    this.highlightedId,
    this.errorMessage,
    this.accountsLoading = false,
    required this.isPlaidSupported,
    required this.onGoToWallets,
  });

  final List<BankConnection> connections;
  final List<BankAccount> accounts;
  final String? highlightedId;
  final String? errorMessage;
  final bool accountsLoading;
  final bool isPlaidSupported;
  final VoidCallback onGoToWallets;

  @override
  Widget build(BuildContext context) {
    final accountsByConnection = <String, List<BankAccount>>{};
    for (final account in accounts) {
      final connectionId = account.bankConnectionId;
      if (connectionId == null || connectionId.trim().isEmpty) continue;
      accountsByConnection
          .putIfAbsent(connectionId, () => <BankAccount>[])
          .add(account);
    }
    return RefreshIndicator(
      onRefresh: () => _refreshConnections(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineMessage(
              icon: Icons.warning_amber_rounded,
              message: errorMessage!,
            ),
          ],
          if (connections.isEmpty)
            _EmptyConnectionsState(
              isPlaidSupported: isPlaidSupported,
              onGoToWallets: onGoToWallets,
            )
          else ...[
            const SizedBox(height: 20),
            for (var index = 0; index < connections.length; index++) ...[
              _ConnectionCard(
                connection: connections[index],
                accounts: accountsByConnection[connections[index].id] ??
                    const <BankAccount>[],
                highlighted: connections[index].id == highlightedId,
                accountsLoading: accountsLoading,
              ),
              if (index != connections.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _refreshConnections(BuildContext context) async {
    final scope = ProviderScope.containerOf(context, listen: false);
    await Future.wait([
      scope.refresh(bankConnectionsProvider.future),
      scope.refresh(allVisibleBankAccountsProvider.future),
    ]);
  }
}

class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard({
    required this.connection,
    required this.accounts,
    required this.highlighted,
    required this.accountsLoading,
  });

  final BankConnection connection;
  final List<BankAccount> accounts;
  final bool highlighted;
  final bool accountsLoading;

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _isSyncing = false;

  BankConnection get connection => widget.connection;
  List<BankAccount> get accounts => widget.accounts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _connectionStatusLabel(context);
    final statusColor = _connectionStatusColor(colors);
    final showRecoveryAction = connection.canReconnect &&
        (connection.needsReconnect ||
            connection.hasNewAccountsAvailable ||
            connection.needsFinishSetup);
    final showSyncAction = connection.canRequestManualRefresh &&
        !connection.isPendingRemoval &&
        !connection.isRemoved;
    final hasActions = showSyncAction ||
        showRecoveryAction ||
        (connection.canDisconnect && !connection.isPendingRemoval);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: widget.highlighted
            ? colors.primary.withValues(alpha: .06)
            : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.highlighted ? colors.primary : colors.outlineVariant,
          width: widget.highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WalletLogoAvatar(
                logoUrl: connection.institutionLogoUrl,
                icon: Icons.account_balance_rounded,
                baseColor: colors.primary,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.displayNameOr(context.l10n.bankConnection),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusPill(label: status, color: statusColor),
                        _ScopePill(
                          label: connection.householdId == null
                              ? context.l10n.personal
                              : context.l10n.sharedSpace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(
            icon: Icons.account_balance_wallet_outlined,
            label: context.l10n.bankAccount,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.accountsLoading
                ? const _AccountRowsSkeleton(key: ValueKey('accounts-loading'))
                : accounts.isEmpty
                    ? _NoAccountsRow(
                        key: const ValueKey('accounts-empty'),
                        count: connection.linkedBankAccountCount,
                      )
                    : _AccountRows(
                        key: const ValueKey('accounts-loaded'),
                        accounts: accounts,
                      ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.wallet_outlined,
                  size: 17, color: colors.mutedForeground),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  connection.linkedWalletCount == 0
                      ? context.l10n.bankConnectionNotAssigned
                      : context.l10n.bankConnectionWalletCount(
                          connection.linkedWalletCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                ),
              ),
            ],
          ),
          if (connection.roleGuidance != null) ...[
            const SizedBox(height: 12),
            _InlineMessage(
              icon: Icons.info_outline_rounded,
              message: connection.roleGuidance!,
            ),
          ],
          if (hasActions) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _ConnectionActions(
              connection: connection,
              showSyncAction: showSyncAction,
              showRecoveryAction: showRecoveryAction,
              isSyncing: _isSyncing,
              onSync: () => _sync(context),
              onRecover: () => _recover(context, ref),
              onDisconnect: () => _disconnect(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  String _connectionStatusLabel(BuildContext context) {
    if (connection.isRemoved) return context.l10n.bankConnectionRemoved;
    if (connection.isPendingRemoval) {
      return context.l10n.bankConnectionDisconnecting;
    }
    if (connection.needsReconnect) return context.l10n.needsAttention;
    return context.l10n.connected;
  }

  Color _connectionStatusColor(ColorScheme colors) {
    if (connection.isRemoved || connection.isPendingRemoval) {
      return colors.mutedForeground;
    }
    if (connection.needsReconnect) return colors.error;
    return colors.primary;
  }

  Future<void> _sync(BuildContext context) async {
    if (_isSyncing) return;
    final remaining = _manualSyncRemaining(connection, DateTime.now().toUtc());
    if (remaining != null) {
      await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.syncUnavailable,
        description: context.l10n.youCannotSyncMoreThanOncePerDay(
          _formatDurationCompact(remaining),
        ),
        confirmLabel: context.l10n.gotIt,
        showCancelButton: false,
      );
      return;
    }

    setState(() => _isSyncing = true);
    showBlockingProcessingDialog(
      context: context,
      message: context.l10n.requestingBankRefresh,
    );
    try {
      final response = await supabase.functions.invoke(
        'plaid-item-control',
        body: {
          'action': 'request_refresh',
          'connectionId': connection.id,
        },
      );
      if (context.mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (response.status >= 400) {
        if (!context.mounted) return;
        final reason = payload['reason']?.toString();
        if (reason == 'cooldown_active') {
          await MonekoAlertDialog.show(
            context: context,
            title: context.l10n.syncUnavailable,
            description: context.l10n.cannotRequestAnotherPlaidRefreshYet,
            confirmLabel: context.l10n.gotIt,
            showCancelButton: false,
          );
        } else if (reason == 'trial_blocked') {
          await MonekoAlertDialog.show(
            context: context,
            title: context.l10n.refreshUnavailable,
            description: context.l10n.manualPlaidRefreshPaidUsersOnly,
            confirmLabel: context.l10n.gotIt,
            showCancelButton: false,
          );
        } else {
          AppToast.error(
            context,
            payload['error']?.toString() ??
                context.l10n.couldNotSyncThisBankRightNow,
          );
        }
        return;
      }

      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(allVisibleBankAccountsProvider);
      if (context.mounted) {
        AppToast.success(context, context.l10n.refreshRequestedPlaidWillNotify);
      }
    } catch (error) {
      if (context.mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _recover(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaidSyncWalkthroughPage(
        connectionId: connection.id,
        targetHouseholdId: connection.householdId,
        flowReason: connection.hasNewAccountsAvailable
            ? 'new_accounts_available'
            : 'reconnect',
      ),
    ));
    ref.invalidate(bankConnectionsProvider);
    ref.invalidate(allVisibleBankAccountsProvider);
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmation = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.disconnectBankQuestion,
      description: context.l10n.disconnectBankDescription,
      confirmLabel: context.l10n.disconnectBank,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );
    if (confirmation?.confirmed != true || !context.mounted) return;

    showBlockingProcessingDialog(
      context: context,
      message: context.l10n.disconnectingBank,
    );
    try {
      final response = await supabase.functions.invoke(
        'plaid-item-control',
        body: {
          'action': 'remove_item',
          'connectionId': connection.id,
          'reason': 'manual_remove',
        },
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (response.status >= 400) {
        final data = response.data;
        throw Exception(data is Map ? data['error']?.toString() : null);
      }

      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(allVisibleBankAccountsProvider);
      if (!context.mounted) return;

      final data = response.data;
      final status = data is Map ? data['status']?.toString() : null;
      if (response.status == 202 || status == 'pending_removal') {
        AppToast.info(context, context.l10n.bankDisconnectQueuedDescription);
      } else {
        AppToast.success(context, context.l10n.bankDisconnectedSyncsDisabled);
      }
    } catch (error) {
      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
    }
  }
}

class _ConnectionActions extends StatelessWidget {
  const _ConnectionActions({
    required this.connection,
    required this.showSyncAction,
    required this.showRecoveryAction,
    required this.isSyncing,
    required this.onSync,
    required this.onRecover,
    required this.onDisconnect,
  });

  final BankConnection connection;
  final bool showSyncAction;
  final bool showRecoveryAction;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onRecover;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (showSyncAction)
          FilledButton.icon(
            onPressed: isSyncing ? null : onSync,
            icon: isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(context.l10n.syncBank),
          ),
        if (showRecoveryAction)
          OutlinedButton.icon(
            onPressed: onRecover,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              connection.needsFinishSetup
                  ? context.l10n.bankConnectionFinishSetup
                  : connection.hasNewAccountsAvailable
                      ? context.l10n.reviewAccounts
                      : context.l10n.bankConnectionReconnect,
            ),
          ),
        if (connection.canDisconnect && !connection.isPendingRemoval)
          OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off_rounded),
            label: Text(context.l10n.disconnectBank),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.mutedForeground),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _AccountRows extends StatelessWidget {
  const _AccountRows({super.key, required this.accounts});

  final List<BankAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

    Widget buildAccountRow(BankAccount account) {
      final meta = _accountMeta(account);
      final name = Expanded(
        child: Text(
          account.displayName,
          maxLines: isLargeText ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );
      if (isLargeText) {
        final leading = Row(
          children: [
            Icon(Icons.credit_card_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 9),
            name,
          ],
        );
        if (meta.isEmpty) return leading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leading,
            Padding(
              padding: const EdgeInsets.only(left: 27, top: 3),
              child: Text(
                meta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          Icon(Icons.credit_card_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 9),
          name,
          if (meta.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              meta,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var index = 0; index < accounts.length; index++) ...[
          buildAccountRow(accounts[index]),
          if (index != accounts.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }

  String _accountMeta(BankAccount account) {
    final parts = <String>[];
    final currency = account.currency?.trim();
    if (currency != null && currency.isNotEmpty) {
      parts.add(currency.toUpperCase());
    }
    final type = account.subtype?.trim().isNotEmpty == true
        ? account.subtype!.trim()
        : account.type?.trim();
    if (type != null && type.isNotEmpty) parts.add(type);
    return parts.join(' · ');
  }
}

class _NoAccountsRow extends StatelessWidget {
  const _NoAccountsRow({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 18, color: colors.mutedForeground),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            count == 0
                ? context.l10n.noSupportedBankAccountsReturned
                : context.l10n.bankConnectionUnavailable,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.mutedForeground,
                ),
          ),
        ),
      ],
    );
  }
}

class _AccountRowsSkeleton extends StatelessWidget {
  const _AccountRowsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: [
        for (var index = 0; index < 2; index++)
          Container(
            height: 18,
            margin: EdgeInsets.only(bottom: index == 0 ? 9 : 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConnectionsState extends StatelessWidget {
  const _EmptyConnectionsState({
    required this.isPlaidSupported,
    required this.onGoToWallets,
  });

  final bool isPlaidSupported;
  final VoidCallback onGoToWallets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 52),
      child: Column(
        children: [
          Image.asset(
            'lib/assets/mascots/moneko-confused.png',
            width: 148,
            height: 148,
            fit: BoxFit.contain,
            semanticLabel: context.l10n.bankConnectionUnavailable,
          ),
          const SizedBox(height: 14),
          Text(
            isPlaidSupported
                ? context.l10n.bankConnectionNotConnectedYet
                : context.l10n.bankConnectionUnavailable,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          if (isPlaidSupported) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.effortlessTrackingDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.mutedForeground,
                    height: 1.35,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGoToWallets,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addWallet),
            ),
          ],
        ],
      ),
    );
  }
}

class _BankConnectionsError extends StatelessWidget {
  const _BankConnectionsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 42, color: colors.mutedForeground),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankConnectionsSkeleton extends StatelessWidget {
  const _BankConnectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < 2; index++)
          Container(
            height: 270,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
      ],
    );
  }
}

Duration? _manualSyncRemaining(BankConnection connection, DateTime nowUtc) {
  final nextEligibleAt = connection.nextManualRefreshEligibleAt?.toUtc() ??
      connection.lastSuccessfulSyncAt?.toUtc().add(const Duration(hours: 24));
  if (nextEligibleAt == null || !nextEligibleAt.isAfter(nowUtc)) return null;
  return nextEligibleAt.difference(nowUtc);
}

String _formatDurationCompact(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 1) return '0m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
