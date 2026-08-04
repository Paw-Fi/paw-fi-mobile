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

    test('percentage split conserves every cent after rounding', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 10.01,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b'), _member('user-c')],
        autoSplitEnabled: true,
        autoSplitConfig: null,
        keepSemanticallyEqualCustomSplits: true,
        rawCustomSplits: {
          'splitType': 'percentage',
          'memberSplits': [
            {'userId': 'user-a', 'percentage': 33.33},
            {'userId': 'user-b', 'percentage': 33.33},
            {'userId': 'user-c', 'percentage': 33.34},
          ],
        },
      );

      final cents =
          group!.splitLines!.map((line) => line.amountCents!).toList();
      expect(cents.reduce((left, right) => left + right), 1001);
      expect(cents, everyElement(greaterThan(0)));
    });

    test('share split conserves every cent for an uneven total', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 10,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b'), _member('user-c')],
        autoSplitEnabled: true,
        autoSplitConfig: null,
        keepSemanticallyEqualCustomSplits: true,
        rawCustomSplits: {
          'splitType': 'shares',
          'memberSplits': [
            {'userId': 'user-a', 'shares': 1},
            {'userId': 'user-b', 'shares': 1},
            {'userId': 'user-c', 'shares': 1},
          ],
        },
      );

      final cents =
          group!.splitLines!.map((line) => line.amountCents!).toList();
      expect(cents.reduce((left, right) => left + right), 1000);
      expect(cents, everyElement(greaterThan(0)));
    });

    test('preserves an explicit equal-valued custom amount split', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 20,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b')],
        autoSplitEnabled: true,
        autoSplitConfig: {
          'splitType': 'shares',
          'memberSplits': [
            {'userId': 'user-a', 'shares': 3},
            {'userId': 'user-b', 'shares': 1},
          ],
        },
        keepSemanticallyEqualCustomSplits: true,
        rawCustomSplits: {
          'splitType': 'amount',
          'memberSplits': [
            {'userId': 'user-a', 'amount': 10},
            {'userId': 'user-b', 'amount': 10},
          ],
        },
      );

      expect(group!.splitType, SplitType.amount);
      expect(group.splitLines!.map((line) => line.amountCents), [1000, 1000]);
    });
  });
}
