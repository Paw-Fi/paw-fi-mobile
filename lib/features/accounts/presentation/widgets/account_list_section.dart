import 'package:flutter/material.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_card.dart';

class AccountListSection extends StatelessWidget {
  const AccountListSection({
    super.key,
    required this.accounts,
    required this.currencyCode,
    required this.onEdit,
    required this.onArchive,
    required this.onSetDefault,
    required this.onAdjustBalance,
  });

  final List<AccountEntity> accounts;
  final String currencyCode;
  final ValueChanged<AccountEntity> onEdit;
  final ValueChanged<AccountEntity> onArchive;
  final ValueChanged<AccountEntity> onSetDefault;
  final ValueChanged<AccountEntity> onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No accounts yet. Add your first account.')),
      );
    }

    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return AccountCard(
          account: account,
          currencyCode: currencyCode,
          onTap: () => onEdit(account),
          onArchive: () => onArchive(account),
          onSetDefault: () => onSetDefault(account),
          onAdjustBalance: () => onAdjustBalance(account),
        );
      },
    );
  }
}
