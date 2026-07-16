import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';

String _snapshotToken(String character) =>
    'v1:${List<String>.filled(64, character).join()}';

void main() {
  group('SettlementPairwiseBalance', () {
    test('fromJson parses signed pairwise balance values', () {
      final balance = SettlementPairwiseBalance.fromJson({
        'other_user_id': 'user_b',
        'currency': 'usd',
        'split_to_cents': 30000,
        'split_from_cents': 0,
        'paid_to_cents': 0,
        'paid_from_cents': 0,
        'net_cents': 30000,
      });

      expect(balance.otherUserId, 'user_b');
      expect(balance.currency, 'USD');
      expect(balance.splitToCents, 30000);
      expect(balance.splitFromCents, 0);
      expect(balance.paidToCents, 0);
      expect(balance.paidFromCents, 0);
      expect(balance.netCents, 30000);
      expect(balance.youOweCents, 30000);
      expect(balance.youAreOwedCents, 0);
    });

    test('rejects fractional and negative component cents', () {
      final valid = <String, dynamic>{
        'other_user_id': 'user_b',
        'currency': 'USD',
        'split_to_cents': 30000,
        'split_from_cents': 0,
        'paid_to_cents': 0,
        'paid_from_cents': 0,
        'net_cents': 30000,
      };

      expect(
        () => SettlementPairwiseBalance.fromJson({
          ...valid,
          'split_to_cents': 30000.5,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SettlementPairwiseBalance.fromJson({
          ...valid,
          'paid_from_cents': -1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a net that does not reconcile to its components', () {
      expect(
        () => SettlementPairwiseBalance.fromJson({
          'other_user_id': 'user_b',
          'currency': 'USD',
          'split_to_cents': 10000,
          'split_from_cents': 2500,
          'paid_to_cents': 1000,
          'paid_from_cents': 500,
          'net_cents': 6999,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SettlementBreakdownRowV2', () {
    test('fromJson parses canonical breakdown row values', () {
      final row = SettlementBreakdownRowV2.fromJson({
        'direction': 'you_owe',
        'expense_id': 'expense_1',
        'split_group_id': 'group_1',
        'split_line_id': 'line_1',
        'expense_date': '2026-01-12T00:00:00.000Z',
        'expense_description': 'Dinner',
        'expense_category': 'Food',
        'expense_raw_text': 'Dinner at cafe',
        'expense_type': 'expense',
        'total_amount_cents': 5000,
        'remaining_amount_cents': 2500,
      });

      expect(row.direction, SettlementBreakdownDirectionV2.youOwe);
      expect(row.expenseId, 'expense_1');
      expect(row.splitGroupId, 'group_1');
      expect(row.splitLineId, 'line_1');
      expect(row.expenseDescription, 'Dinner');
      expect(row.expenseCategory, 'Food');
      expect(row.expenseRawText, 'Dinner at cafe');
      expect(row.expenseType, 'expense');
      expect(row.totalAmountCents, 5000);
      expect(row.remainingAmountCents, 2500);
      expect(row.isAdjustment, isFalse);
    });

    test('fromJson allows synthetic adjustment rows', () {
      final row = SettlementBreakdownRowV2.fromJson({
        'direction': 'you_owe',
        'expense_id': null,
        'split_group_id': null,
        'split_line_id': null,
        'expense_date': '2026-04-17T00:00:00.000Z',
        'expense_description': 'Settlement adjustment',
        'expense_category': null,
        'expense_raw_text': null,
        'expense_type': 'adjustment',
        'total_amount_cents': 1640415,
        'remaining_amount_cents': 1640415,
      });

      expect(row.expenseId, isNull);
      expect(row.splitGroupId, isNull);
      expect(row.splitLineId, isNull);
      expect(row.expenseType, 'adjustment');
      expect(row.isAdjustment, isTrue);
      expect(row.kind, SettlementBreakdownKindV2.adjustment);
      expect(row.isSynthetic, isTrue);
    });

    test('fromJson parses a source-free legacy carryover distinctly', () {
      final row = SettlementBreakdownRowV2.fromJson({
        'direction': 'they_owe_you',
        'expense_id': null,
        'split_group_id': null,
        'split_line_id': null,
        'expense_date': '2026-07-16T00:00:00.000Z',
        'expense_description': 'Balance carried forward',
        'expense_category': null,
        'expense_raw_text': null,
        'expense_type': 'legacy_carryover',
        'total_amount_cents': 3912,
        'remaining_amount_cents': 3912,
      });

      expect(row.kind, SettlementBreakdownKindV2.legacyCarryover);
      expect(row.isLegacyCarryover, isTrue);
      expect(row.isAdjustment, isFalse);
      expect(row.isSynthetic, isTrue);
      expect(row.expenseId, isNull);
    });

    test('fromJson rejects a carryover tied to a transaction source', () {
      expect(
        () => SettlementBreakdownRowV2.fromJson({
          'direction': 'you_owe',
          'expense_id': 'expense-1',
          'split_group_id': null,
          'split_line_id': null,
          'expense_date': '2026-07-16T00:00:00.000Z',
          'expense_type': 'legacy_carryover',
          'total_amount_cents': 100,
          'remaining_amount_cents': 100,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SettlementCalculationV3', () {
    test('parses the atomic production net and both obligation directions', () {
      final calculation = SettlementCalculationV3.fromJson({
        'split_to_cents': 11223,
        'split_from_cents': 4612,
        'paid_to_cents': 0,
        'paid_from_cents': 0,
        'net_cents': 6611,
        'rows': [
          {
            'direction': 'you_owe',
            'expense_id': 'cat-food',
            'split_group_id': 'cat-food-group',
            'split_line_id': 'cat-food-line',
            'expense_date': '2026-07-16T00:54:59.202Z',
            'expense_description': 'Wet and dry catfood',
            'expense_category': 'Pets',
            'expense_raw_text': 'Wet and dry catfood',
            'expense_type': 'expense',
            'total_amount_cents': 11223,
            'remaining_amount_cents': 11223,
          },
          {
            'direction': 'they_owe_you',
            'expense_id': 'groceries',
            'split_group_id': 'groceries-group',
            'split_line_id': 'groceries-line',
            'expense_date': '2026-07-16T00:55:42.365Z',
            'expense_description': 'groceries',
            'expense_category': 'Groceries',
            'expense_raw_text': 'groceries',
            'expense_type': 'expense',
            'total_amount_cents': 4612,
            'remaining_amount_cents': 4612,
          },
        ],
      });

      expect(calculation.netCents, 6611);
      expect(calculation.rows, hasLength(2));
      expect(
        calculation.rows.map((row) => row.direction),
        [
          SettlementBreakdownDirectionV2.youOwe,
          SettlementBreakdownDirectionV2.theyOweYou,
        ],
      );
    });

    test('accepts only complete cryptographic snapshot metadata', () {
      final calculation = SettlementCalculationV3.fromJson({
        'snapshot_version': 1,
        'snapshot_token': _snapshotToken('a'),
        'household_id': 'household-1',
        'member_user_id': 'member-1',
        'currency': 'cad',
        'split_to_cents': 11223,
        'split_from_cents': 4612,
        'paid_to_cents': 0,
        'paid_from_cents': 0,
        'net_cents': 6611,
        'rows': const [],
      });

      expect(calculation.hasAuthoritativeSnapshotToken, isTrue);
      expect(calculation.snapshotToken, _snapshotToken('a'));
      expect(calculation.currency, 'CAD');

      expect(
        () => SettlementCalculationV3.fromJson({
          'snapshot_version': 1,
          'snapshot_token': 'v1:not-a-sha256',
          'household_id': 'household-1',
          'member_user_id': 'member-1',
          'currency': 'CAD',
          'net_cents': 0,
          'rows': const [],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SettlementCalculationV3.fromJson({
          'snapshot_version': 1,
          'household_id': 'household-1',
          'member_user_id': 'member-1',
          'currency': 'CAD',
          'net_cents': 0,
          'rows': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects components that do not reconcile to the canonical net', () {
      expect(
        () => SettlementCalculationV3.fromJson({
          'split_to_cents': 11223,
          'split_from_cents': 4612,
          'paid_to_cents': 0,
          'paid_from_cents': 0,
          'net_cents': 6610,
          'rows': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires net_cents so malformed data cannot look settled', () {
      expect(
        () => SettlementCalculationV3.fromJson({'rows': const []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects fractional or non-finite canonical net cents', () {
      expect(
        () => SettlementCalculationV3.fromJson({
          'net_cents': 66.11,
          'rows': const [],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SettlementCalculationV3.fromJson({
          'net_cents': double.infinity,
          'rows': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('filters deleted rows and removes their signed gross contribution',
        () {
      final calculation = SettlementCalculationV3(
        netCents: 6611,
        rows: [
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.youOwe,
            expenseId: 'deleted-expense',
            expenseDate: DateTime(2026, 7, 16),
            totalAmountCents: 11223,
            remainingAmountCents: 11223,
          ),
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.theyOweYou,
            expenseId: 'kept-expense',
            expenseDate: DateTime(2026, 7, 16),
            totalAmountCents: 4612,
            remainingAmountCents: 4612,
          ),
        ],
      );

      final filtered = calculation.excludingExpenseIds({'deleted-expense'});

      expect(filtered.netCents, -4612);
      expect(filtered.rows.single.expenseId, 'kept-expense');
    });

    test('deleting a partially paid row preserves the immutable payment', () {
      final calculation = SettlementCalculationV3(
        netCents: 2500,
        rows: [
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.youOwe,
            expenseId: 'partially-paid-expense',
            expenseDate: DateTime(2026, 7, 16),
            totalAmountCents: 5000,
            remainingAmountCents: 2500,
          ),
        ],
      );

      final filtered = calculation.excludingExpenseIds({
        'partially-paid-expense',
      });

      expect(filtered.netCents, -2500);
      expect(filtered.rows, isEmpty);
    });

    test('tombstone filtering preserves an unrelated backend adjustment', () {
      final calculation = SettlementCalculationV3(
        // Visible row net is 6,611 and the backend has a separate 100-cent
        // adjustment that must survive removing one deleted row.
        netCents: 6711,
        rows: [
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.youOwe,
            expenseId: 'deleted-expense',
            expenseDate: DateTime(2026, 7, 16),
            totalAmountCents: 11223,
            remainingAmountCents: 11223,
          ),
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.theyOweYou,
            expenseId: 'kept-expense',
            expenseDate: DateTime(2026, 7, 16),
            totalAmountCents: 4612,
            remainingAmountCents: 4612,
          ),
        ],
      );

      final filtered = calculation.excludingExpenseIds({'deleted-expense'});

      expect(filtered.netCents, -4512);
      expect(filtered.rows.single.remainingAmountCents, 4612);
    });
  });

  group('SettlementWriteResultV2', () {
    Map<String, dynamic> appliedResult() => {
          'status': 'applied',
          'replayed': false,
          'client_mutation_id': 'mobile:settlement:1',
          'settlement_event_id': 'event-1',
          'requested_amount_cents': 2500,
          'applied_amount_cents': 2500,
          'pair_balance_before_cents': 6611,
          'pair_balance_after_cents': 4111,
          'current_net_cents': 4111,
          'cleared_pair_balance': false,
          'result_snapshot_token': _snapshotToken('b'),
        };

    test('parses an exact applied response', () {
      final result = SettlementWriteResultV2.fromJson(appliedResult());

      expect(result.status, SettlementWriteStatusV2.applied);
      expect(result.appliedAmountCents, 2500);
      expect(result.pairBalanceAfterCents, 4111);
      expect(result.settlementEventId, 'event-1');
    });

    test('parses terminal conflict without inventing an event', () {
      final result = SettlementWriteResultV2.fromJson({
        'status': 'snapshot_conflict',
        'reason': 'snapshot_changed',
        'replayed': true,
        'client_mutation_id': 'mobile:settlement:2',
        'settlement_event_id': null,
        'requested_amount_cents': 2500,
        'applied_amount_cents': 0,
        'pair_balance_before_cents': 6611,
        'pair_balance_after_cents': 6611,
        'current_net_cents': 6611,
        'cleared_pair_balance': false,
        'result_snapshot_token': _snapshotToken('a'),
      });

      expect(result.status, SettlementWriteStatusV2.snapshotConflict);
      expect(result.replayed, isTrue);
      expect(result.appliedAmountCents, 0);
      expect(result.settlementEventId, isNull);
    });

    test('rejects malformed or internally inconsistent terminal results', () {
      expect(
        () => SettlementWriteResultV2.fromJson({
          ...appliedResult(),
          'applied_amount_cents': 2000,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SettlementWriteResultV2.fromJson({
          ...appliedResult(),
          'pair_balance_after_cents': -4111,
          'current_net_cents': -4111,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SettlementWriteResultV2.fromJson({
          ...appliedResult(),
          'result_snapshot_token': 'v1:invalid',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
