import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';

void main() {
  test('payment cancellation exception omits the Exception prefix', () {
    const error = PaymentCanceledException('付款已取消');

    expect(error.toString(), '付款已取消');
  });
}
