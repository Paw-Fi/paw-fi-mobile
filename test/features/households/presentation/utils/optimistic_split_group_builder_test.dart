import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/utils/optimistic_split_group_builder.dart';

HouseholdMember _member(String userId, {String? name}) {
  final now = DateTime(2026, 5, 15);
  return HouseholdMember(
    id: 'member-$userId',
    householdId: 'household-1',
    userId: userId,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    userName: name,
  );
}

void main() {
  group('buildOptimisticHouseholdSplitGroup', () {
    test('builds equal auto-split lines when household config is default', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 20,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b')],
        autoSplitEnabled: true,
        autoSplitConfig: null,
      );

      expect(group, isNotNull);
      expect(group!.splitType, SplitType.equal);
      expect(group.id, 'optimistic_split_expense-1');
      expect(group.splitLines!.map((line) => line.amountCents), [1000, 1000]);
      expect(
          group.splitLines!.map((line) => line.userId), ['user-a', 'user-b']);
    });

    test('explicit amount splits override household defaults', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 20,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b')],
        autoSplitEnabled: true,
        autoSplitConfig: null,
        rawCustomSplits: {
          'splitType': 'amount',
          'memberSplits': [
            {'userId': 'user-a', 'amount': 5},
            {'userId': 'user-b', 'amount': 15},
          ],
        },
      );

      expect(group, isNotNull);
      expect(group!.splitType, SplitType.amount);
      expect(group.splitLines!.map((line) => line.amountCents), [500, 1500]);
    });

    test('does not create fallback split lines when auto-split is disabled',
        () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 20,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b')],
        autoSplitEnabled: false,
        autoSplitConfig: null,
      );

      expect(group, isNull);
    });
  });
}
