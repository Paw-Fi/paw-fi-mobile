import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_ai_budget_intro_sheet.dart';

void main() {
  testWidgets('PocketsAiBudgetIntroSheet renders flash cards and CTA buttons',
      (tester) async {
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'USD',
      periodMonth: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PocketsAiBudgetIntroSheet(
              scopeParams: scopeParams,
              currency: 'USD',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial flash card content
    expect(find.text('MILESTONE'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Welcome to Moneko!'), findsOneWidget);
    expect(find.text('Get My AI Budget Plan'), findsOneWidget);
    expect(find.text('Set up manually'), findsOneWidget);

    // Swipe to second card
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Verify second card content
    expect(find.text('LAST MONTH'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Real habits, zero guesswork'), findsOneWidget);

    // Swipe to third card
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('AI BLUEPRINT'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Smart targets for this month'), findsOneWidget);

    // Verify all Text widgets in the card have no maxLines restriction (no truncation)
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    final bodyTextWidget = textWidgets.firstWhere(
      (w) =>
          w.data != null &&
          w.data!.contains('AI drafts realistic pocket limits'),
    );
    expect(bodyTextWidget.maxLines, isNull);
    expect(bodyTextWidget.overflow, isNull);
  });

  testWidgets('PocketsAiBudgetIntroSheet manual setup button dismisses sheet',
      (tester) async {
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      currency: 'USD',
      periodMonth: DateTime(2026, 9, 1),
    );

    var dismissed = false;

    await tester.pumpWidget(
      ProviderScope(
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
