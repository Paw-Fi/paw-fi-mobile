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

  test('builds a direct Logo.dev URL for a canonical merchant domain', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');
    final url = buildLogoDevMerchantUrl('merchant_1', 'Starbucks.COM');

    expect(url, isNotNull);
    expect(Uri.parse(url!).host, 'img.logo.dev');
    expect(Uri.parse(url).path, '/starbucks.com');

    final withoutIdentity = buildLogoDevMerchantUrl(null, 'amazon.co.uk');
    expect(withoutIdentity, isNotNull);
    expect(Uri.parse(withoutIdentity!).path, '/amazon.co.uk');
  });

  test('builds a name URL without canonical identity', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');
    final url = buildLogoDevMerchantNameUrl('Amazon');

    expect(url, isNotNull);
    expect(Uri.parse(url!).path, '/name/Amazon');
    expect(Uri.parse(url).queryParameters['fallback'], '404');
  });

  test('encodes merchant names as one path segment', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');
    final url = buildLogoDevMerchantNameUrl('Café / 東京');

    expect(Uri.parse(url!).pathSegments, ['name', 'Café / 東京']);
  });

  test('returns null when no domain or merchant name is available', () {
    dotenv.clean();
    expect(buildLogoDevMerchantNameUrl('Amazon'), isNull);
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
      plaidLogo,
    );
  });

  test('uses only the structured name for Logo.dev name lookup', () {
    dotenv.testLoad(fileInput: 'LOGO_DEV_PUBLISHABLE_KEY=test-logo-token');

    final structured = buildMerchantLogoUrl(
      logoUrl: null,
      merchantId: null,
      domain: null,
      merchantStructuredName: 'Amazon Marketplace',
      merchantName: 'AMZN MKTP',
    );
    final rawOnly = buildMerchantLogoUrl(
      logoUrl: null,
      merchantId: null,
      domain: null,
      merchantStructuredName: '  ',
      merchantName: 'AMZN MKTP',
    );

    expect(Uri.parse(structured!).pathSegments, ['name', 'Amazon Marketplace']);
    expect(rawOnly, isNull);
  });
}
