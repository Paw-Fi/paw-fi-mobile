import 'package:moneko/features/households/domain/entities/settlement_v2.dart';

int calculateSettlementBreakdownRowsNetCents({
  required List<SettlementBreakdownRowV2> rows,
}) {
  final youOweCents = rows
      .where((row) => row.direction == SettlementBreakdownDirectionV2.youOwe)
      .fold<int>(0, (sum, row) => sum + row.remainingAmountCents);
  final theyOweYouCents = rows
      .where(
          (row) => row.direction == SettlementBreakdownDirectionV2.theyOweYou)
      .fold<int>(0, (sum, row) => sum + row.remainingAmountCents);

  return youOweCents - theyOweYouCents;
}

int calculateSettlementBreakdownAdjustmentCents({
  required int fallbackNetCents,
  required List<SettlementBreakdownRowV2> rows,
}) {
  if (rows.isEmpty) {
    return 0;
  }

  return fallbackNetCents -
      calculateSettlementBreakdownRowsNetCents(
        rows: rows,
      );
}
