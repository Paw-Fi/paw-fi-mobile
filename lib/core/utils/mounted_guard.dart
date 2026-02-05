Future<T?> runIfMounted<T>({
  required bool Function() isMounted,
  required Future<T> Function() action,
}) async {
  if (!isMounted()) return null;
  final result = await action();
  if (!isMounted()) return null;
  return result;
}
