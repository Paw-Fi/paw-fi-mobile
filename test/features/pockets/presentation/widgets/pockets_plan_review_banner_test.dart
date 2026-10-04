import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_plan_review_banner.dart';

void main() {
  late MonekoDatabase database;
  late LocalMutationOutboxData review;
  setUp(() async {
    database = MonekoDatabase.inMemory();
    await database.enqueueMutation(
        clientMutationId: 'usd-plan',
        entityType: 'pockets_month',
        entityId: 'USD',
        operation: 'save_pockets_month',
        payload: {
          'currency': 'USD',
          'totalBudgetCents': 7000,
          'pockets': [
            {'name': '食費', 'budgetAmountCents': 7000}
          ],
        });
    final row = (await database.getOutboxMutations()).single;
    await database.markMutationNeedsReviewIfPayloadMatches(
        clientMutationId: row.clientMutationId,
        expectedPayloadJson: row.payloadJson,
        error: 'conflict');
    review = (await database.getOutboxMutations()).single;
  });
  tearDown(() async {
    await database.close();
  });

  testWidgets(
      'review waits for canonical data and reapplies the native currency intent',
      (tester) async {
    final canonical = Completer<PocketsState>();
    final resolved = <(String, bool)>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PocketsPlanReviewBanner(
      reviews: [review],
      prepare: (_) => canonical.future,
      resolve: (row, reapply) async {
        resolved.add((row.clientMutationId, reapply));
      },
    ))));
    await tester.tap(find.text('Needs review USD'));
    await tester.pump();
    expect(find.textContaining('Current plan:'), findsNothing);
    expect(resolved, isEmpty);
    canonical.complete(
        PocketsState.initial().copyWith(currency: 'USD', savedTotalBudget: 50));
    await tester.pumpAndSettle();
    expect(find.textContaining('Current plan: USD 50'), findsOneWidget);
    expect(find.textContaining('Saved changes: USD 70'), findsOneWidget);
    expect(find.textContaining('食費: USD 70'), findsOneWidget);
    await tester.ensureVisible(find.text('Reapply saved changes'));
    await tester.tap(find.text('Reapply saved changes'));
    await tester.pumpAndSettle();
    expect(resolved, [('usd-plan', true)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard works offline without a canonical read', (tester) async {
    var reads = 0;
    final resolved = <bool>[];
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: PocketsPlanReviewBanner(
          reviews: [review],
          prepare: (_) async {
            reads++;
            throw StateError('offline');
          },
          resolve: (_, reapply) async {
            resolved.add(reapply);
          },
        ))));
    await tester.tap(find.text('Discard saved changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved changes: USD 70'), findsOneWidget);
    await tester.ensureVisible(find.text('Discard saved changes').last);
    await tester.tap(find.text('Discard saved changes').last);
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(resolved, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing review retains the durable intent', (tester) async {
    var resolutions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PocketsPlanReviewBanner(
      reviews: [review],
      prepare: (_) async => PocketsState.initial(),
      resolve: (_, reapply) async {
        resolutions++;
      },
    ))));
    await tester.tap(find.text('Needs review USD'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(resolutions, 0);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusNeedsReview);
  });
}
