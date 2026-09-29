import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/bank_account.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/wallets/presentation/pages/wallet_details_page.dart';

void main() {
  const account = BankAccount(id: 'account-1', name: 'PayPal');
  const connection = BankConnection(id: 'connection-1');

  test('bank data resolution distinguishes loading and error from disconnected',
      () {
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: const AsyncLoading<List<BankAccount>>(),
        bankConnectionsAsync:
            const AsyncData<List<BankConnection>>([connection]),
      ),
      WalletBankDataState.loading,
    );
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: AsyncError<List<BankAccount>>(
          StateError('account read failed'),
          StackTrace.empty,
        ),
        bankConnectionsAsync:
            const AsyncData<List<BankConnection>>([connection]),
      ),
      WalletBankDataState.unavailable,
    );
  });

  test('bank data resolution keeps cached values during refresh or failure',
      () {
    final refreshingAccounts = const AsyncLoading<List<BankAccount>>()
        .copyWithPrevious(const AsyncData<List<BankAccount>>([account]));
    final failedConnections = AsyncError<List<BankConnection>>(
      StateError('connection refresh failed'),
      StackTrace.empty,
    ).copyWithPrevious(
      const AsyncData<List<BankConnection>>([connection]),
    );

    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: refreshingAccounts,
        bankConnectionsAsync: failedConnections,
      ),
      WalletBankDataState.ready,
    );
  });

  test('bank data resolution handles unlinked and fully resolved states', () {
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: false,
        bankAccountsAsync: const AsyncLoading<List<BankAccount>>(),
        bankConnectionsAsync: const AsyncLoading<List<BankConnection>>(),
      ),
      WalletBankDataState.notLinked,
    );
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: const AsyncData<List<BankAccount>>([account]),
        bankConnectionsAsync:
            const AsyncData<List<BankConnection>>([connection]),
      ),
      WalletBankDataState.ready,
    );
  });
}
