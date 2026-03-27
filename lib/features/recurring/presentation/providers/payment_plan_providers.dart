import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/domain/models/payment_plan.dart';

final scheduledListItemsProvider = FutureProvider.family
    .autoDispose<List<ScheduledListItemDto>, String?>((ref, householdId) async {
  final query = supabase.from('scheduled_list_items').select('*');

  final data = householdId == null
      ? await query.isFilter('household_id', null)
      : await query.eq('household_id', householdId);

  return (data as List)
      .whereType<Map<String, dynamic>>()
      .map(ScheduledListItemDto.fromJson)
      .toList(growable: false);
});

final paymentPlanDetailProvider = FutureProvider.family
    .autoDispose<PaymentPlanDetailDto, String>((ref, planId) async {
  final response = await supabase.rpc(
    'get_payment_plan_detail',
    params: {'p_plan_id': planId},
  );

  return PaymentPlanDetailDto.fromJson(response as Map<String, dynamic>);
});

class PaymentPlanMutationState {
  final bool isLoading;
  final String? error;

  const PaymentPlanMutationState({
    this.isLoading = false,
    this.error,
  });

  PaymentPlanMutationState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return PaymentPlanMutationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final paymentPlanMutationProvider = StateNotifierProvider<
    PaymentPlanMutationNotifier, PaymentPlanMutationState>(
  (ref) => PaymentPlanMutationNotifier(ref),
);

class PaymentPlanMutationNotifier
    extends StateNotifier<PaymentPlanMutationState> {
  PaymentPlanMutationNotifier(this.ref)
      : super(const PaymentPlanMutationState());

  final Ref ref;

  Future<Map<String, dynamic>?> createInstallmentPlan({
    required String userId,
    required String type,
    required String category,
    required String currency,
    required int principalAmountCents,
    required int interestFeeAmountCents,
    required int totalPayableAmountCents,
    required RecurrenceRuleDto recurrenceRule,
    int? installmentCount,
    int? installmentAmountCents,
    bool customScheduleMode = false,
    List<InstallmentScheduleLineDto> customSchedule = const [],
    bool allowPartialPayments = true,
    String? householdId,
    String privacyScope = 'full',
    String ownerType = 'me',
    String? payerUserId,
    String? contactId,
  }) {
    return _invokeAction(
      action: 'create_installment',
      fallbackError: 'Failed to create installment plan',
      body: {
        'userId': userId,
        'idempotencyKey':
            'moneko-mobile-installment-${DateTime.now().microsecondsSinceEpoch}',
        'type': type,
        'category': category,
        'currency': currency,
        'principalAmountCents': principalAmountCents,
        'interestFeeAmountCents': interestFeeAmountCents,
        'totalPayableAmountCents': totalPayableAmountCents,
        'recurrenceRule': recurrenceRule.toJson(),
        if (installmentCount != null) 'installmentCount': installmentCount,
        if (installmentAmountCents != null)
          'installmentAmountCents': installmentAmountCents,
        'customScheduleMode': customScheduleMode,
        'customSchedule': customSchedule.map((line) => line.toJson()).toList(),
        'allowPartialPayments': allowPartialPayments,
        if (householdId != null) 'householdId': householdId,
        if (contactId != null) 'contactId': contactId,
        'privacyScope': privacyScope,
        'ownerType': ownerType,
        if (payerUserId != null) 'payerUserId': payerUserId,
      },
      invalidatePlanIdFromResponse: true,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> createRecurringPlan({
    required String userId,
    required String type,
    required String category,
    required String currency,
    required int amountCents,
    required RecurrenceRuleDto recurrenceRule,
    String? householdId,
    String? contactId,
    String privacyScope = 'full',
    String ownerType = 'me',
    String? payerUserId,
  }) {
    return _invokeAction(
      action: 'create_recurring',
      fallbackError: 'Failed to create recurring plan',
      body: {
        'userId': userId,
        'idempotencyKey':
            'moneko-mobile-recurring-${DateTime.now().microsecondsSinceEpoch}',
        'type': type,
        'category': category,
        'currency': currency,
        'amountCents': amountCents,
        'recurrenceRule': recurrenceRule.toJson(),
        if (householdId != null) 'householdId': householdId,
        if (contactId != null) 'contactId': contactId,
        'privacyScope': privacyScope,
        'ownerType': ownerType,
        if (payerUserId != null) 'payerUserId': payerUserId,
      },
      invalidatePlanIdFromResponse: true,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> skipRecurring({
    required String userId,
    required String planId,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'skip_recurring',
      fallbackError: 'Failed to skip recurring occurrence',
      body: {
        'userId': userId,
        'planId': planId,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> skipInstallment({
    required String userId,
    required String planId,
    String? reason,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'skip_installment',
      fallbackError: 'Failed to skip installment occurrence',
      body: {
        'userId': userId,
        'planId': planId,
        if (reason != null) 'reason': reason,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> markPaid({
    required String userId,
    required String planId,
    required String occurrenceId,
    required int amountCents,
    required String paymentDate,
    String? notes,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'mark_paid',
      fallbackError: 'Failed to mark occurrence paid',
      body: {
        'userId': userId,
        'idempotencyKey':
            'moneko-mobile-pay-${DateTime.now().microsecondsSinceEpoch}',
        'planId': planId,
        'occurrenceId': occurrenceId,
        'amountCents': amountCents,
        'paymentDate': paymentDate,
        if (notes != null) 'notes': notes,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> markPartiallyPaid({
    required String userId,
    required String planId,
    required String occurrenceId,
    required int amountCents,
    required String paymentDate,
    String? notes,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'mark_partially_paid',
      fallbackError: 'Failed to record partial payment',
      body: {
        'userId': userId,
        'idempotencyKey':
            'moneko-mobile-partial-${DateTime.now().microsecondsSinceEpoch}',
        'planId': planId,
        'occurrenceId': occurrenceId,
        'amountCents': amountCents,
        'paymentDate': paymentDate,
        if (notes != null) 'notes': notes,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> earlyPayoff({
    required String userId,
    required String planId,
    required int amountCents,
    required String paymentDate,
    String? notes,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'early_payoff',
      fallbackError: 'Failed to settle remaining balance',
      body: {
        'userId': userId,
        'idempotencyKey':
            'moneko-mobile-payoff-${DateTime.now().microsecondsSinceEpoch}',
        'planId': planId,
        'amountCents': amountCents,
        'paymentDate': paymentDate,
        if (notes != null) 'notes': notes,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> cancelPlan({
    required String userId,
    required String planId,
    String? reason,
    String? householdId,
  }) {
    return _invokeAction(
      action: 'cancel',
      fallbackError: 'Failed to cancel payment plan',
      body: {
        'userId': userId,
        'planId': planId,
        if (reason != null) 'reason': reason,
      },
      planId: planId,
      householdId: householdId,
    );
  }

  Future<Map<String, dynamic>?> _invokeAction({
    required String action,
    required String fallbackError,
    required Map<String, dynamic> body,
    String? planId,
    String? householdId,
    bool invalidatePlanIdFromResponse = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.functions.invoke(
        'payment-plan',
        body: {
          'action': action,
          ...body,
        },
      );

      if (response.status >= 400) {
        final message = (response.data is Map<String, dynamic>)
            ? ((response.data['error'] ?? response.data['message']) as String?)
            : null;
        state = state.copyWith(
          isLoading: false,
          error: message ?? fallbackError,
        );
        return null;
      }

      final data = response.data as Map<String, dynamic>?;
      final responsePlan = data?['plan'];
      final responsePlanMap =
          responsePlan is Map<String, dynamic> ? responsePlan : null;
      String? effectivePlanId = planId;
      if (effectivePlanId == null && invalidatePlanIdFromResponse) {
        effectivePlanId = responsePlanMap?['id']?.toString();
      }

      _invalidateRelatedProviders(
        householdId: householdId,
        planId: effectivePlanId,
      );

      state = state.copyWith(isLoading: false, error: null);
      return data;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
      return null;
    }
  }

  void _invalidateRelatedProviders({
    required String? householdId,
    required String? planId,
  }) {
    ref.invalidate(scheduledListItemsProvider(householdId));
    if (planId != null && planId.isNotEmpty) {
      ref.invalidate(paymentPlanDetailProvider(planId));
    }
  }
}
