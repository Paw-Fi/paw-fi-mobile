import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

void main() {
  final recurringTransaction = RecurringTransaction(
    id: 'recurring-id',
    date: DateTime(2026, 7, 1),
    category: 'housing',
    amount: 100,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    type: 'expense',
    attachments: const [],
    createdAt: DateTime(2026, 7, 1),
  );

  test('includes editable financial fields for an unlocked occurrence', () {
    final command = RecurringOccurrenceUpdateCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
      ),
      paidDate: DateTime(2026, 7, 2),
      amountCents: 12550,
      accountId: 'account-id',
      merchant: 'Landlord',
      description: 'July rent',
      updateFutureAmount: true,
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
      'paidDate': '2026-07-02',
      'amount': 125.5,
      'accountId': 'account-id',
      'merchant': 'Landlord',
      'updateFutureAmount': true,
      'description': 'July rent',
    });
  });

  test('omits the wallet when confirming an unassigned occurrence', () {
    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      scheduledOccurrenceDate: DateTime(2026, 7, 1),
      paidDate: DateTime(2026, 7, 1),
      amountCents: 10000,
      accountId: null,
    );

    expect(command.toRequestBody(), isNot(contains('accountId')));
  });

  test('builds the one-off override payload without changing confirmation', () {
    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction.copyWith(type: 'income'),
      scheduledOccurrenceDate: DateTime(2026, 7, 1),
      paidDate: DateTime(2026, 7, 2),
      amountCents: 12550,
      accountId: 'account-id',
      functionName: 'save-recurring-occurrence-override',
      category: 'income:salary',
      currency: 'USD',
      source: 'Employer',
    );

    expect(command.functionName, 'save-recurring-occurrence-override');
    expect(command.toRequestBody(), containsPair('category', 'income:salary'));
    expect(command.toRequestBody(), containsPair('currency', 'USD'));
    expect(command.toRequestBody(), containsPair('source', 'Employer'));
  });

  test('sends only notes for a settlement-locked occurrence', () {
    final command = RecurringOccurrenceUpdateCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
        isSettlementLocked: true,
      ),
      paidDate: DateTime(2026, 7, 2),
      amountCents: null,
      accountId: null,
      merchant: 'Landlord',
      description: 'Corrected note',
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
      'description': 'Corrected note',
    });
  });

  test('keeps an unlocked unassigned occurrence unassigned', () {
    final command = RecurringOccurrenceUpdateCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
      ),
      paidDate: DateTime(2026, 7, 2),
      amountCents: 12550,
      accountId: null,
      description: 'July rent',
    );

    expect(command.toRequestBody(), isNot(contains('accountId')));
  });

  test('materializes the saved template split for an edited occurrence', () {
    final now = DateTime(2026, 8, 14);
    final plan = buildRecurringOccurrenceSplitPlan(
      templateGroup: ExpenseSplitGroup(
        id: 'template-split',
        householdId: 'household-id',
        expenseId: 'recurring-id',
        payerUserId: 'payer',
        splitType: SplitType.percentage,
        currency: 'USD',
        totalAmountCents: 100000,
        createdAt: now,
        updatedAt: now,
        splitLines: [
          ExpenseSplitLine(
            id: 'first',
            splitGroupId: 'template-split',
            userId: 'payer',
            amountCents: 60000,
            percentage: 60,
            isSettled: false,
            createdAt: now,
            updatedAt: now,
          ),
          ExpenseSplitLine(
            id: 'second',
            splitGroupId: 'template-split',
            userId: 'member',
            amountCents: 40000,
            percentage: 40,
            isSettled: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      optimisticExpenseId: 'optimistic-occurrence',
      occurrenceAmountCents: 80000,
    );

    expect(plan, isNotNull);
    expect(plan!.payerUserId, 'payer');
    expect(plan.requestPayload, {
      'splitType': 'amount',
      'memberSplits': [
        {'userId': 'payer', 'amount': 480.0},
        {'userId': 'member', 'amount': 320.0},
      ],
    });
    expect(plan.optimisticSplit.expenseId, 'optimistic-occurrence');
    expect(plan.optimisticSplit.id, 'optimistic_split_optimistic-occurrence');
    expect(plan.optimisticSplit.totalAmountCents, 80000);
    expect(
      plan.optimisticSplit.splitLines!.map((line) => line.amountCents),
      [48000, 32000],
    );
  });

  test('builds an unconfirm request for a confirmed occurrence', () {
    final command = RecurringOccurrenceUnconfirmCommand(
      userId: 'user-id',
      recurringTransaction: recurringTransaction,
      occurrence: RecurringOccurrenceTimelineItem(
        scheduledOccurrenceDate: DateTime(2026, 7, 1),
        status: 'confirmed',
      ),
    );

    expect(command.toRequestBody(), {
      'userId': 'user-id',
      'recurringId': 'recurring-id',
      'scheduledOccurrenceDate': '2026-07-01',
    });
  });
}
