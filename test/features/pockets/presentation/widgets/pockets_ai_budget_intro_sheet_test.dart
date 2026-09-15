import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/pockets/presentation/state/monthly_intro_insights.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_ai_budget_intro_sheet.dart';

void main() {
  testWidgets(
      'PocketsAiBudgetIntroSheet renders hero insight card and CTA buttons',
      (tester) async {
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'EUR',
      periodMonth: DateTime(2026, 9, 1),
    );

    final insightParams = MonthlyIntroInsightsParams(
      scopeParams: scopeParams,
      currency: 'EUR',
    );

    final testState = MonthlyIntroState(
      primaryInsight: const MonthlyIntroInsight(
        type: MonthlyInsightType.rolloverCarry,
        priority: 100,
        badge: 'ROLLOVER',
        headline: "You're starting September with €230 extra",
        description:
            "Your unused budget from August has rolled forward. Let's decide where it can help most.",
        metric: '+€230',
        metricLabel: 'Carried forward',
        sentiment: MonthlyInsightSentiment.positive,
      ),
      milestoneText: '16 months with Moneko',
      currentMonth: DateTime(2026, 9, 1),
      previousMonth: DateTime(2026, 8, 1),
      currentMonthName: 'September',
      previousMonthName: 'August',
      monthsUsingMoneko: 16,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyIntroInsightsProvider(insightParams).overrideWithValue(testState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PocketsAiBudgetIntroSheet(
              scopeParams: scopeParams,
              currency: 'EUR',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify monthly header and kicker
    expect(find.text('HELLO, SEPTEMBER'), findsOneWidget);
    expect(find.text('A fresh month starts here'), findsOneWidget);

    // Verify hero insight card content
    expect(find.text('ROLLOVER'), findsOneWidget);
    expect(
      find.text("You're starting September with €230 extra"),
      findsOneWidget,
    );
    expect(
      find.text(
        "Your unused budget from August has rolled forward. Let's decide where it can help most.",
      ),
      findsOneWidget,
    );
    expect(find.text('+€230'), findsOneWidget);
    expect(find.text('Carried forward'), findsOneWidget);

    // Verify milestone badge
    expect(find.text('16 months with Moneko'), findsOneWidget);

    // Verify CTAs
    expect(find.text('Build My September Plan'), findsOneWidget);
    expect(find.text('Set up manually'), findsOneWidget);
  });

  testWidgets(
      'PocketsAiBudgetIntroSheet renders supportive overspent pocket adjustment',
      (tester) async {
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'EUR',
      periodMonth: DateTime(2026, 9, 1),
    );

    final insightParams = MonthlyIntroInsightsParams(
      scopeParams: scopeParams,
      currency: 'EUR',
    );

    final testState = MonthlyIntroState(
      primaryInsight: const MonthlyIntroInsight(
        type: MonthlyInsightType.pocketAdjustment,
        priority: 90,
        badge: 'FRESH START',
        headline: 'New month, fresh balance',
        description:
            'Dining ran €92 above plan last month. We can adjust September around how you actually spend.',
        metric: '+€92',
        metricLabel: 'Above plan in August',
        sentiment: MonthlyInsightSentiment.supportive,
      ),
      currentMonth: DateTime(2026, 9, 1),
      previousMonth: DateTime(2026, 8, 1),
      currentMonthName: 'September',
      previousMonthName: 'August',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyIntroInsightsProvider(insightParams).overrideWithValue(testState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PocketsAiBudgetIntroSheet(
              scopeParams: scopeParams,
              currency: 'EUR',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('FRESH START'), findsOneWidget);
    expect(find.text('New month, fresh balance'), findsOneWidget);
    expect(
      find.text(
        'Dining ran €92 above plan last month. We can adjust September around how you actually spend.',
      ),
      findsOneWidget,
    );
    expect(find.text('+€92'), findsOneWidget);
    expect(find.text('Above plan in August'), findsOneWidget);
  });

  testWidgets('PocketsAiBudgetIntroSheet manual setup button dismisses sheet',
      (tester) async {
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'USD',
      periodMonth: DateTime(2026, 9, 1),
    );

    final insightParams = MonthlyIntroInsightsParams(
      scopeParams: scopeParams,
      currency: 'USD',
    );

    final testState = MonthlyIntroState(
      primaryInsight: const MonthlyIntroInsight(
        type: MonthlyInsightType.freshStart,
        priority: 10,
        badge: 'WELCOME',
        headline: 'Hello, September ✨',
        description: 'A new month and a clean starting point.',
        sentiment: MonthlyInsightSentiment.positive,
      ),
      currentMonth: DateTime(2026, 9, 1),
      previousMonth: DateTime(2026, 8, 1),
      currentMonthName: 'September',
      previousMonthName: 'August',
    );

    var dismissed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyIntroInsightsProvider(insightParams)
              .overrideWithValue(testState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PocketsAiBudgetIntroSheet(
                      scopeParams: scopeParams,
                      currency: 'USD',
                    ),
                  );
                  dismissed = true;
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(PocketsAiBudgetIntroSheet), findsOneWidget);

    await tester.tap(find.text('Set up manually'));
    await tester.pumpAndSettle();

    expect(find.byType(PocketsAiBudgetIntroSheet), findsNothing);
    expect(dismissed, isTrue);
  });
}
