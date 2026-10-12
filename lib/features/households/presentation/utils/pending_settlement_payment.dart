import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';

/// Maps a durable settlement attempt to the same payer/participant direction
/// used by the settlement net calculator: payer is the expense creditor,
/// participant is the debtor paying them, not the cash recipient/sender.
/// Express netting deliberately has no
/// optimistic direction: only the authoritative settlement RPC can determine
/// which side of a netted balance pays.
SettlementPaymentRecord? pendingSettlementPaymentRecord({
  required String currentUserId,
  required String memberUserId,
  required String mode,
  required int amountCents,
  required String currency,
  String? clientMutationId,
}) {
  final actor = currentUserId.trim();
  final member = memberUserId.trim();
  if (actor.isEmpty || member.isEmpty || actor == member || amountCents <= 0) {
    return null;
  }

  switch (mode.trim().toLowerCase()) {
    case 'to_member':
      return SettlementPaymentRecord(
        actorUserId: actor,
        clientMutationId: clientMutationId,
        payerUserId: member,
        participantUserId: actor,
        amountCents: amountCents,
        currency: currency.trim().toUpperCase(),
      );
    case 'from_member':
      return SettlementPaymentRecord(
        actorUserId: actor,
        clientMutationId: clientMutationId,
        payerUserId: actor,
        participantUserId: member,
        amountCents: amountCents,
        currency: currency.trim().toUpperCase(),
      );
    case 'both':
      return null;
    default:
      return null;
  }
}
