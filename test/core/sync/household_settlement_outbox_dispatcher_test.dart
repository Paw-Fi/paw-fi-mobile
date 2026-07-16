import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/sync/household_settlement_outbox_dispatcher.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';

String _snapshotToken(String character) =>
    'v1:${List<String>.filled(64, character).join()}';

void main() {
  Map<String, dynamic> appliedResult() => {
        'status': 'applied',
        'replayed': true,
        'client_mutation_id': 'mobile:settlement:durable-1',
        'settlement_event_id': 'event-1',
        'requested_amount_cents': 2500,
        'applied_amount_cents': 2500,
        'pair_balance_before_cents': 6611,
        'pair_balance_after_cents': 4111,
        'current_net_cents': 4111,
        'cleared_pair_balance': false,
        'result_snapshot_token': _snapshotToken('b'),
      };

  test('accepts an exact replay for the durable settlement attempt', () {
    final parsed = parseHouseholdSettlementWriteResult(
      appliedResult(),
      expectedClientMutationId: 'mobile:settlement:durable-1',
      expectedAmountCents: 2500,
    );

    expect(parsed.status, SettlementWriteStatusV2.applied);
    expect(parsed.replayed, isTrue);
  });

  test('rejects a response for another mutation or amount', () {
    expect(
      () => parseHouseholdSettlementWriteResult(
        appliedResult(),
        expectedClientMutationId: 'mobile:settlement:other',
        expectedAmountCents: 2500,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseHouseholdSettlementWriteResult(
        appliedResult(),
        expectedClientMutationId: 'mobile:settlement:durable-1',
        expectedAmountCents: 2000,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a terminal label without a valid accounting result', () {
    expect(
      () => parseHouseholdSettlementWriteResult(
        {
          ...appliedResult(),
          'settlement_event_id': null,
        },
        expectedClientMutationId: 'mobile:settlement:durable-1',
        expectedAmountCents: 2500,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
