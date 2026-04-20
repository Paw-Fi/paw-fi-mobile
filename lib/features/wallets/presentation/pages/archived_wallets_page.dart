import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class ArchivedWalletsPage extends ConsumerWidget {
  const ArchivedWalletsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final archivedAsync = ref.watch(archivedScopedAccountsProvider);
    final actions = ref.watch(walletActionsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);

    Future<void> onRestore(WalletEntity wallet) async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.restoreWallet,
        description: context.l10n.restoreWalletDescription,
        confirmLabel: context.l10n.restore,
        cancelLabel: context.l10n.cancel,
      );
      if (confirm?.confirmed != true || !context.mounted) return;

      try {
        await actions.restoreAccount(wallet.id);
        if (!context.mounted) return;
        AppToast.success(context, context.l10n.walletRestored);
      } catch (error) {
        if (!context.mounted) return;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.archivedWallets),
      ),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return Center(
              child: Center(
                child: Text(
                  context.l10n.noWalletsYetAddFirst,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArchivedAccountCard(
                  wallet: wallet,
                  currencyCode: selectedCurrencyCode,
                  onRestore: () => onRestore(wallet),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArchivedAccountCard extends StatelessWidget {
  const _ArchivedAccountCard({
    required this.wallet,
    required this.currencyCode,
    required this.onRestore,
  });

  final WalletEntity wallet;
  final String currencyCode;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = wallet.currentBalanceCents / 100.0;
    final mutedSurface = colorScheme.muted.withValues(alpha: 0.35);

    final walletColorRaw = wallet.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseWalletColor(wallet.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      walletColorRaw,
      colorScheme,
      hasCustomColor: wallet.color.toUpperCase() != '#6B7280',
    );

    return Opacity(
      opacity: 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: mutedSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolveWalletIcon(wallet.icon),
                  color: colorScheme.mutedForeground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRestore,
                child: Text(context.l10n.restore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
