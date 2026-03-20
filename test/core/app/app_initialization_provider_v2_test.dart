import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';

void main() {
  group('resolveInitializedCurrencyFilterState', () {
    test('treats stored currency as explicit user selection', () {
      final result = resolveInitializedCurrencyFilterState(
        existingState: HomeFilterState(selectedCurrency: 'USD'),
        storedCurrency: 'eur',
        preferredCurrency: 'usd',
        preferExistingState: false,
      );

      expect(result.selectedCurrency, 'EUR');
      expect(result.hasExplicitCurrency, isTrue);
    });

    test('keeps existing explicit selection unchanged', () {
      final existingState = HomeFilterState(
        selectedCurrency: 'GBP',
        hasExplicitCurrency: true,
      );

      final result = resolveInitializedCurrencyFilterState(
        existingState: existingState,
        storedCurrency: 'EUR',
        preferredCurrency: 'USD',
        preferExistingState: false,
      );

      expect(result.selectedCurrency, 'GBP');
      expect(result.hasExplicitCurrency, isTrue);
    });

    test('bootstraps preferred currency when nothing explicit is stored', () {
      final result = resolveInitializedCurrencyFilterState(
        existingState: HomeFilterState(),
        storedCurrency: null,
        preferredCurrency: 'cad',
        preferExistingState: false,
      );

      expect(result.selectedCurrency, 'CAD');
      expect(result.hasExplicitCurrency, isFalse);
    });
  });
}
