import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';

void main() {
  group('householdDashboardDependencyState', () {
    test('does not expose a partial summary while any input is unresolved', () {
      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        const AsyncValue.data(<Object>[]),
        const AsyncValue.loading(),
        const AsyncValue.data(<Object>[]),
      ]);

      expect(state.isLoading, isTrue);
      expect(state.hasValue, isFalse);
    });

    test('preserves usable cached inputs while they refresh', () {
      final refreshing = const AsyncValue<List<Object>>.loading()
          .copyWithPrevious(const AsyncValue.data(<Object>[]));

      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        refreshing,
        const AsyncValue.data(<Object>[]),
      ]);

      expect(state.valueOrNull, isTrue);
    });

    test('propagates an input error when no cached value exists', () {
      final error = StateError('splits failed');
      final state = householdDashboardDependencyState(<AsyncValue<Object?>>[
        const AsyncValue.data(<Object>[]),
        AsyncValue.error(error, StackTrace.current),
      ]);

      expect(state.hasError, isTrue);
      expect(state.error, same(error));
    });
  });
}
