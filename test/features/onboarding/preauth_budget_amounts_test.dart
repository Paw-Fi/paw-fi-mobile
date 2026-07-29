import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/onboarding/domain/preauth_budget_amounts.dart';

void main() {
  group('parseManualPreauthBudgetAmount', () {
    test('preserves amounts outside currency slider ranges', () {
      expect(parseManualPreauthBudgetAmount('4000000'), 4000000);
      expect(parseManualPreauthBudgetAmount('1'), 1);
      expect(parseManualPreauthBudgetAmount('9,999,999'), 9999999);
      expect(parseManualPreauthBudgetAmount('4.000.000'), 4000000);
    });

    test('preserves supported decimal input', () {
      expect(parseManualPreauthBudgetAmount('1234.56'), 1234.56);
      expect(parseManualPreauthBudgetAmount('1234,56'), 1234.56);
      expect(parseManualPreauthBudgetAmount('1,234.56'), 1234.56);
      expect(parseManualPreauthBudgetAmount('1.234,56'), 1234.56);
    });

    test('rejects non-positive and malformed input', () {
      expect(parseManualPreauthBudgetAmount('0'), isNull);
      expect(parseManualPreauthBudgetAmount('-1'), isNull);
      expect(parseManualPreauthBudgetAmount('not an amount'), isNull);
      expect(parseManualPreauthBudgetAmount('amount 123'), isNull);
      expect(parseManualPreauthBudgetAmount('1,,2'), isNull);
      expect(parseManualPreauthBudgetAmount('1.2.3'), isNull);
    });
  });
}
