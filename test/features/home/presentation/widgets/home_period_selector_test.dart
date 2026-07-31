import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/home_period_selector.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

void main() {
  test('monthly ring uses the same bootstrap currency scope as Pockets', () {
    final params = buildHomePeriodPocketsScopeParams(
      scopeType: PocketsScopeType.personal,
      householdId: null,
      period: DateTime(2026, 7, 12),
      currency: 'EUR',
      selectedCurrencies: const ['EUR'],
      financialMonthStartDay: 12,
      includeUpcomingRecurring: true,
      isBootstrapCurrency: true,
    );

    expect(
      params,
      PocketsScopeParams(
        scope: PocketsScopeType.personal,
        periodMonth: DateTime(2026, 7, 12),
        currency: 'EUR',
        selectedCurrencies: const ['EUR'],
        financialMonthStartDay: 12,
        isBootstrapCurrency: true,
        includeUpcomingRecurring: true,
      ),
    );
  });
}
