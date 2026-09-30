import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/bank_account.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/wallet_details_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _WalletDetailsAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

class _WalletDetailsScopedWallets extends ScopedWalletsNotifier {
  _WalletDetailsScopedWallets(this.wallet);

  final WalletEntity wallet;

  @override
  Future<List<WalletEntity>> build() async => [wallet];

  @override
  Future<List<WalletEntity>> refreshFromNetwork() async => [wallet];
}

class _WalletDetailsDataService implements WalletsDataService {
  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async =>
      WalletsHistorySummary(
        availableMonths: [query.currentMonthStart],
        netWorthSeries: [
          WalletNetWorthPoint(
            monthStart: query.currentMonthStart,
            netWorthCents: 0,
          ),
        ],
      );

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async =>
      WalletsMonthSnapshot(
        monthStart: query.monthStart,
        monthEndExclusive: DateTime(
          query.monthStart.year,
          query.monthStart.month + 1,
          1,
        ),
        incomeTotalCents: 0,
        spentTotalCents: 0,
        netWorthCents: 0,
        walletBalances: const {'wallet-1': 0},
      );
}

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
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: const AsyncData<List<BankAccount>>([account]),
        bankConnectionsAsync: const AsyncLoading<List<BankConnection>>(),
      ),
      WalletBankDataState.loading,
    );
    expect(
      resolveWalletBankDataState(
        hasLinkedBankAccount: true,
        bankAccountsAsync: const AsyncData<List<BankAccount>>([account]),
        bankConnectionsAsync: AsyncError<List<BankConnection>>(
          StateError('connection read failed'),
          StackTrace.empty,
        ),
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

  testWidgets(
      'mounted wallet keeps bank state checking until both reads resolve',
      (tester) async {
    const wallet = WalletEntity(
      id: 'wallet-1',
      userId: 'user-1',
      householdId: null,
      name: 'PayPal',
      icon: 'wallet',
      color: '#6B7280',
      currency: 'USD',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 0,
      hasProviderBalance: true,
      linkedBankAccountId: 'account-1',
    );
    const accounts = <BankAccount>[
      BankAccount(
        id: 'account-1',
        name: 'PayPal',
        bankConnectionId: 'connection-1',
      ),
    ];
    const connections = <BankConnection>[
      BankConnection(
        id: 'connection-1',
        provider: 'plaid',
        itemStatus: 'active',
        itemHealthState: 'healthy',
      ),
    ];

    Future<void> pumpWallet({
      required Key key,
      required Future<List<BankAccount>> accountsFuture,
      required Future<List<BankConnection>> connectionsFuture,
    }) {
      return tester.pumpWidget(ProviderScope(
        key: key,
        overrides: [
          authProvider.overrideWith(_WalletDetailsAuth.new),
          appPreferredTimezoneProvider
              .overrideWith((ref) => 'America/New_York'),
          householdScopeProvider.overrideWithValue(
            const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
          scopedWalletsProvider.overrideWith(
            () => _WalletDetailsScopedWallets(wallet),
          ),
          effectiveScopeWalletsProvider.overrideWith((ref) => const [wallet]),
          walletsDataServiceProvider.overrideWithValue(
            _WalletDetailsDataService(),
          ),
          transactionsRemoteFeedServiceProvider.overrideWithValue(
            const EmptyTransactionsFeedService(),
          ),
          transactionsFeedServiceProvider.overrideWithValue(
            const EmptyTransactionsFeedService(),
          ),
          bankAccountsProvider.overrideWith(
            (ref) => accountsFuture,
          ),
          bankConnectionsProvider.overrideWith(
            (ref) => connectionsFuture,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WalletDetailsPage(wallet: wallet),
        ),
      ));
    }

    final accountsCompleter = Completer<List<BankAccount>>();
    await pumpWallet(
      key: const ValueKey('accounts-loading'),
      accountsFuture: accountsCompleter.future,
      connectionsFuture: Future.value(connections),
    );
    await tester.pump();

    expect(find.text('Checking bank sync...'), findsOneWidget);
    expect(find.text('Bank connection unavailable'), findsNothing);
    accountsCompleter.complete(accounts);
    await tester.pump();
    expect(find.text('Bank connected. Initial sync pending'), findsOneWidget);
    expect(find.text('Bank connection unavailable'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));

    final connectionsCompleter = Completer<List<BankConnection>>();
    await pumpWallet(
      key: const ValueKey('connections-loading'),
      accountsFuture: Future.value(accounts),
      connectionsFuture: connectionsCompleter.future,
    );
    await tester.pump();
    expect(find.text('Checking bank sync...'), findsOneWidget);
    expect(find.text('Bank connection unavailable'), findsNothing);
    connectionsCompleter.complete(connections);
    await tester.pump();
    expect(find.text('Bank connected. Initial sync pending'), findsOneWidget);
    expect(find.text('Bank connection unavailable'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
  });
}
