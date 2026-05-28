import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/utils/ai_input_wallet_filter.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

void main() {
  test('keeps wallets matching any selected currency', () {
    final wallets = <WalletEntity>[
      _wallet(id: 'eur-wallet', currency: 'EUR'),
      _wallet(id: 'usd-wallet', currency: 'USD'),
      _wallet(id: 'jpy-wallet', currency: 'JPY'),
      _wallet(id: 'archived-wallet', currency: 'EUR', isArchived: true),
    ];
    final filter = HomeFilterState(
      selectedCurrency: 'EUR',
      selectedCurrencies: const <String>['EUR', 'USD'],
    );

    final result = filterAiInputTargetWallets(wallets, filter);

    expect(result.map((wallet) => wallet.id), ['eur-wallet', 'usd-wallet']);
  });
}

WalletEntity _wallet({
  required String id,
  required String currency,
  bool isArchived = false,
}) {
  return WalletEntity(
    id: id,
    userId: 'user-id',
    householdId: null,
    name: id,
    icon: 'wallet',
    color: '#6B7280',
    currency: currency,
    openingBalanceCents: 0,
    goalAmountCents: null,
    isDefault: false,
    isSystem: false,
    isArchived: isArchived,
    currentBalanceCents: 0,
  );
}
