import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

void main() {
  group('SplitType - Enum', () {
    test('toJson returns correct string values', () {
      expect(SplitType.equal.toJson(), 'equal');
      expect(SplitType.percentage.toJson(), 'percentage');
      expect(SplitType.amount.toJson(), 'amount');
      expect(SplitType.shares.toJson(), 'shares');
    });

    test('fromJson parses correct enum values', () {
      expect(SplitType.fromJson('equal'), SplitType.equal);
      expect(SplitType.fromJson('percentage'), SplitType.percentage);
      expect(SplitType.fromJson('amount'), SplitType.amount);
      expect(SplitType.fromJson('shares'), SplitType.shares);
    });

    test('fromJson throws on invalid value', () {
      expect(
        () => SplitType.fromJson('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ExpenseSplitGroup - Model Creation', () {
    test('creates split group with required fields', () {
      final now = DateTime(2024, 1, 1);
      final group = ExpenseSplitGroup(
        id: 'split_1',
        householdId: 'hh_1',
        expenseId: 'exp_1',
        payerUserId: 'user_1',
        splitType: SplitType.equal,
        currency: 'USD',
        totalAmountCents: 10000,
        createdAt: now,
        updatedAt: now,
      );

      expect(group.id, 'split_1');
      expect(group.householdId, 'hh_1');
      expect(group.expenseId, 'exp_1');
      expect(group.payerUserId, 'user_1');
      expect(group.splitType, SplitType.equal);
      expect(group.currency, 'USD');
      expect(group.totalAmountCents, 10000);
      expect(group.description, null);
      expect(group.splitLines, null);
    });

    test('creates split group with optional fields', () {
      final now = DateTime(2024, 1, 1);
      final lines = [
        ExpenseSplitLine(
          id: 'line_1',
          splitGroupId: 'split_1',
          userId: 'user_1',
          amountCents: 5000,
          isSettled: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final group = ExpenseSplitGroup(
        id: 'split_1',
        householdId: 'hh_1',
        expenseId: 'exp_1',
        payerUserId: 'user_1',
        splitType: SplitType.amount,
        currency: 'USD',
        totalAmountCents: 10000,
        description: 'Dinner split',
        createdAt: now,
        updatedAt: now,
        payerEmail: 'payer@example.com',
        splitLines: lines,
      );

      expect(group.description, 'Dinner split');
      expect(group.payerEmail, 'payer@example.com');
      expect(group.splitLines, lines);
    });
  });

  group('ExpenseSplitGroup - JSON Serialization', () {
    test('fromJson parses split group correctly', () {
      final json = {
        'id': 'split_1',
        'household_id': 'hh_1',
        'expense_id': 'exp_1',
        'payer_user_id': 'user_1',
        'split_type': 'percentage',
        'currency': 'USD',
        'total_amount_cents': 10000,
        'description': 'Dinner',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'payer_email': 'payer@example.com',
      };

      final group = ExpenseSplitGroup.fromJson(json);

      expect(group.id, 'split_1');
      expect(group.expenseId, 'exp_1');
      expect(group.splitType, SplitType.percentage);
      expect(group.totalAmountCents, 10000);
      expect(group.description, 'Dinner');
    });

    test('fromJson parses nested split lines from expense_split_lines', () {
      final json = {
        'id': 'split_1',
        'household_id': 'hh_1',
        'expense_id': 'exp_1',
        'payer_user_id': 'user_1',
        'split_type': 'equal',
        'currency': 'USD',
        'total_amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'expense_split_lines': [
          {
            'id': 'line_1',
            'split_group_id': 'split_1',
            'user_id': 'user_1',
            'amount_cents': 5000,
            'is_settled': false,
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-01T00:00:00.000Z',
          },
        ],
      };

      final group = ExpenseSplitGroup.fromJson(json);

      expect(group.splitLines, isNotNull);
      expect(group.splitLines!.length, 1);
      expect(group.splitLines![0].id, 'line_1');
    });

    test('fromJson parses nested split lines from split_lines', () {
      final json = {
        'id': 'split_1',
        'household_id': 'hh_1',
        'expense_id': 'exp_1',
        'payer_user_id': 'user_1',
        'split_type': 'equal',
        'currency': 'USD',
        'total_amount_cents': 10000,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'split_lines': [
          {
            'id': 'line_1',
            'split_group_id': 'split_1',
            'user_id': 'user_1',
            'amount_cents': 5000,
            'is_settled': true,
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-01T00:00:00.000Z',
          },
        ],
      };

      final group = ExpenseSplitGroup.fromJson(json);

      expect(group.splitLines, isNotNull);
      expect(group.splitLines!.length, 1);
      expect(group.splitLines![0].isSettled, true);
    });

    test('toJson serializes split group correctly', () {
      final now = DateTime(2024, 1, 1);
      final lines = [
        ExpenseSplitLine(
          id: 'line_1',
          splitGroupId: 'split_1',
          userId: 'user_1',
          amountCents: 5000,
          isSettled: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final group = ExpenseSplitGroup(
        id: 'split_1',
        householdId: 'hh_1',
        expenseId: 'exp_1',
        payerUserId: 'user_1',
        splitType: SplitType.shares,
        currency: 'USD',
        totalAmountCents: 10000,
        description: 'Dinner',
        createdAt: now,
        updatedAt: now,
        splitLines: lines,
      );

      final json = group.toJson();

      expect(json['id'], 'split_1');
      expect(json['expense_id'], 'exp_1');
      expect(json['split_type'], 'shares');
      expect(json['total_amount_cents'], 10000);
      expect(json['split_lines'], isA<List>());
      expect((json['split_lines'] as List).length, 1);
    });
  });

  group('ExpenseSplitLine - Model Creation', () {
    test('creates split line with amount', () {
      final now = DateTime(2024, 1, 1);
      final line = ExpenseSplitLine(
        id: 'line_1',
        splitGroupId: 'split_1',
        userId: 'user_1',
        amountCents: 5000,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(line.id, 'line_1');
      expect(line.splitGroupId, 'split_1');
      expect(line.userId, 'user_1');
      expect(line.amountCents, 5000);
      expect(line.percentage, null);
      expect(line.shares, null);
      expect(line.isSettled, false);
      expect(line.settledAt, null);
    });

    test('creates split line with percentage', () {
      final now = DateTime(2024, 1, 1);
      final line = ExpenseSplitLine(
        id: 'line_1',
        splitGroupId: 'split_1',
        userId: 'user_1',
        percentage: 50.0,
        isSettled: true,
        settledAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(line.percentage, 50.0);
      expect(line.isSettled, true);
      expect(line.settledAt, now);
    });

    test('creates split line with shares', () {
      final now = DateTime(2024, 1, 1);
      final line = ExpenseSplitLine(
        id: 'line_1',
        splitGroupId: 'split_1',
        userId: 'user_1',
        shares: 2,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
        userEmail: 'user@example.com',
        userName: 'John Doe',
      );

      expect(line.shares, 2);
      expect(line.userEmail, 'user@example.com');
      expect(line.userName, 'John Doe');
    });
  });

  group('ExpenseSplitLine - JSON Serialization', () {
    test('fromJson parses split line with amount', () {
      final json = {
        'id': 'line_1',
        'split_group_id': 'split_1',
        'user_id': 'user_1',
        'amount_cents': 5000,
        'is_settled': false,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'user_email': 'user@example.com',
        'user_name': 'John Doe',
      };

      final line = ExpenseSplitLine.fromJson(json);

      expect(line.id, 'line_1');
      expect(line.amountCents, 5000);
      expect(line.isSettled, false);
      expect(line.userEmail, 'user@example.com');
      expect(line.userName, 'John Doe');
    });

    test('fromJson parses split line with percentage', () {
      final json = {
        'id': 'line_1',
        'split_group_id': 'split_1',
        'user_id': 'user_1',
        'percentage': 33.33,
        'is_settled': true,
        'settled_at': '2024-01-02T00:00:00.000Z',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'settled_by_user_id': 'user_2',
      };

      final line = ExpenseSplitLine.fromJson(json);

      expect(line.percentage, closeTo(33.33, 0.01));
      expect(line.isSettled, true);
      expect(line.settledAt, DateTime.utc(2024, 1, 2));
      expect(line.settledByUserId, 'user_2');
    });

    test('fromJson handles integer percentage', () {
      final json = {
        'id': 'line_1',
        'split_group_id': 'split_1',
        'user_id': 'user_1',
        'percentage': 50,
        'is_settled': false,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final line = ExpenseSplitLine.fromJson(json);

      expect(line.percentage, 50.0);
    });

    test('toJson serializes split line correctly', () {
      final now = DateTime(2024, 1, 1);
      final settledAt = DateTime(2024, 1, 2);

      final line = ExpenseSplitLine(
        id: 'line_1',
        splitGroupId: 'split_1',
        userId: 'user_1',
        amountCents: 5000,
        percentage: 50.0,
        shares: 2,
        isSettled: true,
        settledAt: settledAt,
        createdAt: now,
        updatedAt: now,
        userEmail: 'user@example.com',
        userName: 'John Doe',
        settledByUserId: 'user_2',
      );

      final json = line.toJson();

      expect(json['id'], 'line_1');
      expect(json['amount_cents'], 5000);
      expect(json['percentage'], 50.0);
      expect(json['shares'], 2);
      expect(json['is_settled'], true);
      expect(json['settled_at'], '2024-01-02T00:00:00.000');
      expect(json['user_email'], 'user@example.com');
      expect(json['settled_by_user_id'], 'user_2');
    });
  });

  group('SplitRequest - Model Creation', () {
    test('creates split request with required fields', () {
      const request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.equal,
        currency: 'USD',
        totalAmountCents: 10000,
        splits: [
          SplitLineRequest(userId: 'user_1', amountCents: 5000),
          SplitLineRequest(userId: 'user_2', amountCents: 5000),
        ],
      );

      expect(request.expenseId, 'exp_1');
      expect(request.householdId, 'hh_1');
      expect(request.splitType, SplitType.equal);
      expect(request.splits.length, 2);
      expect(request.description, null);
    });

    test('creates split request with description', () {
      const request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.percentage,
        currency: 'USD',
        totalAmountCents: 10000,
        description: 'Dinner split',
        splits: [
          SplitLineRequest(userId: 'user_1', percentage: 60.0),
          SplitLineRequest(userId: 'user_2', percentage: 40.0),
        ],
      );

      expect(request.description, 'Dinner split');
      expect(request.splits[0].percentage, 60.0);
      expect(request.splits[1].percentage, 40.0);
    });
  });

  group('SplitRequest - JSON Serialization', () {
    test('fromJson parses split request correctly', () {
      final json = {
        'expense_id': 'exp_1',
        'household_id': 'hh_1',
        'payer_user_id': 'user_1',
        'split_type': 'amount',
        'currency': 'USD',
        'total_amount_cents': 10000,
        'description': 'Dinner',
        'splits': [
          {'user_id': 'user_1', 'amount_cents': 6000},
          {'user_id': 'user_2', 'amount_cents': 4000},
        ],
      };

      final request = SplitRequest.fromJson(json);

      expect(request.expenseId, 'exp_1');
      expect(request.splitType, SplitType.amount);
      expect(request.description, 'Dinner');
      expect(request.splits.length, 2);
      expect(request.splits[0].amountCents, 6000);
    });

    test('toJson serializes split request correctly', () {
      const request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.shares,
        currency: 'USD',
        totalAmountCents: 10000,
        description: 'Dinner',
        splits: [
          SplitLineRequest(userId: 'user_1', shares: 2),
          SplitLineRequest(userId: 'user_2', shares: 1),
        ],
      );

      final json = request.toJson();

      expect(json['expense_id'], 'exp_1');
      expect(json['split_type'], 'shares');
      expect(json['description'], 'Dinner');
      expect(json['splits'], isA<List>());
      expect((json['splits'] as List).length, 2);
    });
  });

  group('SplitLineRequest - Model Creation', () {
    test('creates split line request with amount', () {
      const request = SplitLineRequest(
        userId: 'user_1',
        amountCents: 5000,
      );

      expect(request.userId, 'user_1');
      expect(request.amountCents, 5000);
      expect(request.percentage, null);
      expect(request.shares, null);
    });

    test('creates split line request with percentage', () {
      const request = SplitLineRequest(
        userId: 'user_1',
        percentage: 50.0,
      );

      expect(request.percentage, 50.0);
      expect(request.amountCents, null);
    });

    test('creates split line request with shares', () {
      const request = SplitLineRequest(
        userId: 'user_1',
        shares: 3,
      );

      expect(request.shares, 3);
      expect(request.amountCents, null);
      expect(request.percentage, null);
    });
  });

  group('SplitLineRequest - JSON Serialization', () {
    test('fromJson parses split line request correctly', () {
      final json = {
        'user_id': 'user_1',
        'amount_cents': 5000,
        'percentage': 50.0,
        'shares': 2,
      };

      final request = SplitLineRequest.fromJson(json);

      expect(request.userId, 'user_1');
      expect(request.amountCents, 5000);
      expect(request.percentage, 50.0);
      expect(request.shares, 2);
    });

    test('fromJson handles integer percentage', () {
      final json = {
        'user_id': 'user_1',
        'percentage': 33,
      };

      final request = SplitLineRequest.fromJson(json);

      expect(request.percentage, 33.0);
    });

    test('toJson serializes split line request correctly', () {
      const request = SplitLineRequest(
        userId: 'user_1',
        amountCents: 5000,
        percentage: 50.0,
        shares: 2,
      );

      final json = request.toJson();

      expect(json['user_id'], 'user_1');
      expect(json['amount_cents'], 5000);
      expect(json['percentage'], 50.0);
      expect(json['shares'], 2);
    });

    test('toJson includes null values', () {
      const request = SplitLineRequest(
        userId: 'user_1',
        amountCents: 5000,
      );

      final json = request.toJson();

      expect(json['user_id'], 'user_1');
      expect(json['amount_cents'], 5000);
      expect(json['percentage'], null);
      expect(json['shares'], null);
    });
  });

  group('Split Types - Edge Cases', () {
    test('handles equal split with multiple members', () {
      final request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.equal,
        currency: 'USD',
        totalAmountCents: 10000,
        splits: List.generate(
          5,
          (i) => SplitLineRequest(userId: 'user_$i', amountCents: 2000),
        ),
      );

      expect(request.splits.length, 5);
      expect(request.splits.every((s) => s.amountCents == 2000), true);
    });

    test('handles percentage split totaling 100%', () {
      const request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.percentage,
        currency: 'USD',
        totalAmountCents: 10000,
        splits: [
          SplitLineRequest(userId: 'user_1', percentage: 60.0),
          SplitLineRequest(userId: 'user_2', percentage: 25.0),
          SplitLineRequest(userId: 'user_3', percentage: 15.0),
        ],
      );

      final totalPercentage = request.splits
          .map((s) => s.percentage ?? 0.0)
          .reduce((a, b) => a + b);
      expect(totalPercentage, 100.0);
    });

    test('handles shares split with varying shares', () {
      const request = SplitRequest(
        expenseId: 'exp_1',
        householdId: 'hh_1',
        payerUserId: 'user_1',
        splitType: SplitType.shares,
        currency: 'USD',
        totalAmountCents: 10000,
        splits: [
          SplitLineRequest(userId: 'user_1', shares: 3),
          SplitLineRequest(userId: 'user_2', shares: 2),
          SplitLineRequest(userId: 'user_3', shares: 1),
        ],
      );

      final totalShares =
          request.splits.map((s) => s.shares ?? 0).reduce((a, b) => a + b);
      expect(totalShares, 6);
    });
  });
}
