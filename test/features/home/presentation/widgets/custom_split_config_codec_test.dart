import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_config_codec.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

void main() {
  group('custom split config codec', () {
    final members = [
      HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'u1',
        role: HouseholdRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        userName: 'Alex',
      ),
      HouseholdMember(
        id: 'm2',
        householdId: 'h1',
        userId: 'u2',
        role: HouseholdRole.member,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        userName: 'Sam',
      ),
      HouseholdMember(
        id: 'm3',
        householdId: 'h1',
        userId: 'u3',
        role: HouseholdRole.member,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        userName: 'Jordan',
      ),
    ];

    test('serializes and deserializes amount split config', () {
      final stored = serializeStoredSplitConfig(
        splitType: SplitType.amount,
        splits: [
          MemberSplit(
            member: members[0],
            amount: 2,
          ),
          MemberSplit(
            member: members[1],
            amount: 1,
          ),
          MemberSplit(
            member: members[2],
            amount: 0,
            includedInAmount: false,
          ),
        ],
      );

      final decoded = deserializeStoredSplitConfig(
        members: members,
        totalAmount: 3,
        config: stored,
      );

      expect(resolveStoredSplitType(stored), SplitType.amount);
      expect(decoded[0].amount, 2);
      expect(decoded[1].amount, 1);
      expect(decoded[2].includedInAmount, isFalse);
    });

    test('fills new members from defaults when stored config is stale', () {
      final decoded = deserializeStoredSplitConfig(
        members: members,
        totalAmount: 4,
        config: {
          'splitType': 'shares',
          'memberSplits': [
            {'userId': 'u1', 'shares': 3},
            {'userId': 'u2', 'shares': 1},
          ],
        },
      );

      expect(decoded, hasLength(3));
      expect(decoded[0].shares, 3);
      expect(decoded[1].shares, 1);
      expect(decoded[2].shares, isNull);
    });

    test('builds backend payload from percentage split config', () {
      final payload = buildCustomSplitsPayload(
        splitType: SplitType.percentage,
        splits: [
          MemberSplit(member: members[0], percentage: 50.0),
          MemberSplit(member: members[1], percentage: 30.0),
          MemberSplit(member: members[2], percentage: 20.0),
        ],
      );

      expect(payload?['splitType'], 'percentage');
      expect(payload?['memberSplits'], [
        {'userId': 'u1', 'percentage': 50.0},
        {'userId': 'u2', 'percentage': 30.0},
        {'userId': 'u3', 'percentage': 20.0},
      ]);
    });

    test('preserves two-member 40/60 percentage default payload', () {
      final stored = serializeStoredSplitConfig(
        splitType: SplitType.percentage,
        splits: [
          MemberSplit(member: members[0], percentage: 40.0),
          MemberSplit(member: members[1], percentage: 60.0),
        ],
      );
      final decoded = deserializeStoredSplitConfig(
        members: members.take(2).toList(),
        totalAmount: 15,
        config: stored,
      );
      final resolved = resolveStoredSplitsForTransaction(
        splitType: SplitType.percentage,
        splits: decoded,
        config: stored,
        totalAmount: 15,
      );

      final payload = buildCustomSplitsPayload(
        splitType: SplitType.percentage,
        splits: resolved,
      );

      expect(payload, {
        'splitType': 'percentage',
        'memberSplits': [
          {'userId': 'u1', 'percentage': 40.0},
          {'userId': 'u2', 'percentage': 60.0},
        ],
      });
    });

    test('preserves share default payloads for future transactions', () {
      final stored = serializeStoredSplitConfig(
        splitType: SplitType.shares,
        splits: [
          MemberSplit(member: members[0], shares: 2),
          MemberSplit(member: members[1], shares: 3),
        ],
      );
      final decoded = deserializeStoredSplitConfig(
        members: members.take(2).toList(),
        totalAmount: 15,
        config: stored,
      );
      final resolved = resolveStoredSplitsForTransaction(
        splitType: SplitType.shares,
        splits: decoded,
        config: stored,
        totalAmount: 15,
      );

      final payload = buildCustomSplitsPayload(
        splitType: SplitType.shares,
        splits: resolved,
      );

      expect(payload, {
        'splitType': 'shares',
        'memberSplits': [
          {'userId': 'u1', 'shares': 2},
          {'userId': 'u2', 'shares': 3},
        ],
      });
    });

    test('round-trips equal and null config as default equal splits', () {
      final decoded = deserializeStoredSplitConfig(
        members: members,
        totalAmount: 90,
        config: null,
      );

      final stored = serializeStoredSplitConfig(
        splitType: SplitType.equal,
        splits: decoded,
      );
      final payload = buildCustomSplitsPayload(
        splitType: SplitType.equal,
        splits: decoded,
      );

      expect(resolveStoredSplitType(null, fallback: SplitType.equal),
          SplitType.equal);
      expect(resolveStoredSplitType(stored), SplitType.equal);
      expect(decoded.map((split) => split.amount), [30, 30, 30]);
      expect(payload, {
        'splitType': 'equal',
        'memberSplits': [
          {'userId': 'u1'},
          {'userId': 'u2'},
          {'userId': 'u3'},
        ],
      });
    });

    test('builds income-compatible payload from stored amount defaults', () {
      final config = serializeStoredSplitConfig(
        splitType: SplitType.amount,
        splits: [
          MemberSplit(member: members[0], amount: 4.0),
          MemberSplit(member: members[1], amount: 2.0),
          MemberSplit(member: members[2], amount: 0.0, includedInAmount: false),
        ],
      );
      final splits = resolveStoredSplitsForTransaction(
        splitType: SplitType.amount,
        splits: deserializeStoredSplitConfig(
          members: members,
          totalAmount: 120,
          config: config,
        ),
        config: config,
        totalAmount: 120,
      );

      final payload = buildCustomSplitsPayload(
        splitType: SplitType.amount,
        splits: splits,
      );

      expect(payload, {
        'splitType': 'amount',
        'memberSplits': [
          {'userId': 'u1', 'amount': 80.0},
          {'userId': 'u2', 'amount': 40.0},
          {'userId': 'u3', 'amount': 0.0},
        ],
      });
    });

    test('rescales stored amount templates to the transaction total', () {
      final config = serializeStoredSplitConfig(
        splitType: SplitType.amount,
        splits: [
          MemberSplit(member: members[0], amount: 2.0),
          MemberSplit(member: members[1], amount: 1.0),
          MemberSplit(
            member: members[2],
            amount: 0,
            includedInAmount: false,
          ),
        ],
      );

      final splits = deserializeStoredSplitConfig(
        members: members,
        totalAmount: 90,
        config: config,
      );
      final rescaled = resolveStoredSplitsForTransaction(
        splitType: SplitType.amount,
        splits: splits,
        config: config,
        totalAmount: 90,
      );

      expect(rescaled[0].amount, 60);
      expect(rescaled[1].amount, 30);
      expect(rescaled[2].amount, 0);
    });
  });
}
