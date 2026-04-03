import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

void main() {
  test('defaultScopedAccountProvider resolves default wallet', () async {
    const wallets = [
      WalletEntity(
        id: 'a1',
        userId: 'u1',
        householdId: null,
        name: 'Spending',
        icon: 'wallet',
        color: '#6B7280',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: false,
        isSystem: true,
        isArchived: false,
        currentBalanceCents: 0,
      ),
      WalletEntity(
        id: 'a2',
        userId: 'u1',
        householdId: null,
        name: 'Travel',
        icon: 'plane',
        color: '#3B82F6',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: true,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 0,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        scopedWalletsProvider.overrideWith((ref) async => wallets),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);
    final resolved = container.read(defaultScopedAccountProvider);
    expect(resolved?.id, 'a2');
  });
}
