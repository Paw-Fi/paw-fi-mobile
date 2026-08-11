import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import_review/data/import_review_repository.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:moneko/features/import_review/presentation/pages/import_review_page.dart';
import 'package:moneko/features/import_review/presentation/providers/import_review_provider.dart';

void main() {
  const reviewId = '11111111-1111-4111-8111-111111111111';
  const token = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  const source = ImportReviewSource(
    senderEmail: 'receipts@example.com',
    subjectLine: 'August card receipts',
    files: [
      ImportReviewSourceFile(
        name: 'hotel.pdf',
        status: 'processed',
        transactionCount: 2,
      ),
    ],
  );
  const item = ImportReviewItem(
    id: 'item-1',
    summary: 'Airport ride',
    issues: [],
    transaction: ImportReviewTransaction(
      type: 'expense',
      amount: 42.5,
      currency: 'USD',
      date: null,
      merchant: 'City Taxi',
      description: 'Airport ride',
      category: 'transportation',
    ),
    saveStatus: 'saved',
  );

  testWidgets('pending review identifies its source and transaction',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importReviewRepositoryProvider.overrideWithValue(
            const _FakeImportReviewRepository(
              ImportReview(
                status: 'pending',
                version: 1,
                expiresAt: null,
                items: [item],
                source: source,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ImportReviewPage(reviewId: reviewId, token: token),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('August card receipts'), findsOneWidget);
    expect(find.text('receipts@example.com'), findsOneWidget);
    expect(find.text('hotel.pdf'), findsOneWidget);
    expect(find.text('USD 42.50'), findsOneWidget);
    expect(find.text('City Taxi'), findsOneWidget);
    expect(find.text('Transportation'), findsOneWidget);
  });

  testWidgets(
      'completed review shows logged transaction and closes to previous',
      (tester) async {
    late BuildContext previousContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importReviewRepositoryProvider.overrideWithValue(
            const _FakeImportReviewRepository(
              ImportReview(
                status: 'completed',
                version: 1,
                expiresAt: null,
                items: [item],
                source: source,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              previousContext = context;
              return const Scaffold(body: Text('Previous page'));
            },
          ),
        ),
      ),
    );
    unawaited(Navigator.of(previousContext).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ImportReviewPage(reviewId: reviewId, token: token),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Transaction logged'), findsOneWidget);
    expect(find.text('USD 42.50'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Close this page'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Close this page'), findsOneWidget);

    await tester.tap(find.text('Close this page'));
    await tester.pumpAndSettle();

    expect(find.text('Previous page'), findsOneWidget);
  });
}

class _FakeImportReviewRepository implements ImportReviewRepository {
  const _FakeImportReviewRepository(this.review);

  final ImportReview review;

  @override
  Future<ImportReview> inspect({
    required String reviewId,
    required String token,
  }) async =>
      review;

  @override
  Future<ImportReview> submit({
    required String reviewId,
    required String token,
    required int version,
    required Map<String, List<String>?> selections,
  }) async =>
      review;
}
