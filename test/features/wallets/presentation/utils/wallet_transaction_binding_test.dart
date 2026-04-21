import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transaction_binding.dart';

WalletEntity _wallet({
  required String id,
  required String name,
  required bool isDefault,
  required bool isSystem,
}) {
  return WalletEntity(
    id: id,
    userId: 'user-1',
    householdId: null,
    name: name,
    icon: 'wallet',
    color: '#6B7280',
    openingBalanceCents: 0,
    goalAmountCents: null,
    isDefault: isDefault,
    isSystem: isSystem,
    isArchived: false,
    currentBalanceCents: 0,
  );
}

ExpenseEntry _transaction({String? accountId}) {
  return ExpenseEntry(
    id: 'expense-1',
    date: DateTime(2026, 4, 6),
    amountCents: 1500,
    currency: 'USD',
    createdAt: DateTime(2026, 4, 6),
    walletId: accountId,
  );
}

void main() {
  group('resolveTransactionWalletId', () {
    test(
        'pins legacy null-account transactions to Spending instead of the current default wallet',
        () {
      final wallets = [
        _wallet(
          id: 'spending-wallet',
          name: 'Spending',
          isDefault: false,
          isSystem: true,
        ),
        _wallet(
          id: 'wallet-b',
          name: 'Wallet B',
          isDefault: true,
          isSystem: false,
        ),
      ];

      final resolvedWalletId = resolveTransactionWalletId(
        transaction: _transaction(),
        wallets: wallets,
      );

      expect(resolvedWalletId, 'spending-wallet');
    });

    test(
        'prefers the Spending system wallet when multiple system wallets exist',
        () {
      final wallets = [
        _wallet(
          id: 'reserve-wallet',
          name: 'Reserve',
          isDefault: false,
          isSystem: true,
        ),
        _wallet(
          id: 'spending-wallet',
          name: 'Spending',
          isDefault: false,
          isSystem: true,
        ),
      ];

      final resolvedWalletId = resolveTransactionWalletId(
        transaction: _transaction(),
        wallets: wallets,
      );

      expect(resolvedWalletId, 'spending-wallet');
    });

    test('keeps an explicitly assigned wallet id unchanged', () {
      final wallets = [
        _wallet(
          id: 'spending-wallet',
          name: 'Spending',
          isDefault: true,
          isSystem: true,
        ),
      ];

      final resolvedWalletId = resolveTransactionWalletId(
        transaction: _transaction(accountId: 'wallet-c'),
        wallets: wallets,
      );

      expect(resolvedWalletId, 'wallet-c');
    });

    test(
        'falls back to the current default when no active system wallet exists',
        () {
      final wallets = [
        _wallet(
          id: 'wallet-b',
          name: 'Wallet B',
          isDefault: true,
          isSystem: false,
        ),
      ];

      final resolvedWalletId = resolveTransactionWalletId(
        transaction: _transaction(),
        wallets: wallets,
      );

      expect(resolvedWalletId, 'wallet-b');
    });
  });
}
