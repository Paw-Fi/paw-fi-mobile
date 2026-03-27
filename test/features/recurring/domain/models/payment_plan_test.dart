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

  group('PaymentPlanDetailDto', () {
    test('parses plan detail payload', () {
      final detail = PaymentPlanDetailDto.fromJson({
        'plan': {
          'id': 'plan-1',
          'payment_plan_type': 'installment',
          'plan_status': 'active',
          'type': 'expense',
          'category': 'shopping',
          'currency': 'USD',
          'recurrence_rule': {
            'frequency': 'monthly',
            'anchor_date': '2026-03-25',
          },
          'remaining_balance_cents': 900,
        },
        'occurrences': [
          {
            'id': 'occ-1',
            'payment_plan_id': 'plan-1',
            'occurrence_number': 1,
            'scheduled_date': '2026-03-25',
            'original_scheduled_date': '2026-03-25',
            'due_amount_cents': 300,
            'paid_amount_cents': 0,
            'remaining_amount_cents': 300,
            'status': 'scheduled',
          },
        ],
        'payments': [
          {'id': 'pay-1', 'amount_cents': 100},
        ],
      });

      expect(detail.plan.id, 'plan-1');
      expect(detail.plan.paymentPlanType, PaymentPlanType.installment);
      expect(detail.occurrences.single.id, 'occ-1');
      expect(
          detail.occurrences.single.status, PaymentOccurrenceStatus.scheduled);
      expect(detail.payments.single['id'], 'pay-1');
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
