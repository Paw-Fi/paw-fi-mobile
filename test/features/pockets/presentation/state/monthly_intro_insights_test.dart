import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/monthly_intro_insights.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

void main() {
  group('evaluateMonthlyIntroInsights', () {
    final september2026 = DateTime(2026, 9, 1);
    final august2026 = DateTime(2026, 8, 1);

    test('Scenario 1: Rollover carry-over has top priority', () {
      final previousPockets = PocketsState(
        isLoading: false,
        saved: [
          PocketEnvelope(
            id: 'pocket-1',
            name: 'Dining',
            budgetAmountCents: 30000,
            spent: 200.0,
            currency: 'EUR',
            rolloverEnabled: true,
            availableBudgetCents: 30000,
            remainingCents: 10000, // 100.0 unspent carry
            lastUpdated: august2026,
          ),
          PocketEnvelope(
            id: 'pocket-2',
            name: 'Groceries',
            budgetAmountCents: 40000,
            spent: 270.0,
            currency: 'EUR',
            rolloverEnabled: true,
            availableBudgetCents: 40000,
            remainingCents: 13000, // 130.0 unspent carry -> total rollover = 230.0
            lastUpdated: august2026,
          ),
        ],
        editing: const [],
        periodMonth: august2026,
        previousBudget: 700.0,
        hasPreviousMonthPockets: true,
        currency: 'EUR',
        totalBudget: 700.0,
        savedTotalBudget: 700.0,
        unallocatedSpend: 0.0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
        previousPocketsState: previousPockets,
        monthsUsingMoneko: 16,
      );

      expect(state.primaryInsight.type, MonthlyInsightType.rolloverCarry);
      expect(state.primaryInsight.badge, 'ROLLOVER');
      expect(
        state.primaryInsight.headline,
        "You're starting September with €230 extra",
      );
      expect(state.primaryInsight.metric, '+€230');
      expect(state.milestoneText, '16 months with Moneko');
    });

    test('Scenario 2: Pocket overspent adjustment when rollover is zero', () {
      final previousPockets = PocketsState(
        isLoading: false,
        saved: [
          PocketEnvelope(
            id: 'pocket-1',
            name: 'Dining',
            budgetAmountCents: 20000,
            spent: 274.0, // Overspent by 74.0
            currency: 'EUR',
            rolloverEnabled: false,
            availableBudgetCents: 20000,
            remainingCents: -7400,
            lastUpdated: august2026,
          ),
          PocketEnvelope(
            id: 'pocket-2',
            name: 'Groceries',
            budgetAmountCents: 30000,
            spent: 290.0,
            currency: 'EUR',
            rolloverEnabled: false,
            availableBudgetCents: 30000,
            remainingCents: 1000,
            lastUpdated: august2026,
          ),
        ],
        editing: const [],
        periodMonth: august2026,
        previousBudget: 500.0,
        hasPreviousMonthPockets: true,
        currency: 'EUR',
        totalBudget: 500.0,
        savedTotalBudget: 500.0,
        unallocatedSpend: 0.0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
        previousPocketsState: previousPockets,
      );

      expect(state.primaryInsight.type, MonthlyInsightType.pocketAdjustment);
      expect(state.primaryInsight.badge, 'FRESH START');
      expect(state.primaryInsight.headline, 'New month, fresh balance');
      expect(
        state.primaryInsight.description,
        contains('Dining ran €74 above plan last month'),
      );
      expect(state.primaryInsight.metric, '+€74');
      expect(
        state.primaryInsight.sentiment,
        MonthlyInsightSentiment.supportive,
      );
    });

    test('Scenario 3: Finished month on budget with pocket count', () {
      final previousPockets = PocketsState(
        isLoading: false,
        saved: [
          PocketEnvelope(
            id: 'pocket-1',
            name: 'Dining',
            budgetAmountCents: 25000,
            spent: 240.0,
            currency: 'EUR',
            rolloverEnabled: false,
            availableBudgetCents: 25000,
            remainingCents: 1000,
            lastUpdated: august2026,
          ),
          PocketEnvelope(
            id: 'pocket-2',
            name: 'Groceries',
            budgetAmountCents: 35000,
            spent: 310.0,
            currency: 'EUR',
            rolloverEnabled: false,
            availableBudgetCents: 35000,
            remainingCents: 4000,
            lastUpdated: august2026,
          ),
        ],
        editing: const [],
        periodMonth: august2026,
        previousBudget: 600.0,
        hasPreviousMonthPockets: true,
        currency: 'EUR',
        totalBudget: 600.0,
        savedTotalBudget: 600.0,
        unallocatedSpend: 0.0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
        previousPocketsState: previousPockets,
      );

      expect(state.primaryInsight.type, MonthlyInsightType.budgetPerformance);
      expect(state.primaryInsight.badge, 'ON TRACK');
      expect(
        state.primaryInsight.headline,
        'You finished August on plan 🎉',
      );
      expect(state.primaryInsight.metric, '2 of 2');
      expect(state.primaryInsight.metricLabel, 'Pockets on budget');
    });

    test('Scenario 4: Month-over-month spending improvement', () {
      final cleanPreviousPockets = PocketsState(
        isLoading: false,
        saved: [
          PocketEnvelope(
            id: 'pocket-1',
            name: 'Expenses',
            budgetAmountCents: 82000,
            spent: 816.0,
            currency: 'EUR',
            rolloverEnabled: false,
            availableBudgetCents: 82000,
            remainingCents: 400,
            lastUpdated: august2026,
          ),
        ],
        editing: const [],
        periodMonth: august2026,
        previousBudget: 800.0, // budget was 800, spent was 816 -> did not stay on plan
        hasPreviousMonthPockets: true,
        currency: 'EUR',
        totalBudget: 800.0,
        savedTotalBudget: 800.0,
        unallocatedSpend: 0.0,
        uncategorized: const [],
        uncategorizedExpenses: const {},
      );

      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
        previousPocketsState: cleanPreviousPockets,
        twoMonthsAgoSpend: 1000.0,
      );

      expect(state.primaryInsight.type, MonthlyInsightType.spendingImprovement);
      expect(state.primaryInsight.badge, 'PROGRESS');
      expect(
        state.primaryInsight.headline,
        'Great progress last month',
      );
      expect(
        state.primaryInsight.description,
        contains('You spent €184 less than the month before'),
      );
      expect(state.primaryInsight.metric, '-€184');
    });

    test('Scenario 5: High upcoming recurring commitments', () {
      final recurringTransactions = [
        RecurringTransaction(
          id: 'rec-1',
          date: august2026,
          category: 'Housing',
          amount: 500.0,
          currency: 'EUR',
          ownerType: 'me',
          privacyScope: 'private',
          type: 'expense',
          attachments: const [],
          createdAt: august2026,
          recurrenceRule: RecurrenceRule(
            frequency: 'monthly',
            interval: 1,
            anchorDate: august2026,
          ),
        ),
        RecurringTransaction(
          id: 'rec-2',
          date: august2026,
          category: 'Subscriptions',
          amount: 140.0,
          currency: 'EUR',
          ownerType: 'me',
          privacyScope: 'private',
          type: 'expense',
          attachments: const [],
          createdAt: august2026,
          recurrenceRule: RecurrenceRule(
            frequency: 'monthly',
            interval: 1,
            anchorDate: august2026,
          ),
        ),
      ];

      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
        recurringExpenses: recurringTransactions,
      );

      expect(state.primaryInsight.type, MonthlyInsightType.upcomingRecurring);
      expect(state.primaryInsight.badge, 'UPCOMING');
      expect(
        state.primaryInsight.headline,
        'September is looking busy',
      );
      expect(
        state.primaryInsight.description,
        contains('€640 of recurring payments coming up'),
      );
      expect(state.primaryInsight.metric, '€640');
    });

    test('Scenario 6: Fallback clean slate for fresh month', () {
      final state = evaluateMonthlyIntroInsights(
        currentMonth: september2026,
        currency: 'EUR',
      );

      expect(state.primaryInsight.type, MonthlyInsightType.freshStart);
      expect(state.primaryInsight.badge, 'WELCOME');
      expect(state.primaryInsight.headline, 'Hello, September ✨');
      expect(state.primaryInsight.description, contains('clean starting point'));
    });
  });
}
