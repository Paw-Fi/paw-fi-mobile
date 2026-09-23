import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/pages/merchant_bulk_update_page.dart';
import 'package:moneko/features/home/presentation/pages/merchant_selection_page.dart';

void main() {
  test('custom merchant selection keeps only legacy text', () {
    const selection = MerchantSelection.customText('Corner Market');

    expect(selection.isCustomText, isTrue);
    expect(selection.merchant, 'Corner Market');
    expect(selection.merchantName, isNull);
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

  testWidgets('focuses search only after the page transition completes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                requestFocus: false,
                transitionDuration: const Duration(seconds: 1),
                pageBuilder: (_, __, ___) => const MerchantSelectionPage(
                  title: 'Merchant',
                  category: 'other',
                  initialQuery: '',
                  initialCandidates: [],
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: const Text('Add merchant'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add merchant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    var searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.focusNode?.hasFocus, isFalse);

    await tester.pumpAndSettle();

    searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.focusNode?.hasFocus, isTrue);
  });
}
