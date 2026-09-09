import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_month_review.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_month_review_sheet.dart';

void main() {
  testWidgets('shows a beginner-friendly pocket suggestion and AI explanation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PocketsMonthReviewSuggestionField(
            suggestion: const PocketsMonthReviewSuggestion(
              envelopeId: 'food',
              lineageId: 'food-lineage',
              label: 'Food',
              amountCents: 25000,
              incomingCarryCents: 5000,
              fundingPolicy: 'refill_to',
            ),
            currency: 'USD',
            valueCents: 25000,
            aiExplanation:
                'This keeps your food pocket close to its usual amount.',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Suggested amount'), findsOneWidget);
    expect(find.textContaining('Added this cycle'), findsOneWidget);
    expect(find.textContaining('Carried from last cycle'), findsOneWidget);
    expect(find.textContaining('Available'), findsOneWidget);
    expect(
      find.text('This keeps your food pocket close to its usual amount.'),
      findsOneWidget,
    );
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
  });

  testWidgets(
      'keeps the pocket editor usable with large text on a narrow screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: PocketsMonthReviewSuggestionField(
              suggestion: const PocketsMonthReviewSuggestion(
                envelopeId: 'transport',
                lineageId: 'transport-lineage',
                label: 'Transport',
                amountCents: 17000,
              ),
              currency: 'USD',
              valueCents: 17000,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
