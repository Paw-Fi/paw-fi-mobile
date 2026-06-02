import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';

void main() {
  group('shouldShowTransactionsChartSkeleton', () {
    test('uses the main feed loading state for the normal chart source', () {
      expect(
        shouldShowTransactionsChartSkeleton(
          isFeedLoading: true,
          isMultiCurrencySelection: false,
          chartSourceState: null,
        ),
        isTrue,
      );
    });

    test('uses the all-items loading state for multi-currency fallback charts',
        () {
      expect(
        shouldShowTransactionsChartSkeleton(
          isFeedLoading: false,
          isMultiCurrencySelection: true,
          chartSourceState: const AsyncLoading<List<ExpenseEntry>>(),
        ),
        isTrue,
      );
    });

    test('does not show a skeleton after an empty load has completed', () {
      expect(
        shouldShowTransactionsChartSkeleton(
          isFeedLoading: false,
          isMultiCurrencySelection: false,
          chartSourceState: const AsyncData<List<ExpenseEntry>>([]),
        ),
        isFalse,
      );
    });
  });
}
