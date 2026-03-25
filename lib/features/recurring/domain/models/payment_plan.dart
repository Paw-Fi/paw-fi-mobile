import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

enum PaymentPlanType { recurring, installment }

enum PaymentPlanStatus { active, paused, completed, cancelled, defaulted }

enum PaymentOccurrenceStatus {
  scheduled,
  paid,
  skipped,
  cancelled,
  overdue,
  partiallyPaid,
  settledEarly,
}

enum PaymentKind { normal, partial, extra, earlyPayoff, correction }

class RecurrenceRuleDto {
  final String frequency;
  final int? interval;
  final DateTime anchorDate;
  final DateTime? endDate;
  final int? reminderValue;
  final String? reminderUnit;
  final List<DateTime> excludedDates;

  const RecurrenceRuleDto({
    required this.frequency,
    required this.anchorDate,
    this.interval,
    this.endDate,
    this.reminderValue,
    this.reminderUnit,
    this.excludedDates = const [],
  });

  factory RecurrenceRuleDto.fromRecurringRule(RecurrenceRule rule) {
    return RecurrenceRuleDto(
      frequency: rule.frequency,
      interval: rule.interval,
      anchorDate: rule.anchorDate,
      endDate: rule.endDate,
      reminderValue: rule.reminderValue,
      reminderUnit: rule.reminderUnit,
      excludedDates: rule.excludedDates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      'anchor_date':
          '${anchorDate.year.toString().padLeft(4, '0')}-${anchorDate.month.toString().padLeft(2, '0')}-${anchorDate.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'end_date':
            '${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
      if (reminderValue != null || reminderUnit != null)
        'reminder': {
          'enabled': true,
          if (reminderValue != null) 'value': reminderValue,
          if (reminderUnit != null) 'unit': reminderUnit,
        },
      if (excludedDates.isNotEmpty)
        'excluded_dates': excludedDates
            .map(
              (date) =>
                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            )
            .toList(),
    };
  }
}

class InstallmentScheduleLineDto {
  final int occurrenceNumber;
  final DateTime scheduledDate;
  final int dueAmountCents;
  final int? principalComponentCents;
  final int? interestComponentCents;
  final int? feeComponentCents;

  const InstallmentScheduleLineDto({
    required this.occurrenceNumber,
    required this.scheduledDate,
    required this.dueAmountCents,
    this.principalComponentCents,
    this.interestComponentCents,
    this.feeComponentCents,
  });

  Map<String, dynamic> toJson() => {
        'occurrenceNumber': occurrenceNumber,
        'scheduledDate':
            '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
        'dueAmountCents': dueAmountCents,
        if (principalComponentCents != null)
          'principalComponentCents': principalComponentCents,
        if (interestComponentCents != null)
          'interestComponentCents': interestComponentCents,
        if (feeComponentCents != null) 'feeComponentCents': feeComponentCents,
      };
}

class ScheduledListItemDto {
  final String id;
  final PaymentPlanType paymentPlanType;
  final String type;
  final String title;
  final String category;
  final String currency;
  final int displayAmountCents;
  final DateTime? nextDueDate;
  final String status;
  final String? progressText;
  final int? remainingBalanceCents;
  final String? householdId;

  const ScheduledListItemDto({
    required this.id,
    required this.paymentPlanType,
    required this.type,
    required this.title,
    required this.category,
    required this.currency,
    required this.displayAmountCents,
    required this.nextDueDate,
    required this.status,
    this.progressText,
    this.remainingBalanceCents,
    this.householdId,
  });

  factory ScheduledListItemDto.fromJson(Map<String, dynamic> json) {
    final rawPlanType = (json['payment_plan_type'] ?? json['paymentPlanType'])
        .toString()
        .toLowerCase();
    return ScheduledListItemDto(
      id: (json['id'] ?? '').toString(),
      paymentPlanType: rawPlanType == 'installment'
          ? PaymentPlanType.installment
          : PaymentPlanType.recurring,
      type: (json['type'] ?? 'expense').toString(),
      title: (json['title'] ?? json['category'] ?? 'Plan').toString(),
      category: (json['category'] ?? 'other').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      displayAmountCents: (json['display_amount_cents'] ??
              json['displayAmountCents'] ??
              0) is num
          ? ((json['display_amount_cents'] ?? json['displayAmountCents'] ?? 0)
                  as num)
              .toInt()
          : 0,
      nextDueDate: DateTime.tryParse((json['next_due_date'] ?? '').toString()),
      status: (json['status'] ?? 'active').toString(),
      progressText: json['progress_text']?.toString(),
      remainingBalanceCents: (json['remaining_balance_cents'] is num)
          ? (json['remaining_balance_cents'] as num).toInt()
          : null,
      householdId: json['household_id']?.toString(),
    );
  }
}
