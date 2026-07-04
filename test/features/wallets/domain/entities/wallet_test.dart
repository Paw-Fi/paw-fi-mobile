import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

void main() {
  test('WalletEntity serializes logoUrl', () {
    const wallet = WalletEntity(
      id: 'wallet-1',
      userId: 'user-1',
      householdId: null,
      name: 'Main Wallet',
      icon: 'wallet',
      color: '#6B7280',
      logoUrl: 'https://example.com/wallet.jpg',
      openingBalanceCents: 1000,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 1000,
    );

    final json = wallet.toJson();
    final parsed = WalletEntity.fromJson(json);

    expect(json['logo_url'], 'https://example.com/wallet.jpg');
    expect(parsed.logoUrl, 'https://example.com/wallet.jpg');
  });

  test('WalletEntity copyWith can replace logoUrl', () {
    const wallet = WalletEntity(
      id: 'wallet-1',
      userId: 'user-1',
      householdId: null,
      name: 'Main Wallet',
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: 1000,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 1000,
    );

    final updated = wallet.copyWith(logoUrl: 'https://example.com/logo.jpg');

    expect(updated.logoUrl, 'https://example.com/logo.jpg');
  });
}
