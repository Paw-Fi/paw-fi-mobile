import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_ai_budget_suggestions_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_ai_budget_suggestions.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class _TestPocketsNotifier extends StateNotifier<PocketsState>
    implements PocketsNotifier {
  _TestPocketsNotifier(super.state, {this.saveCompleter});

  final Completer<void>? saveCompleter;

  @override
  void applySuggestedPocketAmounts(
    Map<String, int> suggestedAmountsCents, {
    int? suggestedTotalBudgetCents,
  }) {}

  @override
  Future<void> saveChanges() => saveCompleter?.future ?? Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'PocketsAiBudgetSuggestionsPage displays suggestions, celebration, and apply button',
      (tester) async {
    final saveCompleter = Completer<void>();
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'USD',
      periodMonth: DateTime(2026, 9, 1),
    );

    final mockPocketsState = PocketsState.initial().copyWith(
      currency: 'USD',
      periodMonth: DateTime(2026, 9, 1),
      editing: [
        PocketEnvelope(
          id: 'e1',
          name: 'Groceries',
          color: 'green',
          icon: 'cart',
          budgetAmountCents: 28500,
          spent: 0,
          currency: 'USD',
          lastUpdated: DateTime.now(),
        ),
        PocketEnvelope(
          id: 'e2',
          name: 'Dining',
          color: 'orange',
          icon: 'utensils',
          budgetAmountCents: 15000,
          spent: 0,
          currency: 'USD',
          lastUpdated: DateTime.now(),
        ),
      ],
    );

    const mockSuggestions = PocketsAiBudgetSuggestions(
      headline: 'Your plan is covered with room left',
      summary: 'Tailored monthly budget plan based on past spending.',
      celebration: 'You kept Dining well within limits last month!',
      topSpendInsight: 'Groceries was your top expense. We added a 5% buffer.',
      pocketsHealthTip: 'Envelopes give you guilt-free permission to spend.',
      totalSuggestedCents: 45000,
      suggestedTotalBudgetCents: 50000,
      usesPreviousMonthPockets: false,
      cashFlow: PocketsAiKnownCashFlow(
        dataStatus: 'complete',
        incomeCoverageStatus: 'covered',
        monthFundingStatus: 'funded',
        recordedIncomeCents: 60000,
        projectedRecurringIncomeCents: 0,
        knownIncomeCents: 60000,
        actualExpenseCents: 35000,
        projectedRecurringExpenseCents: 10000,
        knownOutflowCents: 45000,
        incomeMarginCents: 15000,
        incomingCarryCents: 0,
        knownFundingCents: 60000,
        fundingMarginAfterCarryCents: 15000,
        knownCommitmentsCovered: true,
        safeToSpendStatus: 'unavailable',
      ),
      insights: [
        PocketsAiBudgetInsight(
          type: 'positive_progress',
          title: 'Dining stayed within your target',
          summary: 'You kept Dining within its limit last month.',
        ),
        PocketsAiBudgetInsight(
          type: 'spending_pattern',
          title: 'Groceries need a small buffer',
          summary: 'Groceries was your highest expense last month.',
          action: 'Use the added buffer for your next grocery trip.',
        ),
        PocketsAiBudgetInsight(
          type: 'rollover',
          title: 'Carry reduces what you need to add',
          summary: 'You already have money carried into Groceries.',
        ),
      ],
      suggestions: [
        PocketsAiBudgetSuggestion(
          envelopeId: 'e1',
          pocketName: 'Groceries',
          amountCents: 30000,
          reason: 'Adjusted up 5% to cover seasonal groceries.',
          tip: 'Buy pantry items in bulk.',
          changeType: 'increase',
          previousSpentCents: 28500,
          previousBudgetCents: 28500,
          incomingCarryCents: 5000,
          rolloverEnabled: true,
        ),
        PocketsAiBudgetSuggestion(
          envelopeId: 'e2',
          pocketName: 'Dining',
          amountCents: 15000,
          reason: 'Matches your healthy spending average.',
          tip: 'Enjoy guilt-free weekend dining.',
          changeType: 'same',
          previousSpentCents: 15000,
        ),
      ],
    );

    final request = PocketsAiBudgetSuggestionsRequest(
      scopeParams: scopeParams,
      currency: 'USD',
      locale: 'en-US',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pocketsProvider(scopeParams).overrideWith(
            (ref) => _TestPocketsNotifier(
              mockPocketsState,
              saveCompleter: saveCompleter,
            ),
          ),
          pocketsAiBudgetSuggestionsProvider(request).overrideWith(
            (ref) => Future.value(mockSuggestions),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          home: PocketsAiBudgetSuggestionsPage(
            scopeParams: scopeParams,
            currency: 'USD',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify page elements
    expect(find.text('AI Budget Plan'), findsOneWidget);
    expect(find.textContaining('AI BLUEPRINT'), findsNothing);
    expect(find.text('Your plan is covered with room left'), findsOneWidget);
    expect(find.text('Dining stayed within your target'), findsOneWidget);
    expect(
      find.text('You kept Dining within its limit last month.'),
      findsOneWidget,
    );

    // Swipe coaching carousel to card 2 (Strategy)
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Groceries need a small buffer'), findsOneWidget);
    expect(
      find.text('Groceries was your highest expense last month.'),
      findsOneWidget,
    );
    expect(
      find.text('Use the added buffer for your next grocery trip.'),
      findsOneWidget,
    );

    // Swipe coaching carousel to card 3 (Mindset)
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Carry reduces what you need to add'), findsOneWidget);

    expect(find.textContaining('SUGGESTED POCKET TARGETS'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(find.byType(PrimaryAdaptiveButton), findsOneWidget);
    expect(find.text(r'$500'), findsOneWidget);
    expect(find.text('Total available this month'), findsOneWidget);
    expect(find.text(r'$450'), findsNWidgets(2));
    expect(find.text('Plan for this month'), findsOneWidget);
    expect(find.text(r'$50'), findsOneWidget);
    expect(find.text('Carried from last month'), findsOneWidget);
    final cashFlowLabel = find.text('CASH FLOW', skipOffstage: false);
    await tester.ensureVisible(cashFlowLabel);
    await tester.pumpAndSettle();
    expect(cashFlowLabel, findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text(r'$600'), findsOneWidget);
    expect(find.text(r'$150'), findsNWidgets(2));
    expect(find.text(r'$350'), findsOneWidget);
    expect(find.text(r'$300'), findsNothing);
    expect(find.text(r'+$50 carried in'), findsOneWidget);
    expect(find.text('Why this plan?'), findsNWidgets(2));
    expect(find.text('Available after plan'), findsNothing);

    final groceriesDetailsButton =
        find.byKey(const ValueKey('pocket-suggestion-details-e1'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(groceriesDetailsButton);
    await tester.tap(groceriesDetailsButton);
    await tester.pumpAndSettle();

    expect(find.text('How this plan was made'), findsOneWidget);
    expect(find.text('Add this month'), findsWidgets);
    expect(find.text('Carried in'), findsOneWidget);
    expect(find.text('Available after plan'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(PrimaryAdaptiveButton));
    await tester.tap(find.byType(PrimaryAdaptiveButton));
    await tester.pump();

    expect(find.byType(BlockingProcessingDialog), findsOneWidget);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(BlockingProcessingDialog), findsNothing);
  });
}
