import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/presentation/utils/pending_settlement_payment.dart';

void main() {
  group('pendingSettlementPaymentRecord', () {
    test('maps a payment to a member to the current user as payer', () {
      final payment = pendingSettlementPaymentRecord(
        currentUserId: 'me',
        memberUserId: 'alex',
        mode: 'to_member',
        amountCents: 1250,
        currency: 'usd',
      );

      expect(payment?.payerUserId, 'me');
      expect(payment?.participantUserId, 'alex');
      expect(payment?.amountCents, 1250);
      expect(payment?.currency, 'USD');
    });

    test('maps a payment from a member to that member as payer', () {
      final payment = pendingSettlementPaymentRecord(
        currentUserId: 'me',
        memberUserId: 'alex',
        mode: 'from_member',
        amountCents: 1250,
        currency: 'EUR',
      );

      expect(payment?.payerUserId, 'alex');
      expect(payment?.participantUserId, 'me');
    });

    test('does not invent a direction for express netting', () {
      expect(
        pendingSettlementPaymentRecord(
          currentUserId: 'me',
          memberUserId: 'alex',
          mode: 'both',
          amountCents: 1250,
          currency: 'USD',
        ),
        isNull,
      );
    });
  });
}
