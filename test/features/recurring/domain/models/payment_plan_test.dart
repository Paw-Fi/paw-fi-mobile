import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/payment_plan.dart';

void main() {
  group('ScheduledListItemDto', () {
    test('parses installment item', () {
      final item = ScheduledListItemDto.fromJson({
        'id': 'plan-1',
        'payment_plan_type': 'installment',
        'type': 'expense',
        'title': 'Laptop plan',
        'category': 'shopping',
        'currency': 'USD',
        'display_amount_cents': 12345,
        'next_due_date': '2026-03-28',
        'status': 'active',
        'progress_text': '1/12 paid',
        'remaining_balance_cents': 111111,
      });

      expect(item.id, 'plan-1');
      expect(item.paymentPlanType, PaymentPlanType.installment);
      expect(item.displayAmountCents, 12345);
      expect(item.progressText, '1/12 paid');
      expect(item.remainingBalanceCents, 111111);
    });

    test('falls back to recurring type for unknown values', () {
      final item = ScheduledListItemDto.fromJson({
        'id': 'plan-2',
        'payment_plan_type': 'unknown',
        'type': 'income',
        'category': 'salary',
        'currency': 'EUR',
      });

      expect(item.paymentPlanType, PaymentPlanType.recurring);
      expect(item.type, 'income');
      expect(item.currency, 'EUR');
      expect(item.displayAmountCents, 0);
    });
  });

  group('RecurrenceRuleDto', () {
    test('serializes expected recurrence payload', () {
      final dto = RecurrenceRuleDto(
        frequency: 'monthly',
        interval: 2,
        anchorDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 12, 25),
        reminderValue: 1,
        reminderUnit: 'days',
      );

      final json = dto.toJson();

      expect(json['frequency'], 'monthly');
      expect(json['interval'], 2);
      expect(json['anchor_date'], '2026-03-25');
      expect(json['end_date'], '2026-12-25');
      expect((json['reminder'] as Map<String, dynamic>)['unit'], 'days');
    });
  });
}
