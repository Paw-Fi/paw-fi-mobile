import 'package:flutter/material.dart';
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
  });

  final List<WalletEntity> wallets;
  final String currencyCode;
  final ValueChanged<WalletEntity> onEdit;
  final ValueChanged<WalletEntity> onArchive;
  final ValueChanged<WalletEntity> onSetDefault;
  final ValueChanged<WalletEntity> onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No wallets yet. Add your first wallet.')),
      );
    }

    return ListView.builder(
      itemCount: wallets.length,
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        return WalletCard(
          wallet: wallet,
          currencyCode: currencyCode,
          onTap: () => onEdit(wallet),
          onArchive: () => onArchive(wallet),
          onSetDefault: () => onSetDefault(wallet),
          onAdjustBalance: () => onAdjustBalance(wallet),
        );
      },
    );
  }
}
