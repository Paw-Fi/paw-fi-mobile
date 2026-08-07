import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';

void main() {
  test('payment cancellation exception omits the Exception prefix', () {
    const error = PaymentCanceledException('付款已取消');

    expect(error.toString(), '付款已取消');
  });

  test('recognizes the hosted mobile success return before localhost loads',
      () {
    final result = mobileStripeCheckoutResultForNavigationUri(
      Uri.parse(
        'https://localhost:3000/checkout?status=success&source=mobile&redirectUrl=moneko%3A%2F%2Fpayment&session_id=cs_123&v=nonce',
      ),
      checkoutBaseUrl: 'localhost:3000',
    );

    expect(result?.isSuccess, isTrue);
    expect(result?.sessionId, 'cs_123');
    expect(result?.verificationNonce, 'nonce');
  });

  test('does not accept a payment result from an unrelated host', () {
    final result = mobileStripeCheckoutResultForNavigationUri(
      Uri.parse(
        'https://example.com/checkout?status=success&source=mobile&redirectUrl=moneko%3A%2F%2Fpayment&session_id=cs_123',
      ),
      checkoutBaseUrl: 'moneko.io',
    );

    expect(result, isNull);
  });

  test('refreshes until the paid subscription becomes active', () async {
    var refreshCount = 0;
    final isActive = await waitForMobileStripeSubscriptionActivation(
      refreshSubscription: () async => refreshCount++,
      hasActiveSubscription: () => refreshCount >= 3,
      wait: (_) async {},
    );

    expect(isActive, isTrue);
    expect(refreshCount, 3);
  });

  test('returns false when subscription activation never arrives', () async {
    var refreshCount = 0;
    final isActive = await waitForMobileStripeSubscriptionActivation(
      refreshSubscription: () async => refreshCount++,
      hasActiveSubscription: () => false,
      wait: (_) async {},
    );

    expect(isActive, isFalse);
    expect(refreshCount, 12);
  });

  test('times out a stalled checkout-session request', () async {
    final pendingResponse = Completer<String>();

    await expectLater(
      awaitMobileStripeCheckoutSession(
        pendingResponse.future,
        timeout: Duration.zero,
      ),
      throwsA(isA<TimeoutException>()),
    );
    pendingResponse.complete('ignored after timeout');
  });
}
