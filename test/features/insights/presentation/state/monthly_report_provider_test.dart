import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';

void main() {
  group('buildMonthlyReportBudgetInputsForTesting', () {
    test('uses rollover-adjusted available budget for report budget health',
        () {
      final inputs = buildMonthlyReportBudgetInputsForTesting(
        [
          PocketEnvelope(
            id: 'env-food',
            name: 'Food',
            budgetAmountCents: 40000,
            spent: 425,
            currency: 'EUR',
            rolloverEnabled: true,
            rolloverFromPreviousCents: 5000,
            availableBudgetCents: 45000,
            remainingCents: 2500,
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        currencyCode: 'EUR',
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 1},
        ),
        aggregateSpentByEnvelopeId: const {},
      );

      expect(inputs.single.budgetAmount, 450);
      expect(inputs.single.spent, 425);
    });

    test('converts available budgets for multi-currency report selections', () {
      final inputs = buildMonthlyReportBudgetInputsForTesting(
        [
          PocketEnvelope(
            id: 'env-food',
            name: 'Food',
            budgetAmountCents: 40000,
            spent: 200,
            currency: 'USD',
            availableBudgetCents: 50000,
            remainingCents: 30000,
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        currencyCode: 'EUR',
        selectedCurrencies: const ['EUR', 'USD'],
        rates: const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: {'USD': 1, 'EUR': 0.5},
        ),
        aggregateSpentByEnvelopeId: const {'env-food': 100},
      );

      expect(inputs.single.budgetAmount, 250);
      expect(inputs.single.spent, 100);
    });
  });
}
