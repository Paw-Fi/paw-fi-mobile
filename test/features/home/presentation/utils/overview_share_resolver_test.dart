import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/overview_share_resolver.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

void main() {
  group('normalizeTransactionType', () {
    test('normalizes whitespace and plural values', () {
      expect(normalizeTransactionType(' income '), 'income');
      expect(normalizeTransactionType('INCOMES'), 'income');
      expect(normalizeTransactionType(' expenses '), 'expense');
    });

    test('defaults null and empty to expense', () {
      expect(normalizeTransactionType(null), 'expense');
      expect(normalizeTransactionType('   '), 'expense');
    });
  });

  group('resolveUserShareRawAmountForOverview', () {
    const currentUserId = 'u1';

    ExpenseEntry buildEntry({
      required String id,
      String? householdId,
      String? userId,
      int amountCents = 10000,
      String? splitGroupId,
      List<String>? sharedMemberIds,
    }) {
      return ExpenseEntry(
        id: id,
        householdId: householdId,
        userId: userId,
        date: DateTime(2026, 1, 1),
        amountCents: amountCents,
        createdAt: DateTime(2026, 1, 1, 12),
        splitGroupId: splitGroupId,
        sharedMemberIds: sharedMemberIds,
      );
    }

    ExpenseSplitGroup buildAmountSplitGroup({
      required String id,
      required String expenseId,
      required List<ExpenseSplitLine> lines,
    }) {
      return ExpenseSplitGroup(
        id: id,
        householdId: 'h1',
        expenseId: expenseId,
        payerUserId: 'u2',
        splitType: SplitType.amount,
        currency: 'USD',
        totalAmountCents: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        splitLines: lines,
      );
    }

    ExpenseSplitLine buildLine({required String userId, int? amountCents}) {
      return ExpenseSplitLine(
        id: 'line-$userId',
        splitGroupId: 'g1',
        userId: userId,
        amountCents: amountCents,
        isSettled: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    test('returns full amount for personal entry', () {
      final entry = buildEntry(id: 'e1', userId: currentUserId);

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 100.0);
    });

    test('returns creator full amount for unsplit household entry', () {
      final entry = buildEntry(
        id: 'e2',
        householdId: 'h1',
        userId: currentUserId,
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 100.0);
    });

    test('returns zero for unsplit household entry by another user', () {
      final entry = buildEntry(
        id: 'e3',
        householdId: 'h1',
        userId: 'u2',
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 0.0);
    });

    test('uses normalized unique shared members for fallback split', () {
      final entry = buildEntry(
        id: 'e4',
        householdId: 'h1',
        userId: 'u2',
        sharedMemberIds: const [' u1 ', 'u2', 'u1', ''],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 50.0);
    });

    test('uses split group by expense id when available', () {
      final entry = buildEntry(
        id: 'e5',
        householdId: 'h1',
        userId: 'u2',
      );
      final group = buildAmountSplitGroup(
        id: 'g1',
        expenseId: 'e5',
        lines: [buildLine(userId: currentUserId, amountCents: 2500)],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: {'e5': group},
        splitGroupsById: const {},
      );

      expect(result, 25.0);
    });

    test(
        'falls back to creator full amount when split group id exists but group missing',
        () {
      final entry = buildEntry(
        id: 'e6',
        householdId: 'h1',
        userId: currentUserId,
        splitGroupId: 'missing',
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 100.0);
    });

    test(
        'falls back to shared members when split group id exists but group missing',
        () {
      final entry = buildEntry(
        id: 'e7',
        householdId: 'h1',
        userId: 'u2',
        splitGroupId: 'missing',
        sharedMemberIds: const ['u1', 'u2'],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: const {},
        splitGroupsById: const {},
      );

      expect(result, 50.0);
    });

    test('returns zero when split group exists and user has no split line', () {
      final entry = buildEntry(
        id: 'e8',
        householdId: 'h1',
        userId: 'u2',
        splitGroupId: 'g1',
      );
      final group = buildAmountSplitGroup(
        id: 'g1',
        expenseId: 'e8',
        lines: [buildLine(userId: 'u2', amountCents: 10000)],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: {'e8': group},
        splitGroupsById: {'g1': group},
      );

      expect(result, 0.0);
    });

    test('supports percentage split lines', () {
      final entry = buildEntry(
        id: 'e9',
        householdId: 'h1',
      );
      final group = ExpenseSplitGroup(
        id: 'g9',
        householdId: 'h1',
        expenseId: 'e9',
        payerUserId: 'u2',
        splitType: SplitType.percentage,
        currency: 'USD',
        totalAmountCents: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        splitLines: [
          ExpenseSplitLine(
            id: 'l9',
            splitGroupId: 'g9',
            userId: currentUserId,
            percentage: 25,
            isSettled: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: {'e9': group},
        splitGroupsById: {'g9': group},
      );

      expect(result, 25.0);
    });

    test('supports shares split lines', () {
      final entry = buildEntry(
        id: 'e10',
        householdId: 'h1',
      );
      final group = ExpenseSplitGroup(
        id: 'g10',
        householdId: 'h1',
        expenseId: 'e10',
        payerUserId: 'u2',
        splitType: SplitType.shares,
        currency: 'USD',
        totalAmountCents: 9000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        splitLines: [
          ExpenseSplitLine(
            id: 'l10-1',
            splitGroupId: 'g10',
            userId: currentUserId,
            shares: 1,
            isSettled: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          ExpenseSplitLine(
            id: 'l10-2',
            splitGroupId: 'g10',
            userId: 'u2',
            shares: 2,
            isSettled: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: {'e10': group},
        splitGroupsById: {'g10': group},
      );

      expect(result, 30.0);
    });

    test('supports equal split lines', () {
      final entry = buildEntry(
        id: 'e11',
        householdId: 'h1',
      );
      final group = ExpenseSplitGroup(
        id: 'g11',
        householdId: 'h1',
        expenseId: 'e11',
        payerUserId: 'u2',
        splitType: SplitType.equal,
        currency: 'USD',
        totalAmountCents: 12000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        splitLines: [
          ExpenseSplitLine(
            id: 'l11-1',
            splitGroupId: 'g11',
            userId: currentUserId,
            isSettled: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          ExpenseSplitLine(
            id: 'l11-2',
            splitGroupId: 'g11',
            userId: 'u2',
            isSettled: false,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final result = resolveUserShareRawAmountForOverview(
        entry: entry,
        currentUserId: currentUserId,
        splitGroupsByExpenseId: {'e11': group},
        splitGroupsById: {'g11': group},
      );

      expect(result, 60.0);
    });
  });
}
