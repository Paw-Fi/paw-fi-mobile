import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/domain/models/payment_plan.dart';

final scheduledListItemsProvider = FutureProvider.family
    .autoDispose<List<ScheduledListItemDto>, String?>((ref, householdId) async {
  final query = supabase.from('scheduled_list_items').select('*');

  final data = householdId == null
      ? await query.isFilter('household_id', null)
      : await query.eq('household_id', householdId);

  final items = (data as List)
      .whereType<Map<String, dynamic>>()
      .map(ScheduledListItemDto.fromJson)
      .toList(growable: false);

  return items;
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
  (ref) => PaymentPlanMutationNotifier(),
);

class PaymentPlanMutationNotifier
    extends StateNotifier<PaymentPlanMutationState> {
  PaymentPlanMutationNotifier() : super(const PaymentPlanMutationState());

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
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.functions.invoke(
        'create-installment-plan',
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
          'customSchedule':
              customSchedule.map((line) => line.toJson()).toList(),
          'allowPartialPayments': allowPartialPayments,
          if (householdId != null) 'householdId': householdId,
          if (contactId != null) 'contactId': contactId,
          'privacyScope': privacyScope,
          'ownerType': ownerType,
          if (payerUserId != null) 'payerUserId': payerUserId,
        },
      );

      if (response.status >= 400) {
        final message = (response.data is Map<String, dynamic>)
            ? ((response.data['error'] ?? response.data['message']) as String?)
            : null;
        state = state.copyWith(
          isLoading: false,
          error: message ?? 'Failed to create installment plan',
        );
        return null;
      }

      state = state.copyWith(isLoading: false, error: null);
      return response.data as Map<String, dynamic>?;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
      return null;
    }
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.functions.invoke(
        'create-recurring-plan',
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
      );

      if (response.status >= 400) {
        final message = (response.data is Map<String, dynamic>)
            ? ((response.data['error'] ?? response.data['message']) as String?)
            : null;
        state = state.copyWith(
          isLoading: false,
          error: message ?? 'Failed to create recurring plan',
        );
        return null;
      }

      state = state.copyWith(isLoading: false, error: null);
      return response.data as Map<String, dynamic>?;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
      return null;
    }
  }
}
