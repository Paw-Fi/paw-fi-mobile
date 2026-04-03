import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

void main() {
  test('accountByIdProvider returns null when id missing', () async {
    const wallets = [
      WalletEntity(
        id: 'spending',
        userId: 'u1',
        householdId: null,
        name: 'Spending',
        icon: 'wallet',
        color: '#6B7280',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: true,
        isSystem: true,
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
    final account = container.read(walletByIdProvider('missing'));
    expect(account, isNull);
  });
}
