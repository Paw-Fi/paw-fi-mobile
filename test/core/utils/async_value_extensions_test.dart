import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/async_value_extensions.dart';

void main() {
  test('maps loaded, refreshing, reloading and cached error values', () {
    const data = AsyncData(10);
    final error = StateError('offline');
    final stack = StackTrace.current;
    for (final source in <AsyncValue<int>>[
      data,
      const AsyncLoading<int>().copyWithPrevious(data),
      const AsyncLoading<int>().copyWithPrevious(data, isRefresh: false),
      AsyncError<int>(error, stack).copyWithPrevious(data),
      const AsyncLoading<int>().copyWithPrevious(
          AsyncError<int>(error, stack).copyWithPrevious(data)),
    ]) {
      final mapped = source.whenDataWithPrevious((value) => '$value');
      expect(mapped.requireValue, '10');
      expect(mapped.isLoading, source.isLoading);
      expect(mapped.isReloading, source.isReloading);
      expect(mapped.hasError, source.hasError);
      expect(mapped.error, source.error);
      expect(mapped.stackTrace, source.stackTrace);
    }
  });

  test('unknown reads do not transform or invent cached data', () {
    final error = AsyncError<int>(StateError('offline'), StackTrace.current);
    for (final source in <AsyncValue<int>>[
      const AsyncLoading(),
      error,
      const AsyncLoading<int>().copyWithPrevious(error),
      const AsyncLoading<int>().copyWithPrevious(error, isRefresh: false),
    ]) {
      final mapped = source.whenDataWithPrevious((value) {
        fail('unknown values cannot be transformed');
      });
      expect(mapped.hasValue, isFalse);
      expect(mapped.isLoading, source.isLoading);
      expect(mapped.isReloading, source.isReloading);
      expect(mapped.error, source.error);
    }
  });

  test('failed transformation never retains an invalid financial value', () {
    final source = const AsyncLoading<int>()
        .copyWithPrevious(const AsyncData(10), isRefresh: false);
    final mapped = source.whenDataWithPrevious<String>(
        (value) => throw StateError('invalid rates'));
    expect(mapped.hasError, isTrue);
    expect(mapped.hasValue, isFalse);
  });
}
