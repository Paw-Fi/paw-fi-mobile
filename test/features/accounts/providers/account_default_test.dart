import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';

void main() {
  test('accountByIdProvider returns null when id missing', () async {
    const accounts = [
      AccountEntity(
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
        scopedAccountsProvider.overrideWith((ref) async => accounts),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedAccountsProvider.future);
    final account = container.read(accountByIdProvider('missing'));
    expect(account, isNull);
  });
}
