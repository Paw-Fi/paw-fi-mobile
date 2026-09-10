import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_ai_budget_suggestions.dart';

void main() {
  test('parses read-only AI pocket suggestions', () {
    final result = PocketsAiBudgetSuggestions.fromJson({
      'deterministicFallback': false,
      'suggestions': {
        'summary': 'A practical starting point.',
        'suggestions': [
          {
            'envelope_id': 'e1',
            'suggested_amount_cents': 12500,
            'reason': 'Based on the pocket context.',
          },
        ],
      },
    });

    expect(result.summary, 'A practical starting point.');
    expect(result.suggestions.single.amountCents, 12500);
    expect(result.isFallback, isFalse);
  });

  test('rejects an invalid AI suggestion payload', () {
    expect(
      () => PocketsAiBudgetSuggestions.fromJson({
        'suggestions': {'summary': 'Missing list'},
      }),
      throwsA(isA<PocketsAiBudgetSuggestionsException>()),
    );
  });
}
