import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';

void main() {
  testWidgets('missing identity renders fallback without initialized dotenv',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MerchantLogo(
        merchantId: null,
        domain: null,
        fallback: Text('category fallback'),
      ),
    ));
    expect(find.text('category fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('builds a direct Logo.dev URL only for canonical merchant identity', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');
    final url = buildLogoDevMerchantUrl('merchant_1', 'Starbucks.COM');

    expect(url, isNotNull);
    expect(Uri.parse(url!).host, 'img.logo.dev');
    expect(Uri.parse(url).path, '/starbucks.com');
  });

  test('returns null so callers retain the category-icon fallback', () {
    dotenv.clean();
    expect(buildLogoDevMerchantUrl(null, 'starbucks.com'), isNull);
    expect(buildLogoDevMerchantUrl('merchant_1', null), isNull);
  });

  test('uses a trusted Plaid logo before the Logo.dev domain fallback', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');
    const plaidLogo =
        'https://plaid-merchant-logos.plaid.com/burger_king_155.png';

    expect(
      buildMerchantLogoUrl(
        logoUrl: plaidLogo,
        merchantId: 'merchant_1',
        domain: 'burgerking.com',
      ),
      plaidLogo,
    );
    expect(
      Uri.parse(buildMerchantLogoUrl(
        logoUrl: 'https://example.com/untrusted.png',
        merchantId: 'merchant_1',
        domain: 'burgerking.com',
      )!)
          .host,
      'img.logo.dev',
    );
    expect(
      buildMerchantLogoUrl(
        logoUrl: plaidLogo,
        merchantId: null,
        domain: 'burgerking.com',
      ),
      isNull,
    );
  });
}
