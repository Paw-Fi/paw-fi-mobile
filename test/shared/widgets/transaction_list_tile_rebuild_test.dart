import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

void main() {
  tearDown(() => setCustomCategoryStyleOverrides({}));

  testWidgets('shared row does not rebuild for private category style changes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: TransactionListTile(
        category: 'food',
        title: 'Shared row',
        amount: 20,
        currency: 'EUR',
        isIncome: false,
        showCurrencyFlag: false,
        useCustomCategoryStyleOverrides: false,
      )),
    ));
    final before = tester.widget<Text>(find.text('Shared row'));
    setCustomCategoryStyleOverrides({
      'food': const CustomCategoryStyle(colorArgb: 0xff123456, iconKey: 'home'),
    });
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Shared row')), before),
        isTrue);
  });

  testWidgets('personal row still reacts to custom styles', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: TransactionListTile(
        category: 'food',
        title: 'Personal row',
        amount: 20,
        currency: 'EUR',
        isIncome: false,
        showCurrencyFlag: false,
      )),
    ));
    final before = tester.widget<Text>(find.text('Personal row'));
    setCustomCategoryStyleOverrides({
      'food': const CustomCategoryStyle(colorArgb: 0xff123456, iconKey: 'home'),
    });
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Personal row')), before),
        isFalse);
  });

  testWidgets('currency selections rebuild only when flag visibility changes',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: Scaffold(
              body: TransactionListTile(
        category: 'food',
        subtitleWidget: Text('Personal'),
        title: 'Currency row',
        amount: 20,
        currency: 'EUR',
        isIncome: false,
      ))),
    ));
    final before = tester.widget<Text>(find.text('Currency row'));
    container.read(homeFilterProvider.notifier).setSelectedCurrency('USD');
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Currency row')), before),
        isTrue);
    container
        .read(homeFilterProvider.notifier)
        .setSelectedCurrencies(['EUR', 'USD']);
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Currency row')), before),
        isFalse);
    expect(find.byType(TransactionCurrencyFlagBadge), findsOneWidget);
    final multi = tester.widget<Text>(find.text('Currency row'));
    container
        .read(homeFilterProvider.notifier)
        .setSelectedCurrencies(['EUR', 'GBP']);
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Currency row')), multi),
        isTrue);
  });
}
