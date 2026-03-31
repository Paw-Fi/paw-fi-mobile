import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';

void main() {
  test('defaultScopedAccountProvider resolves default account', () async {
    const accounts = [
      AccountEntity(
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
      AccountEntity(
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
        scopedAccountsProvider.overrideWith((ref) async => accounts),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedAccountsProvider.future);
    final resolved = container.read(defaultScopedAccountProvider);
    expect(resolved?.id, 'a2');
  });
}
