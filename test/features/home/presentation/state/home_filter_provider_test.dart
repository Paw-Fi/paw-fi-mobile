import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';

void main() {
  test('home filter keeps primary currency separate from selected currencies',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(homeFilterProvider.notifier);

    notifier.setSelectedCurrency('USD');
    notifier.setSelectedCurrencies(['usd', 'EUR', 'usd', '']);

    final state = container.read(homeFilterProvider);
    expect(state.selectedCurrency, 'USD');
    expect(state.selectedCurrencies, ['USD', 'EUR']);
    expect(state.allowsCurrency('EUR'), isTrue);
    expect(state.allowsCurrency('JPY'), isFalse);
  });
}
