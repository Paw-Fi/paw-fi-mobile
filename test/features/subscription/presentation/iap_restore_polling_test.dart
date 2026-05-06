import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/presentation/iap_restore_polling.dart';

void main() {
  test('polls subscription state after restore until entitlement appears',
      () async {
    var restoreCalls = 0;
    var refreshCalls = 0;
    var active = false;

    final restored = await restoreAndWaitForIapSubscription(
      restorePurchases: () async {
        restoreCalls += 1;
      },
      refreshSubscription: () async {
        refreshCalls += 1;
        if (refreshCalls == 3) {
          active = true;
        }
      },
      hasActiveSubscription: () => active,
      retryDelay: Duration.zero,
      maxRefreshAttempts: 5,
    );

    expect(restored, true);
    expect(restoreCalls, 1);
    expect(refreshCalls, 3);
  });
}
