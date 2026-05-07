import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

class _StaticScopedWalletsNotifier extends ScopedWalletsNotifier {
  _StaticScopedWalletsNotifier(this.wallets);

  final List<WalletEntity> wallets;

  @override
  Future<List<WalletEntity>> build() async => wallets;

  @override
  Future<List<WalletEntity>> refreshFromNetwork() async => wallets;
}

WalletEntity _wallet(String id, {String name = 'Spending'}) {
  return WalletEntity(
    id: id,
    userId: 'user-1',
    householdId: null,
    name: name,
    icon: 'wallet',
    color: '#6B7280',
    openingBalanceCents: 0,
    goalAmountCents: null,
    isDefault: false,
    isSystem: false,
    isArchived: false,
    currentBalanceCents: 0,
  );
}

void main() {
  test('effectiveScopeWalletsProvider overlays and appends optimistic wallets',
      () async {
    final container = ProviderContainer(
      overrides: [
        walletScopeHouseholdIdProvider.overrideWithValue(null),
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
}
