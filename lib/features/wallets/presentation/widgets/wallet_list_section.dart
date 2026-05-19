import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_card.dart';

class WalletListSection extends StatelessWidget {
  const WalletListSection({
    super.key,
    required this.wallets,
    required this.currencyCode,
    required this.onEdit,
    required this.onArchive,
    required this.onSetDefault,
    required this.onAdjustBalance,
    this.walletBalances = const <String, int>{},
  });

  final List<WalletEntity> wallets;
  final String currencyCode;
  final Map<String, int> walletBalances;
  final ValueChanged<WalletEntity> onEdit;
  final ValueChanged<WalletEntity> onArchive;
  final ValueChanged<WalletEntity> onSetDefault;
  final ValueChanged<WalletEntity> onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(context.l10n.noWalletsYetAddFirst)),
      );
    }

    return ListView.builder(
      itemCount: wallets.length,
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        return WalletCard(
          wallet: wallet,
          currencyCode: currencyCode,
          displayBalanceCents: walletBalances[wallet.id],
          onTap: () => onEdit(wallet),
          onArchive: () => onArchive(wallet),
          onSetDefault: () => onSetDefault(wallet),
          onAdjustBalance: () => onAdjustBalance(wallet),
        );
      },
    );
  }
}
