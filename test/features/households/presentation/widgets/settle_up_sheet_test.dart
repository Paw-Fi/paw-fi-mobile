import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';

void main() {
  test('optimistic settlement uses the server payer direction when user owes',
      () {
    final payment = buildOptimisticSettlementPayment(
      currentUserId: 'me',
      memberUserId: 'alex',
      currentUserOwes: true,
      amountCents: 10000,
      currency: 'USD',
    );

    expect(payment.payerUserId, 'alex');
    expect(payment.participantUserId, 'me');
  });

  test('optimistic settlement reverses direction when member owes user', () {
    final payment = buildOptimisticSettlementPayment(
      currentUserId: 'me',
      memberUserId: 'alex',
      currentUserOwes: false,
      amountCents: 2500,
      currency: 'USD',
    );

    expect(payment.payerUserId, 'me');
    expect(payment.participantUserId, 'alex');
  });
}
