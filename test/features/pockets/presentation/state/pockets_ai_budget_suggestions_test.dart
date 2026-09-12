import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_ai_budget_suggestions.dart';

void main() {
  test('parses read-only AI pocket suggestions', () {
    final result = PocketsAiBudgetSuggestions.fromJson({
      'suggestions': {
        'summary': 'A practical starting point.',
        'headline': 'Your plan has room to breathe',
        'financial_status': 'covered',
        'celebration': 'You stayed within budget in 3 categories!',
        'top_spend_insight': 'Dining was your highest spend last month.',
        'pockets_health_tip': 'Pockets give you guilt-free clarity.',
        'total_suggested_cents': 12500,
        'suggested_total_budget_cents': 15000,
        'cash_flow': {
          'data_status': 'complete',
          'income_coverage_status': 'covered',
          'month_funding_status': 'funded',
          'recorded_income_cents': 30000,
          'projected_recurring_income_cents': 5000,
          'known_income_cents': 35000,
          'actual_expense_cents': 10000,
          'projected_recurring_expense_cents': 5000,
          'known_outflow_cents': 15000,
          'income_margin_cents': 20000,
          'incoming_carry_cents': 5000,
          'funding_margin_after_carry_cents': 25000,
        },
        'insights': [
          {
            'type': 'cash_flow',
            'title': 'Your known income covers this plan',
            'summary': 'Known income is 350 above 150 of spending.',
            'action': 'Keep 50 unassigned as a buffer.',
            'estimated_impact_cents': 5000,
          },
        ],
        'suggestions': [
          {
            'envelope_id': 'e1',
            'pocket_name': 'Groceries',
            'suggested_amount_cents': 12500,
            'reason': 'Based on the pocket context.',
            'tip': 'Try buying in bulk for non-perishables.',
            'change_type': 'increase',
            'icon': 'cart',
            'color': 'green',
            'incoming_carry_cents': 5000,
            'rollover_enabled': true,
            'remaining_cents': 2500,
          },
        ],
      },
    });

    expect(result.summary, 'A practical starting point.');
    expect(result.headline, 'Your plan has room to breathe');
    expect(result.financialStatus, 'covered');
    expect(result.cashFlow?.incomeCoverageStatus, 'covered');
    expect(result.cashFlow?.incomeMarginCents, 20000);
    expect(result.insights.single.title, 'Your known income covers this plan');
    expect(result.insights.single.action, 'Keep 50 unassigned as a buffer.');
    expect(result.insights.single.estimatedImpactCents, 5000);
    expect(result.celebration, 'You stayed within budget in 3 categories!');
    expect(result.topSpendInsight, 'Dining was your highest spend last month.');
    expect(result.pocketsHealthTip, 'Pockets give you guilt-free clarity.');
    expect(result.totalSuggestedCents, 12500);
    expect(result.suggestedTotalBudgetCents, 15000);
    expect(result.suggestions.single.amountCents, 12500);
    expect(result.suggestions.single.pocketName, 'Groceries');
    expect(result.suggestions.single.icon, 'cart');
    expect(result.suggestions.single.color, 'green');
    expect(result.suggestions.single.incomingCarryCents, 5000);
    expect(result.suggestions.single.rolloverEnabled, isTrue);
    expect(result.suggestions.single.remainingCents, 2500);
    expect(result.suggestions.single.tip,
        'Try buying in bulk for non-perishables.');
    expect(result.suggestions.single.changeType, 'increase');
  });

  test('rejects an invalid AI suggestion payload', () {
    expect(
      () => PocketsAiBudgetSuggestions.fromJson({
        'suggestions': {'summary': 'Missing list'},
      }),
      throwsA(isA<PocketsAiBudgetSuggestionsException>()),
    );
  });

  test('rejects a partial dynamic insight', () {
    expect(
      () => PocketsAiBudgetSuggestions.fromJson({
        'suggestions': {
          'summary': 'Plan summary',
          'insights': [
            {'type': 'cash_flow', 'title': 'Missing summary'},
          ],
          'suggestions': <Map<String, dynamic>>[],
        },
      }),
      throwsA(isA<PocketsAiBudgetSuggestionsException>()),
    );
  });

  test('rebinds prior-month suggestion IDs to copied current-month pockets',
      () {
    expect(
      rebindCopiedPocketSuggestionAmounts(
        sourceAmountsCents: const {'aug-groceries': 42500, 'aug-car': 15000},
        copiedPocketIds: const {
          'aug-groceries': 'sep-groceries',
          'aug-car': 'sep-car',
        },
      ),
      const {'sep-groceries': 42500, 'sep-car': 15000},
    );
  });

  test('refuses to apply a plan when a copied pocket is missing', () {
    expect(
      () => rebindCopiedPocketSuggestionAmounts(
        sourceAmountsCents: const {'aug-groceries': 42500},
        copiedPocketIds: const {},
      ),
      throwsA(isA<PocketsAiBudgetSuggestionsException>()),
    );
  });
}
