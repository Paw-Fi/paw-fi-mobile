import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> householdSettlementTerminalStatuses = <String>{
  'applied',
  'snapshot_conflict',
  'nothing_to_settle',
};

Future<String> dispatchHouseholdSettlementMutation(
  SupabaseClient client,
  LocalMutationOutboxData mutation,
  Map<String, dynamic> rawPayload, {
  Future<void> Function(SettlementWriteResultV2)? onResult,
}) async {
  if (!isDurableHouseholdSettlementMutation(mutation)) {
    throw StateError('Mutation is not a durable household settlement');
  }
  final payload = LocalHouseholdSettlementMutationPayload.fromJson(rawPayload);
  if (payload.clientMutationId != mutation.clientMutationId ||
      payload.householdId != mutation.entityId) {
    throw StateError('Settlement mutation identity does not match its payload');
  }

  final result = await client.rpc(
    'households_settle_amount_and_notify_v2',
    params: <String, dynamic>{
      'p_household_id': payload.householdId,
      'p_member_user_id': payload.memberUserId,
      'p_mode': payload.mode,
      'p_amount_cents': payload.amountCents,
      'p_currency': payload.currency,
      'p_settlement_note': payload.note,
      'p_expected_snapshot_token': payload.expectedSnapshotToken,
      'p_client_mutation_id': payload.clientMutationId,
    },
  );
  final resultMap = result is Map<String, dynamic>
      ? result
      : result is Map
          ? Map<String, dynamic>.from(result)
          : null;
  if (resultMap == null) {
    throw StateError(
      'Settlement RPC returned an unknown or malformed terminal status',
    );
  }
  final parsed = parseHouseholdSettlementWriteResult(
    resultMap,
    expectedClientMutationId: payload.clientMutationId,
    expectedAmountCents: payload.amountCents,
  );
  final status = resultMap['status']?.toString().trim().toLowerCase();
  if (status == null ||
      !householdSettlementTerminalStatuses.contains(status) ||
      (parsed.status == SettlementWriteStatusV2.applied &&
          status != 'applied')) {
    throw StateError(
      'Settlement RPC returned an unknown or malformed terminal status',
    );
  }
  await onResult?.call(parsed);
  return status;
}

Future<void> persistHouseholdSettlementAcknowledgement({
  required MonekoDatabase database,
  required String actorUserId,
  required LocalHouseholdSettlementMutationPayload payload,
  required SettlementWriteResultV2 result,
}) async {
  if (result.status != SettlementWriteStatusV2.applied) return;
  // Only a validated server acknowledgement determines express payment direction.
  final creditor =
      result.pairBalanceBeforeCents > 0 ? payload.memberUserId : actorUserId;
  final debtor =
      result.pairBalanceBeforeCents > 0 ? actorUserId : payload.memberUserId;
  await database.upsertJsonCache(
    namespace: localHouseholdSettlementAcknowledgementNamespace,
    cacheKey: '$actorUserId|${payload.householdId}|${payload.clientMutationId}',
    payload: {
      'id': result.settlementEventId,
      'client_mutation_id': payload.clientMutationId,
      'actor_user_id': actorUserId,
      'payer_user_id': creditor,
      'participant_user_id': debtor,
      'amount_cents': result.appliedAmountCents,
      'currency': payload.currency,
    },
  );
}

SettlementWriteResultV2 parseHouseholdSettlementWriteResult(
  Map<String, dynamic> result, {
  required String expectedClientMutationId,
  required int expectedAmountCents,
}) {
  final parsed = SettlementWriteResultV2.fromJson(result);
  if (parsed.clientMutationId != expectedClientMutationId ||
      parsed.requestedAmountCents != expectedAmountCents) {
    throw const FormatException(
      'Settlement write response does not match the durable request',
    );
  }
  return parsed;
}
