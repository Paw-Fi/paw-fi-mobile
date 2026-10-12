import 'dart:convert';
import 'dart:io';

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
    test(
        'mobile matches shared backend fixtures regardless of member display order',
        () {
      final fixtures = jsonDecode(
          File('test/fixtures/household_split_allocation_cases.json')
              .readAsStringSync()) as List;
      for (final fixture in fixtures.cast<Map>()) {
        final ids = (fixture['members'] as List).cast<String>();
        final values = fixture['values'] as List;
        final type = fixture['type'] as String;
        final field = type == 'amount'
            ? 'amount'
            : type == 'percentage'
                ? 'percentage'
                : 'shares';
        for (final reversed in [false, true]) {
          final group = buildOptimisticHouseholdSplitGroup(
            householdId: 'household-1',
            expenseId: 'new-expense',
            payerUserId: 'user-a',
            totalAmount: (fixture['cents'] as int) / 100,
            currency: 'EUR',
            members: (reversed ? ids.reversed : ids).map(_member).toList(),
            autoSplitEnabled: type == 'equal',
            autoSplitConfig: null,
            keepSemanticallyEqualCustomSplits: true,
            rawCustomSplits: type == 'equal'
                ? null
                : {
                    'splitType': type,
                    'memberSplits': [
                      for (var i = 0; i < ids.length; i++)
                        {'userId': ids[i], field: values[i]},
                    ],
                  },
          )!;
          final actual = {
            for (final id in ids) id: 0,
            for (final line in group.splitLines!) line.userId: line.amountCents
          };
          expect(actual, fixture['expected'],
              reason: '$type ${fixture['cents']} reversed=$reversed');
        }
      }
    });
    test('weighted custom and stored splits conserve 1 through 100 cents', () {
      final members =
          ['user-a', 'user-b', 'user-c', 'user-d'].map(_member).toList();
      for (final splitType in ['shares', 'percentage']) {
        final config = {
          'splitType': splitType,
          'memberSplits': [
            for (var index = 0; index < members.length; index++)
              {
                'userId': members[index].userId,
                'shares': index + 1,
                'percentage': (index + 1) * 10,
              },
          ],
        };
        for (final stored in [false, true]) {
          for (var cents = 1; cents <= 100; cents++) {
            final group = buildOptimisticHouseholdSplitGroup(
              householdId: 'household-1',
              expenseId: '$splitType-$stored-$cents',
              payerUserId: 'user-d',
              totalAmount: cents / 100,
              currency: 'EUR',
              members: members,
              autoSplitEnabled: stored,
              autoSplitConfig: stored ? config : null,
              rawCustomSplits: stored ? null : config,
              keepSemanticallyEqualCustomSplits: true,
            )!;
            expect(
              group.splitLines!
                  .fold<int>(0, (sum, line) => sum + line.amountCents!),
              cents,
              reason: '$splitType stored=$stored cents=$cents',
            );
            expect(group.splitLines!.map((line) => line.amountCents!),
                everyElement(greaterThan(0)));
          }
        }
      }
    });

    for (final splitType in ['shares', 'percentage']) {
      test('$splitType allocates a two-cent expense without inventing cents',
          () {
        final group = buildOptimisticHouseholdSplitGroup(
          householdId: 'household-1',
          expenseId: 'tiny',
          payerUserId: 'user-d',
          totalAmount: 0.02,
          currency: 'EUR',
          members:
              ['user-a', 'user-b', 'user-c', 'user-d'].map(_member).toList(),
          autoSplitEnabled: false,
          autoSplitConfig: null,
          keepSemanticallyEqualCustomSplits: true,
          rawCustomSplits: {
            'splitType': splitType,
            'memberSplits': [
              for (final id in ['user-a', 'user-b', 'user-c', 'user-d'])
                {'userId': id, 'shares': 1, 'percentage': 25},
            ],
          },
        )!;
        final allocated = {
          for (final line in group.splitLines!) line.userId: line.amountCents,
        };
        expect(allocated, {'user-a': 1, 'user-b': 1});
        expect(
            group.splitLines!
                .fold<int>(0, (sum, line) => sum + line.amountCents!),
            group.totalAmountCents);
      });
    }

    test('percentage fractional cents match canonical largest remainders', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'fractional',
        payerUserId: 'user-a',
        totalAmount: 10.01,
        currency: 'EUR',
        members: [_member('user-a'), _member('user-b'), _member('user-c')],
        autoSplitEnabled: false,
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
      )!;
      // Exact shares are 333.6333, 333.6333, 333.7334 cents.
      // C gets the first remainder, A wins the stable tie for the second.
      expect(
          group.splitLines!.map((line) => line.amountCents), [334, 333, 334]);
    });

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

    test('materializes an explicit equal split without household defaults', () {
      final group = buildOptimisticHouseholdSplitGroup(
        householdId: 'household-1',
        expenseId: 'expense-1',
        payerUserId: 'user-a',
        totalAmount: 10.01,
        currency: 'EUR',
        members: const [],
        autoSplitEnabled: false,
        autoSplitConfig: null,
        keepSemanticallyEqualCustomSplits: true,
        rawCustomSplits: {
          'splitType': 'equal',
          'memberSplits': [
            {'userId': 'user-a'},
            {'userId': 'user-b'},
          ],
        },
      );

      expect(group!.splitType, SplitType.equal);
      expect(group.splitLines!.map((line) => line.amountCents), [501, 500]);
    });
  });
}
