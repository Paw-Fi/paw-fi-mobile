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

  factory RecurrenceRuleDto.fromJson(Map<String, dynamic> json) {
    final reminder = json['reminder'];
    return RecurrenceRuleDto(
      frequency: (json['frequency'] ?? 'monthly').toString(),
      interval: _toIntOrNull(json['interval']),
      anchorDate: DateTime.tryParse(
              (json['anchor_date'] ?? json['anchorDate']).toString()) ??
          DateTime.now(),
      endDate: DateTime.tryParse(
          (json['end_date'] ?? json['endDate'] ?? '').toString()),
      reminderValue: reminder is Map<String, dynamic>
          ? _toIntOrNull(reminder['value'])
          : _toIntOrNull(json['reminderValue']),
      reminderUnit: reminder is Map<String, dynamic>
          ? reminder['unit']?.toString()
          : json['reminderUnit']?.toString(),
      excludedDates:
          ((json['excluded_dates'] ?? json['excludedDates']) as List?)
                  ?.map((value) => DateTime.tryParse(value.toString()))
                  .whereType<DateTime>()
                  .toList(growable: false) ??
              const <DateTime>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      'anchor_date': _dateOnly(anchorDate),
      if (endDate != null) 'end_date': _dateOnly(endDate!),
      if (reminderValue != null || reminderUnit != null)
        'reminder': {
          'enabled': true,
          if (reminderValue != null) 'value': reminderValue,
          if (reminderUnit != null) 'unit': reminderUnit,
        },
      if (excludedDates.isNotEmpty)
        'excluded_dates': excludedDates.map(_dateOnly).toList(growable: false),
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

  factory InstallmentScheduleLineDto.fromJson(Map<String, dynamic> json) {
    return InstallmentScheduleLineDto(
      occurrenceNumber:
          _toIntOrNull(json['occurrence_number'] ?? json['occurrenceNumber']) ??
              0,
      scheduledDate: DateTime.tryParse(
            (json['scheduled_date'] ?? json['scheduledDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      dueAmountCents:
          _toIntOrNull(json['due_amount_cents'] ?? json['dueAmountCents']) ?? 0,
      principalComponentCents: _toIntOrNull(
        json['principal_component_cents'] ?? json['principalComponentCents'],
      ),
      interestComponentCents: _toIntOrNull(
        json['interest_component_cents'] ?? json['interestComponentCents'],
      ),
      feeComponentCents: _toIntOrNull(
          json['fee_component_cents'] ?? json['feeComponentCents']),
    );
  }

  Map<String, dynamic> toJson() => {
        'occurrenceNumber': occurrenceNumber,
        'scheduledDate': _dateOnly(scheduledDate),
        'dueAmountCents': dueAmountCents,
        if (principalComponentCents != null)
          'principalComponentCents': principalComponentCents,
        if (interestComponentCents != null)
          'interestComponentCents': interestComponentCents,
        if (feeComponentCents != null) 'feeComponentCents': feeComponentCents,
      };
}

class PaymentPlanDto {
  final String id;
  final PaymentPlanType paymentPlanType;
  final PaymentPlanStatus planStatus;
  final String type;
  final String category;
  final String currency;
  final String? householdId;
  final String? contactId;
  final String? privacyScope;
  final String? ownerType;
  final String? payerUserId;
  final RecurrenceRuleDto recurrenceRule;
  final int? principalAmountCents;
  final int? interestFeeAmountCents;
  final int? totalPayableAmountCents;
  final int? installmentCount;
  final int? installmentAmountCents;
  final int? remainingBalanceCents;
  final int? paidInstallmentsCount;
  final int? remainingInstallmentsCount;
  final bool customScheduleMode;
  final List<InstallmentScheduleLineDto> customSchedule;

  const PaymentPlanDto({
    required this.id,
    required this.paymentPlanType,
    required this.planStatus,
    required this.type,
    required this.category,
    required this.currency,
    required this.recurrenceRule,
    this.householdId,
    this.contactId,
    this.privacyScope,
    this.ownerType,
    this.payerUserId,
    this.principalAmountCents,
    this.interestFeeAmountCents,
    this.totalPayableAmountCents,
    this.installmentCount,
    this.installmentAmountCents,
    this.remainingBalanceCents,
    this.paidInstallmentsCount,
    this.remainingInstallmentsCount,
    this.customScheduleMode = false,
    this.customSchedule = const [],
  });

  factory PaymentPlanDto.fromJson(Map<String, dynamic> json) {
    final customSchedule =
        ((json['custom_schedule'] ?? json['customSchedule']) as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(InstallmentScheduleLineDto.fromJson)
                .toList(growable: false) ??
            const <InstallmentScheduleLineDto>[];

    return PaymentPlanDto(
      id: (json['id'] ?? '').toString(),
      paymentPlanType: _paymentPlanTypeFromValue(
        json['payment_plan_type'] ?? json['paymentPlanType'],
      ),
      planStatus: _paymentPlanStatusFromValue(
        json['plan_status'] ?? json['planStatus'],
      ),
      type: (json['type'] ?? 'expense').toString(),
      category: (json['category'] ?? 'other').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      householdId:
          json['household_id']?.toString() ?? json['householdId']?.toString(),
      contactId:
          json['contact_id']?.toString() ?? json['contactId']?.toString(),
      privacyScope:
          json['privacy_scope']?.toString() ?? json['privacyScope']?.toString(),
      ownerType:
          json['owner_type']?.toString() ?? json['ownerType']?.toString(),
      payerUserId:
          json['payer_user_id']?.toString() ?? json['payerUserId']?.toString(),
      recurrenceRule: RecurrenceRuleDto.fromJson(
        (json['recurrence_rule'] ?? json['recurrenceRule'] ?? const {})
            as Map<String, dynamic>,
      ),
      principalAmountCents: _toIntOrNull(
          json['principal_amount_cents'] ?? json['principalAmountCents']),
      interestFeeAmountCents: _toIntOrNull(
        json['interest_fee_amount_cents'] ?? json['interestFeeAmountCents'],
      ),
      totalPayableAmountCents: _toIntOrNull(
        json['total_payable_amount_cents'] ?? json['totalPayableAmountCents'],
      ),
      installmentCount:
          _toIntOrNull(json['installment_count'] ?? json['installmentCount']),
      installmentAmountCents: _toIntOrNull(
        json['installment_amount_cents'] ?? json['installmentAmountCents'],
      ),
      remainingBalanceCents: _toIntOrNull(
        json['remaining_balance_cents'] ?? json['remainingBalanceCents'],
      ),
      paidInstallmentsCount: _toIntOrNull(
        json['paid_installments_count'] ?? json['paidInstallmentsCount'],
      ),
      remainingInstallmentsCount: _toIntOrNull(
        json['remaining_installments_count'] ??
            json['remainingInstallmentsCount'],
      ),
      customScheduleMode:
          (json['custom_schedule_mode'] ?? json['customScheduleMode']) == true,
      customSchedule: customSchedule,
    );
  }
}

class PaymentPlanOccurrenceDto {
  final String id;
  final String paymentPlanId;
  final int occurrenceNumber;
  final DateTime scheduledDate;
  final DateTime originalScheduledDate;
  final int dueAmountCents;
  final int paidAmountCents;
  final int remainingAmountCents;
  final PaymentOccurrenceStatus status;
  final String? transactionId;
  final bool generatedFromSkip;
  final String? skippedReason;

  const PaymentPlanOccurrenceDto({
    required this.id,
    required this.paymentPlanId,
    required this.occurrenceNumber,
    required this.scheduledDate,
    required this.originalScheduledDate,
    required this.dueAmountCents,
    required this.paidAmountCents,
    required this.remainingAmountCents,
    required this.status,
    this.transactionId,
    this.generatedFromSkip = false,
    this.skippedReason,
  });

  factory PaymentPlanOccurrenceDto.fromJson(Map<String, dynamic> json) {
    return PaymentPlanOccurrenceDto(
      id: (json['id'] ?? '').toString(),
      paymentPlanId:
          (json['payment_plan_id'] ?? json['paymentPlanId'] ?? '').toString(),
      occurrenceNumber:
          _toIntOrNull(json['occurrence_number'] ?? json['occurrenceNumber']) ??
              0,
      scheduledDate: DateTime.tryParse(
            (json['scheduled_date'] ?? json['scheduledDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      originalScheduledDate: DateTime.tryParse(
            (json['original_scheduled_date'] ??
                    json['originalScheduledDate'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      dueAmountCents:
          _toIntOrNull(json['due_amount_cents'] ?? json['dueAmountCents']) ?? 0,
      paidAmountCents:
          _toIntOrNull(json['paid_amount_cents'] ?? json['paidAmountCents']) ??
              0,
      remainingAmountCents: _toIntOrNull(
            json['remaining_amount_cents'] ?? json['remainingAmountCents'],
          ) ??
          0,
      status: _paymentOccurrenceStatusFromValue(json['status']),
      transactionId: json['transaction_id']?.toString() ??
          json['transactionId']?.toString(),
      generatedFromSkip:
          (json['generated_from_skip'] ?? json['generatedFromSkip']) == true,
      skippedReason: json['skipped_reason']?.toString() ??
          json['skippedReason']?.toString(),
    );
  }
}

class PaymentPlanDetailDto {
  final PaymentPlanDto plan;
  final List<PaymentPlanOccurrenceDto> occurrences;
  final List<Map<String, dynamic>> payments;

  const PaymentPlanDetailDto({
    required this.plan,
    required this.occurrences,
    required this.payments,
  });

  factory PaymentPlanDetailDto.fromJson(Map<String, dynamic> json) {
    return PaymentPlanDetailDto(
      plan: PaymentPlanDto.fromJson(
          (json['plan'] ?? const {}) as Map<String, dynamic>),
      occurrences: ((json['occurrences'] ?? const <dynamic>[]) as List)
          .whereType<Map<String, dynamic>>()
          .map(PaymentPlanOccurrenceDto.fromJson)
          .toList(growable: false),
      payments: ((json['payments'] ?? const <dynamic>[]) as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }
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
    return ScheduledListItemDto(
      id: (json['id'] ?? '').toString(),
      paymentPlanType: _paymentPlanTypeFromValue(
        json['payment_plan_type'] ?? json['paymentPlanType'],
      ),
      type: (json['type'] ?? 'expense').toString(),
      title: (json['title'] ?? json['category'] ?? 'Plan').toString(),
      category: (json['category'] ?? 'other').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      displayAmountCents: _toIntOrNull(
              json['display_amount_cents'] ?? json['displayAmountCents']) ??
          0,
      nextDueDate: DateTime.tryParse((json['next_due_date'] ?? '').toString()),
      status: (json['status'] ?? 'active').toString(),
      progressText: json['progress_text']?.toString(),
      remainingBalanceCents: _toIntOrNull(
          json['remaining_balance_cents'] ?? json['remainingBalanceCents']),
      householdId: json['household_id']?.toString(),
    );
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

int? _toIntOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

PaymentPlanType _paymentPlanTypeFromValue(dynamic value) {
  return value?.toString().toLowerCase() == 'installment'
      ? PaymentPlanType.installment
      : PaymentPlanType.recurring;
}

PaymentPlanStatus _paymentPlanStatusFromValue(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'paused':
      return PaymentPlanStatus.paused;
    case 'completed':
      return PaymentPlanStatus.completed;
    case 'cancelled':
      return PaymentPlanStatus.cancelled;
    case 'defaulted':
      return PaymentPlanStatus.defaulted;
    default:
      return PaymentPlanStatus.active;
  }
}

PaymentOccurrenceStatus _paymentOccurrenceStatusFromValue(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'paid':
      return PaymentOccurrenceStatus.paid;
    case 'skipped':
      return PaymentOccurrenceStatus.skipped;
    case 'cancelled':
      return PaymentOccurrenceStatus.cancelled;
    case 'overdue':
      return PaymentOccurrenceStatus.overdue;
    case 'partially_paid':
      return PaymentOccurrenceStatus.partiallyPaid;
    case 'settled_early':
      return PaymentOccurrenceStatus.settledEarly;
    default:
      return PaymentOccurrenceStatus.scheduled;
  }
}
