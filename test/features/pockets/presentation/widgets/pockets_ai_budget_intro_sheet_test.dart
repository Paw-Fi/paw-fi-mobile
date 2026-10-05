import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/pockets/presentation/state/monthly_intro_insights.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_ai_budget_intro_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

class _CopyPockets extends StateNotifier<PocketsState>
    implements PocketsNotifier {
  _CopyPockets() : super(PocketsState.initial().copyWith(isLoading: false));

  final pending = Completer<Map<String, String>>();
  final copiedMonths = <DateTime>[];

  @override
  Future<Map<String, String>> copyPocketsFromMonth(DateTime sourceMonth) {
    copiedMonths.add(sourceMonth);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final scope = PocketsScopeParams(
    scope: PocketsScopeType.personal,
    currency: 'EUR',
    periodMonth: DateTime(2026, 10),
  );
  final insight = MonthlyIntroState(
    primaryInsight: const MonthlyIntroInsight(
      type: MonthlyInsightType.freshStart,
      priority: 10,
      badge: 'WELCOME',
      headline: 'Fresh start',
      description: 'Plan your month.',
      sentiment: MonthlyInsightSentiment.positive,
    ),
    currentMonth: DateTime(2026, 10),
    previousMonth: DateTime(2026, 9),
    currentMonthName: 'October',
    previousMonthName: 'September',
  );

  Future<void> openCopySheet(WidgetTester tester, _CopyPockets notifier,
      Future<DateTime?> history) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pocketsProvider(scope).overrideWith((ref) => notifier),
        latestPreviousPocketMonthProvider(scope).overrideWith((ref) => history),
        monthlyIntroInsightsProvider(MonthlyIntroInsightsParams(
          scopeParams: scope,
          currency: 'EUR',
        )).overrideWithValue(insight),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => PocketsAiBudgetIntroSheet.show(
            context: context,
            ref: ref,
            scopeParams: scope,
            currency: 'EUR',
          ),
          child: const Text('Open'),
        ),
      ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('history lookup reserves copy action space until it resolves',
      (tester) async {
    final history = Completer<DateTime?>();
    await openCopySheet(tester, _CopyPockets(), history.future);
    expect(find.byKey(const ValueKey('previous-plan-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-previous-plan')), findsNothing);
    history.complete(DateTime(2026, 7));
    await tester.pumpAndSettle();
    expect(find.text("Copy last month's pockets"), findsOneWidget);
    expect(tester.widget(find.byKey(const ValueKey('copy-previous-plan'))),
        isA<PrimaryAdaptiveButton>());
    expect(find.byKey(const ValueKey('previous-plan-loading')), findsNothing);
  });

  testWidgets('production intro sheet has no header or close button',
      (tester) async {
    await openCopySheet(
        tester, _CopyPockets(), Future.value(DateTime(2026, 7)));
    expect(find.byType(MonekoSheetCloseButton), findsNothing);
    expect(tester.getSize(find.byType(MonekoSheetHeader)), Size.zero);
    await tester.ensureVisible(find.text('Set up manually'));
    await tester.tap(find.text('Set up manually'));
    await tester.pumpAndSettle();
    expect(find.byType(PocketsAiBudgetIntroSheet), findsNothing);
  });

  testWidgets(
      'copy confirmation names the actual source and cancellation does not copy',
      (tester) async {
    final notifier = _CopyPockets();
    await openCopySheet(tester, notifier, Future.value(DateTime(2026, 7)));
    await tester.ensureVisible(find.text("Copy last month's pockets"));
    await tester.tap(find.text("Copy last month's pockets"));
    await tester.pumpAndSettle();
    expect(find.textContaining('July 2026 -> October 2026'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.copiedMonths, isEmpty);
    expect(find.byType(PocketsAiBudgetIntroSheet), findsOneWidget);
  });

  for (final succeeds in [true, false]) {
    testWidgets(
        'copy uses nearest setup, prevents duplicates, and handles ${succeeds ? 'success' : 'failure'}',
        (tester) async {
      final notifier = _CopyPockets();
      await openCopySheet(tester, notifier, Future.value(DateTime(2026, 7)));
      await tester.ensureVisible(find.text("Copy last month's pockets"));
      await tester.tap(find.text("Copy last month's pockets"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy pockets'));
      await tester.pumpAndSettle();
      expect(notifier.copiedMonths, [DateTime(2026, 7)]);
      expect(find.text('Copying...'), findsOneWidget);
      expect(
          tester
              .widget<PrimaryAdaptiveButton>(
                  find.byKey(const ValueKey('copy-previous-plan')))
              .onPressed,
          isNull);
      if (succeeds) {
        notifier.pending.complete({'source': 'destination'});
      } else {
        notifier.pending.completeError(StateError('Copy failed'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(PocketsAiBudgetIntroSheet),
          succeeds ? findsNothing : findsOneWidget);
      if (!succeeds) {
        expect(find.text("Copy last month's pockets"), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });
  }

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
          latestPreviousPocketMonthProvider(scopeParams)
              .overrideWith((ref) async => DateTime(2026, 7)),
          monthlyIntroInsightsProvider(insightParams)
              .overrideWithValue(testState),
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
    expect(find.text('€230'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.text('Carried forward'), findsOneWidget);

    // Verify milestone badge
    expect(find.text('16 months with Moneko'), findsOneWidget);

    // Verify CTAs
    expect(find.text('Build My September Plan'), findsOneWidget);
    expect(find.text("Copy last month's pockets"), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('copy-previous-plan'))),
      tester.getSize(find.ancestor(
        of: find.text('Build My September Plan'),
        matching: find.byType(PrimaryAdaptiveButton),
      )),
    );
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
          latestPreviousPocketMonthProvider(scopeParams)
              .overrideWith((ref) async => null),
          monthlyIntroInsightsProvider(insightParams)
              .overrideWithValue(testState),
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
    expect(find.text('€92'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
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
          latestPreviousPocketMonthProvider(scopeParams)
              .overrideWith((ref) async => null),
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
