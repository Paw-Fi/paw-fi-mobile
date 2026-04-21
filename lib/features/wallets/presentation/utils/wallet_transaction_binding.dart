import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

String? resolveDefaultWalletId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault && !wallet.isArchived) {
      return wallet.id;
    }
  }

  for (final wallet in wallets) {
    if (wallet.isSystem && !wallet.isArchived) {
      return wallet.id;
    }
  }

  for (final wallet in wallets) {
    if (!wallet.isArchived) {
      return wallet.id;
    }
  }

  return null;
}

String? resolveLegacyWalletId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isSystem &&
        !wallet.isArchived &&
        wallet.name.trim().toLowerCase() == 'spending') {
      return wallet.id;
    }
  }

  for (final wallet in wallets) {
    if (wallet.isSystem && !wallet.isArchived) {
      return wallet.id;
    }
  }

  return resolveDefaultWalletId(wallets);
}

String? resolveTransactionWalletId({
  required ExpenseEntry transaction,
  required List<WalletEntity> wallets,
}) {
  final raw = transaction.walletId?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }

  return resolveLegacyWalletId(wallets);
}
