import 'package:hooks_riverpod/hooks_riverpod.dart';

extension AsyncValueMapping<T> on AsyncValue<T> {
  /// Riverpod 2's whenData drops previous data on dependency reloads/errors.
  AsyncValue<R> whenDataWithPrevious<R>(R Function(T value) transform) {
    final mapped = hasValue
        ? AsyncData<T>(requireValue).whenData(transform)
        : whenData(transform);
    if (hasValue && !mapped.hasValue) return mapped;
    final result = hasError
        ? AsyncError<R>(error!, stackTrace ?? StackTrace.current)
            .copyWithPrevious(mapped)
        : mapped;
    return isLoading
        ? AsyncLoading<R>().copyWithPrevious(result, isRefresh: !isReloading)
        : result;
  }
}
