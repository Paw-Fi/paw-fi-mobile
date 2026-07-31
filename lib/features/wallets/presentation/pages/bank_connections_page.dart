import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// Wallet-independent recovery surface.  Its data contract intentionally does
/// not depend on WalletEntity.linkedBankAccountId.
class BankConnectionsPage extends ConsumerWidget {
  const BankConnectionsPage({super.key, this.initialConnectionId});

  final String? initialConnectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(bankConnectionsProvider);
    final cached = connections.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bankConnections)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bankConnectionsProvider.future),
        child: connections.when(
          loading: () => cached == null
              ? const _BankConnectionsSkeleton()
              : _ConnectionList(
                  connections: cached, highlightedId: initialConnectionId),
          error: (error, _) => cached != null
              ? _ConnectionList(
                  connections: cached, highlightedId: initialConnectionId)
              : Center(child: Text(ErrorHandler.getUserFriendlyMessage(error))),
          data: (items) => _ConnectionList(
            connections: items,
            highlightedId: initialConnectionId,
          ),
        ),
      ),
    );
  }
}

class _ConnectionList extends ConsumerWidget {
  const _ConnectionList({required this.connections, this.highlightedId});
  final List<BankConnection> connections;
  final String? highlightedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (connections.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .3),
        Center(child: Text(context.l10n.bankConnectionUnavailable))
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: connections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ConnectionCard(
        connection: connections[index],
        highlighted: connections[index].id == highlightedId,
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.connection, required this.highlighted});
  final BankConnection connection;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final status = connection.isRemoved
        ? context.l10n.bankConnectionRemoved
        : connection.isPendingRemoval
            ? context.l10n.bankConnectionDisconnecting
            : connection.needsReconnect
                ? context.l10n.needsAttention
                : context.l10n.connected;
    Future<void> disconnect() async {
      final result = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.disconnect,
        description: connection.displayName,
        confirmLabel: context.l10n.disconnect,
      );
      if (result?.confirmed != true || !context.mounted) return;
      final fallbackError = context.l10n.couldNotConnectThisBankRightNow;
      try {
        final response =
            await supabase.functions.invoke('plaid-item-control', body: {
          'action': 'remove_item',
          'connectionId': connection.id,
        });
        if (response.status >= 400) {
          throw Exception(response.data is Map
              ? response.data['error']?.toString()
              : fallbackError);
        }
        ref.invalidate(bankConnectionsProvider);
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> recover() async {
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
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: .08)
            : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: highlighted ? colors.primary : colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(connection.displayName,
                    style: Theme.of(context).textTheme.titleMedium)),
            Text(status,
                style: TextStyle(
                    color: connection.needsReconnect
                        ? colors.error
                        : colors.mutedForeground)),
          ]),
          const SizedBox(height: 6),
          Text(connection.householdId == null
              ? context.l10n.personal
              : context.l10n.sharedSpace),
          const SizedBox(height: 4),
          Text(connection.linkedWalletCount == 0
              ? context.l10n.bankConnectionNotAssigned
              : context.l10n
                  .bankConnectionWalletCount(connection.linkedWalletCount)),
          if (connection.roleGuidance != null) ...[
            const SizedBox(height: 10),
            Text(connection.roleGuidance!,
                style: TextStyle(color: colors.mutedForeground)),
          ],
          if (connection.canReconnect ||
              connection.canReviewAccounts ||
              connection.canDisconnect) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (connection.canReconnect &&
                  (connection.needsReconnect ||
                      connection.hasNewAccountsAvailable ||
                      connection.needsFinishSetup))
                FilledButton(
                    onPressed: recover,
                    child: Text(connection.needsFinishSetup
                        ? context.l10n.bankConnectionFinishSetup
                        : connection.hasNewAccountsAvailable
                            ? context.l10n.reviewAccounts
                            : context.l10n.bankConnectionReconnect)),
              if (connection.canDisconnect)
                OutlinedButton(
                    onPressed: disconnect,
                    child: Text(context.l10n.disconnect)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _BankConnectionsSkeleton extends StatelessWidget {
  const _BankConnectionsSkeleton();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          height: 146,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16)),
        ),
      );
}
