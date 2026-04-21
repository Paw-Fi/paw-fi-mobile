import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/wallet_capture_service.dart';

void main() {
  test('WalletCaptureConfig maps account selection fields', () {
    const config = WalletCaptureConfig(
      enabled: true,
      scopeId: 'household-1',
      scopeName: 'Family',
      isPortfolio: false,
      accountId: 'wallet-1',
      accountName: 'Groceries',
    );

    expect(config.toMap(), containsPair('accountId', 'wallet-1'));
    expect(config.toMap(), containsPair('accountName', 'Groceries'));

    final parsed = WalletCaptureConfig.fromMap(config.toMap());

    expect(parsed.accountId, 'wallet-1');
    expect(parsed.accountName, 'Groceries');
  });
}
