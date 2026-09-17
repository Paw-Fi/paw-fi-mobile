import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/pages/merchant_bulk_update_page.dart';
import 'package:moneko/features/home/presentation/pages/merchant_selection_page.dart';

void main() {
  test('custom merchant selection keeps only legacy text', () {
    const selection = MerchantSelection.customText('Corner Market');

    expect(selection.isCustomText, isTrue);
    expect(selection.merchant, 'Corner Market');
    expect(selection.merchantId, isNull);
    expect(selection.merchantDomain, isNull);
  });

  test('verified merchant selection keeps only identity fields', () {
    const selection = MerchantSelection.identity(
      descriptor: 'Example outlet 12',
      merchantName: 'Example',
      merchantId: 'merchant-id',
      merchantDomain: 'example.com',
      allowsStructuredLearning: true,
    );

    expect(selection.isCustomText, isFalse);
    expect(selection.merchant, isNull);
    expect(selection.merchantId, 'merchant-id');
    expect(selection.merchantDomain, 'example.com');
  });

  test('bulk scope includes its primary currency in backend validation', () {
    const scope = MerchantBulkScope(
      userId: 'user-id',
      householdId: null,
      selectedCurrency: 'eur',
      selectedCurrencies: ['USD', 'eur'],
    );

    expect(scope.effectiveCurrencies, ['EUR', 'USD']);
  });
}
