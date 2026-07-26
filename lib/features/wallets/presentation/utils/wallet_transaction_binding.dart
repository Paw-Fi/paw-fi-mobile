import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

String? resolveDefaultWalletId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault && !wallet.isArchived) {
      return wallet.id;
    }
  }

  return null;
}

String? resolveTransactionWalletId({
  required ExpenseEntry transaction,
  required List<WalletEntity> wallets,
}) {
  final raw = transaction.walletId?.trim();
  if (raw != null && raw.isNotEmpty) {
    for (final wallet in wallets) {
      if (wallet.id == raw) {
        return _walletMatchesCurrency(wallet, transaction.currency)
            ? raw
            : null;
      }
    }
    return raw;
  }

  return null;
}

bool _walletMatchesCurrency(WalletEntity wallet, String? currency) {
  final normalized = currency?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) {
    return true;
  }
  return wallet.currency.trim().toUpperCase() == normalized;
}
