Future<bool> restoreAndWaitForIapSubscription({
  required Future<void> Function() restorePurchases,
  required Future<void> Function() refreshSubscription,
  required bool Function() hasActiveSubscription,
  String Function()? restoreError,
  int maxRefreshAttempts = 5,
  Duration retryDelay = const Duration(seconds: 1),
}) async {
  await restorePurchases();

  for (var attempt = 0; attempt < maxRefreshAttempts; attempt += 1) {
    if (attempt > 0 && retryDelay > Duration.zero) {
      await Future<void>.delayed(retryDelay);
    }

    await refreshSubscription();

    if (hasActiveSubscription()) {
      return true;
    }

    final error = restoreError?.call().trim() ?? '';
    if (error.isNotEmpty) {
      return false;
    }
  }

  return false;
}
