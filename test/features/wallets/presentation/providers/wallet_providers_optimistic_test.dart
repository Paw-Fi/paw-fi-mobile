import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RefreshAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'test@example.com');
}

class _StaticScopedWalletsNotifier extends ScopedWalletsNotifier {
  _StaticScopedWalletsNotifier(this.wallets);

  final List<WalletEntity> wallets;

  @override
  Future<List<WalletEntity>> build() async => wallets;

  @override
  Future<List<WalletEntity>> refreshFromNetwork() async => wallets;
}

WalletEntity _wallet(
  String id, {
  String name = 'Spending',
  String currency = 'USD',
  bool hasProviderBalance = false,
  String? linkedBankAccountId,
}) {
  return WalletEntity(
    id: id,
    userId: 'user-1',
    householdId: null,
    name: name,
    icon: 'wallet',
    color: '#6B7280',
    currency: currency,
    openingBalanceCents: 0,
    goalAmountCents: null,
    isDefault: false,
    isSystem: false,
    isArchived: false,
    currentBalanceCents: 0,
    hasProviderBalance: hasProviderBalance,
    linkedBankAccountId: linkedBankAccountId,
  );
}

void main() {
  test(
      'v2 transfer queues idempotent native principals and fee before dispatch',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final response = Completer<http.Response>();
    final requested = Completer<Map<String, dynamic>>();
    await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/create-wallet-transfer')) {
            requested.complete(
                Map<String, dynamic>.from(jsonDecode(request.body) as Map));
            return response.future;
          }
          return http.Response('{}', 200);
        }));
    addTearDown(() => Supabase.instance.dispose());
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final wallets = [
      _wallet('source', currency: 'EUR'),
      _wallet('target', currency: 'USD')
    ];
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_RefreshAuth.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      localDatabaseProvider.overrideWith((ref) async => database),
      effectiveScopeWalletsProvider.overrideWith((ref) => [
            for (final wallet in wallets)
              ref.watch(optimisticScopedAccountsOverridesProvider)[wallet.id] ??
                  wallet,
          ]),
    ]);
    addTearDown(container.dispose);
    final actions = container.read(walletActionsProvider);
    final operation = await actions.createTransfer(
        fromAccountId: 'source',
        toAccountId: 'target',
        amountCents: 10000,
        currency: 'EUR',
        toAmountCents: 11000,
        toCurrency: 'USD',
        exchangeRate: '1.1',
        feeAmountCents: 125,
        // The picker catalog can be older than mounted wallet balances.
        transferWallets: [
          for (final wallet in wallets)
            wallet.copyWith(currentBalanceCents: 999999)
        ],
        date: DateTime(2026, 10, 15));
    final mutation = (await database.getOutboxMutations()).single;
    final body = Map<String, dynamic>.from(
        jsonDecode(mutation.payloadJson)['requestBody'] as Map);
    expect(body['clientRecordId'], mutation.entityId);
    expect(body['transferContractVersion'], 2);
    expect(body['toAmountCents'], 11000);
    expect(body['toCurrency'], 'USD');
    expect(body['feeAmountCents'], 125);
    expect(body['exchangeRate'], '1.1');
    expect(operation.entries, hasLength(3));
    expect(
        container
            .read(optimisticScopedAccountsOverridesProvider)['source']
            ?.currentBalanceCents,
        -10125);
    expect(
        container
            .read(optimisticScopedAccountsOverridesProvider)['target']
            ?.currentBalanceCents,
        11000);
    expect(await requested.future, body);
    final transfer = WalletTransfer(
        id: mutation.entityId,
        fromAccountId: 'source',
        toAccountId: 'target',
        amountCents: 10000,
        currency: 'EUR',
        toAmountCents: 11000,
        toCurrency: 'USD',
        exchangeRate: '1.1',
        feeAmountCents: 125,
        date: DateTime(2026, 10, 15));
    await actions.updateTransfer(
        existingTransfer: transfer,
        fromAccountId: 'source',
        toAccountId: 'target',
        amountCents: 12000,
        currency: 'EUR',
        toAmountCents: 13000,
        toCurrency: 'USD',
        exchangeRate: '1.08333333',
        feeAmountCents: 200,
        date: transfer.date,
        time: null);
    expect(
        container
            .read(optimisticScopedAccountsOverridesProvider)['source']
            ?.currentBalanceCents,
        -12200);
    expect(
        container
            .read(optimisticScopedAccountsOverridesProvider)['target']
            ?.currentBalanceCents,
        13000);
    // The pending edit remains a create dependency and never sends a synthetic ID.
    expect(
        (await database.getOutboxMutations())
            .where((m) => m.status == localMutationStatusQueued),
        hasLength(2));
    response.complete(
        http.Response('{"success":false,"error":"unavailable"}', 503));
    expect(await operation.completion, isNull);
    await pumpEventQueue();
  });

  test('wallet list refresh persists after consuming its cache bypass',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scope = WalletsScopeQuery(
      userId: 'user-1',
      householdId: null,
      selectedCurrency: 'USD',
      currentMonthStart: DateTime(2026, 7),
    );
    final wallets = [_wallet('wallet-1')];
    final cacheKey = walletsListCacheKey(
      userId: scope.userId,
      householdId: scope.householdId,
      selectedCurrency: scope.selectedCurrency,
      selectedCurrencies: scope.normalizedSelectedCurrencies,
      currentMonthStart: scope.currentMonthStart,
    );
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_RefreshAuth.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      walletAuthHeadersProvider
          .overrideWith((ref) => const {'Authorization': 'Bearer test'}),
      walletScopeHouseholdIdProvider.overrideWithValue(null),
      walletsScopeQueryProvider.overrideWithValue(scope),
      walletsByHouseholdIdProvider
          .overrideWith((ref, householdId) async => wallets),
    ]);
    addTearDown(container.dispose);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      cacheKey: wallets,
    };
    container.read(walletsPersistedCacheBypassCountProvider.notifier).state = 1;
    await container.read(scopedWalletsProvider.future);

    await container.read(scopedWalletsProvider.notifier).refreshFromNetwork();

    expect(container.read(walletsPersistedCacheBypassCountProvider), 0);
    expect(prefs.getString(cacheKey), isNotNull);
    expect(container.read(scopedWalletsProvider).requireValue, wallets);
  });

  test('effectiveScopeWalletsProvider overlays and appends optimistic wallets',
      () async {
    final container = ProviderContainer(
      overrides: [
        walletScopeHouseholdIdProvider.overrideWithValue(null),
        walletsScopeQueryProvider.overrideWith(
          (ref) => WalletsScopeQuery(
            userId: 'user-1',
            householdId: null,
            selectedCurrency: 'USD',
            currentMonthStart: DateTime(2026, 7),
          ),
        ),
        scopedWalletsProvider.overrideWith(
          () => _StaticScopedWalletsNotifier([_wallet('wallet-1')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);

    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      'wallet-1': _wallet('wallet-1', name: 'Renamed'),
      'wallet-2': _wallet('wallet-2', name: 'Savings'),
    };

    final wallets = container.read(effectiveScopeWalletsProvider);

    expect(wallets.map((w) => w.id), ['wallet-1', 'wallet-2']);
    expect(wallets.first.name, 'Renamed');
    expect(wallets.last.name, 'Savings');
  });

  test('effectiveScopeWalletsProvider filters optimistic wallets by scope',
      () async {
    const householdWallet = WalletEntity(
      id: 'wallet-household',
      userId: 'user-1',
      householdId: 'household-1',
      name: 'Household',
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 0,
    );
    final container = ProviderContainer(
      overrides: [
        walletScopeHouseholdIdProvider.overrideWithValue(null),
        walletsScopeQueryProvider.overrideWith(
          (ref) => WalletsScopeQuery(
            userId: 'user-1',
            householdId: null,
            selectedCurrency: 'USD',
            currentMonthStart: DateTime(2026, 7),
          ),
        ),
        scopedWalletsProvider.overrideWith(
          () => _StaticScopedWalletsNotifier([_wallet('wallet-personal')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);

    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      householdWallet.id: householdWallet,
    };

    final wallets = container.read(effectiveScopeWalletsProvider);

    expect(wallets.map((w) => w.id), ['wallet-personal']);
  });

  test('effectiveScopeWalletsProvider keeps all included currencies', () async {
    final container = ProviderContainer(
      overrides: [
        walletScopeHouseholdIdProvider.overrideWithValue(null),
        walletsScopeQueryProvider.overrideWith(
          (ref) => WalletsScopeQuery(
            userId: 'user-1',
            householdId: null,
            selectedCurrency: 'USD',
            selectedCurrencies: const ['USD', 'EUR'],
            currentMonthStart: DateTime(2026, 7),
          ),
        ),
        scopedWalletsProvider.overrideWith(
          () => _StaticScopedWalletsNotifier([
            _wallet('wallet-usd'),
            _wallet('wallet-eur', currency: 'EUR'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);

    expect(
      container.read(effectiveScopeWalletsProvider).map((wallet) => wallet.id),
      ['wallet-usd', 'wallet-eur'],
    );
  });

  test('effectiveScopeWalletsProvider excludes non-selected currencies',
      () async {
    final container = ProviderContainer(
      overrides: [
        walletScopeHouseholdIdProvider.overrideWithValue(null),
        walletsScopeQueryProvider.overrideWith(
          (ref) => WalletsScopeQuery(
            userId: 'user-1',
            householdId: null,
            selectedCurrency: 'USD',
            selectedCurrencies: const ['USD'],
            currentMonthStart: DateTime(2026, 7),
          ),
        ),
        scopedWalletsProvider.overrideWith(
          () => _StaticScopedWalletsNotifier([
            _wallet('wallet-usd'),
            _wallet('wallet-eur', currency: 'EUR'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);

    expect(
      container.read(effectiveScopeWalletsProvider).map((wallet) => wallet.id),
      ['wallet-usd'],
    );
  });

  test('wallet reconciliation clears a confirmed edit with bank metadata', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final confirmed = _wallet(
      'wallet-1',
      name: 'Renamed',
      hasProviderBalance: true,
      linkedBankAccountId: 'bank-account-1',
    );
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      confirmed.id: confirmed,
    };

    container
        .read(walletActionsProvider)
        .reconcileOptimisticAccountWithServer(confirmed);

    expect(container.read(optimisticScopedAccountsOverridesProvider), isEmpty);
  });

  test('wallet reconciliation retains override for stale bank metadata', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final optimistic = _wallet(
      'wallet-1',
      name: 'Renamed',
      hasProviderBalance: true,
      linkedBankAccountId: 'bank-account-1',
    );
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      optimistic.id: optimistic,
    };

    container.read(walletActionsProvider).reconcileOptimisticAccountWithServer(
          _wallet(
            'wallet-1',
            name: 'Renamed',
            hasProviderBalance: true,
          ),
        );

    expect(
      container.read(optimisticScopedAccountsOverridesProvider),
      contains(optimistic.id),
    );
  });
}
