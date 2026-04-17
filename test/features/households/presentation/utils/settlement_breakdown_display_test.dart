import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/presentation/utils/settlement_breakdown_display.dart';

void main() {
  group('calculateSettlementBreakdownRowsNetCents', () {
    test('returns zero when there are no rows', () {
      final result = calculateSettlementBreakdownRowsNetCents(
        rows: const <SettlementBreakdownRowV2>[],
      );

      expect(result, 0);
    });

    test('returns row total when rows are available', () {
      final rows = [
        SettlementBreakdownRowV2(
          direction: SettlementBreakdownDirectionV2.youOwe,
          expenseId: 'expense-1',
          splitGroupId: 'group-1',
          splitLineId: 'line-1',
          expenseDate: DateTime(2026, 4, 15),
          totalAmountCents: 1000000,
          remainingAmountCents: 300000,
        ),
        SettlementBreakdownRowV2(
          direction: SettlementBreakdownDirectionV2.theyOweYou,
          expenseId: 'expense-2',
          splitGroupId: 'group-2',
          splitLineId: 'line-2',
          expenseDate: DateTime(2026, 4, 14),
          totalAmountCents: 200000,
          remainingAmountCents: 50000,
        ),
      ];

      final result = calculateSettlementBreakdownRowsNetCents(
        rows: rows,
      );

      expect(result, 250000);
    });
  });

  group('calculateSettlementBreakdownAdjustmentCents', () {
    test('returns zero when there are no rows', () {
      final result = calculateSettlementBreakdownAdjustmentCents(
        fallbackNetCents: 1940415,
        rows: const <SettlementBreakdownRowV2>[],
      );

      expect(result, 0);
    });

    test('returns remainder not explained by visible rows', () {
      final rows = [
        SettlementBreakdownRowV2(
          direction: SettlementBreakdownDirectionV2.youOwe,
          expenseId: 'expense-1',
          splitGroupId: 'group-1',
          splitLineId: 'line-1',
          expenseDate: DateTime(2026, 4, 15),
          totalAmountCents: 1000000,
          remainingAmountCents: 300000,
        ),
      ];

      final result = calculateSettlementBreakdownAdjustmentCents(
        fallbackNetCents: 1940415,
        rows: rows,
      );

      expect(result, 1640415);
    });
  });
}
