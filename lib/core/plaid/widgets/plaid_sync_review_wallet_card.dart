import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';

class PlaidSyncReviewWalletCard extends StatelessWidget {
  const PlaidSyncReviewWalletCard({
    super.key,
    required this.account,
    required this.displayBalanceCents,
    required this.isBusy,
    required this.onEdit,
  });

  final BankSyncReviewAccount account;
  final int displayBalanceCents;
  final bool isBusy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 260,
      child: WalletStackCard(
        wallet: WalletEntity(
          id: account.walletId ?? account.bankAccountId,
          userId: '',
          householdId: null,
          name: account.walletName,
          icon: account.walletIcon,
          color: account.walletColor,
          currency: account.currency,
          openingBalanceCents: account.openingBalanceCents,
          goalAmountCents: account.goalAmountCents,
          isDefault: account.isDefault,
          isSystem: false,
          isArchived: false,
          currentBalanceCents: displayBalanceCents,
        ),
        currencyCode: account.currency,
        displayBalanceCents: displayBalanceCents,
        isExpanded: true,
        subtitle: account.displayName,
        showBalanceChevron: false,
        headerAction: TextButton(
          onPressed: isBusy ? null : onEdit,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.foreground,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: colorScheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(
            context.l10n.edit,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        metadataChips: [
          _WalletMetaChip(label: account.currency),
          if (account.subtype != null) _WalletMetaChip(label: account.subtype!),
          if (account.isDefault) _WalletMetaChip(label: context.l10n.primary),
        ],
      ),
    );
  }
}

class _WalletMetaChip extends StatelessWidget {
  const _WalletMetaChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
