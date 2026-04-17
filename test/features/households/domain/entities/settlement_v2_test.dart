import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';

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
    });
  });
}
