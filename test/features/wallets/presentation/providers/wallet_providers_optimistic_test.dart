import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

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
