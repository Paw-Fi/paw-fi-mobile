import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';

void main() {
  test('buildWalletAuthHeaders returns null when token is missing', () {
    expect(buildWalletAuthHeaders(null), isNull);
    expect(buildWalletAuthHeaders('   '), isNull);
  });

  test('buildWalletAuthHeaders returns bearer auth header', () {
    expect(
      buildWalletAuthHeaders('token-123'),
      {'Authorization': 'Bearer token-123'},
    );
  });
}
