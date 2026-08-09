import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import_review/data/import_review_repository.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:moneko/features/import_review/presentation/providers/import_review_provider.dart';

void main() {
  const launch = ImportReviewLaunch(reviewId: 'review-id', token: 'token');
  const pendingReview = ImportReview(
    status: 'pending',
    version: 1,
    expiresAt: null,
    items: [],
  );

  test('submission stays visible, prevents repeats, and preserves retry state',
      () async {
    final repository = _FakeImportReviewRepository();
    final container = ProviderContainer(overrides: [
      importReviewLaunchProvider.overrideWithValue(launch),
      importReviewRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    await container.read(importReviewProvider.future);
    final firstSubmit =
        container.read(importReviewProvider.notifier).submit(const {
      'item-id': ['currency:USD']
    });
    final repeatedSubmit =
        container.read(importReviewProvider.notifier).submit(const {
      'item-id': ['currency:USD']
    });

    expect(
        container.read(importReviewProvider).requireValue.isSubmitting, true);
    expect(repository.submitCount, 1);

    repository.submission.completeError(Exception('offline'));
    await Future.wait([firstSubmit, repeatedSubmit]);

    final review = container.read(importReviewProvider).requireValue;
    expect(review.status, pendingReview.status);
    expect(review.isSubmitting, false);
    expect(review.submissionError, isNotNull);
  });

  test('submission re-inspects when submit returns processing', () async {
    final repository = _FakeImportReviewRepository(
      inspectResponses: const [
        pendingReview,
        ImportReview(
          status: 'completed',
          version: 1,
          expiresAt: null,
          items: [],
        ),
      ],
      submitResult: const ImportReview(
        status: 'processing',
        version: 1,
        expiresAt: null,
        items: [],
      ),
    );
    final container = ProviderContainer(overrides: [
      importReviewLaunchProvider.overrideWithValue(launch),
      importReviewRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    await container.read(importReviewProvider.future);
    await container.read(importReviewProvider.notifier).submit(const {
      'item-id': ['currency:USD']
    });

    expect(repository.submitCount, 1);
    expect(repository.inspectCount, 2);
    expect(
      container.read(importReviewProvider).requireValue.status,
      'completed',
    );
  });

  test('initial inspection polls an already processing review', () async {
    final repository = _FakeImportReviewRepository(
      inspectResponses: const [
        ImportReview(
          status: 'processing',
          version: 1,
          expiresAt: null,
          items: [],
        ),
        ImportReview(
          status: 'completed',
          version: 1,
          expiresAt: null,
          items: [],
        ),
      ],
    );
    final container = ProviderContainer(overrides: [
      importReviewLaunchProvider.overrideWithValue(launch),
      importReviewRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      importReviewProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final review = await container.read(importReviewProvider.future);

    expect(repository.inspectCount, 2);
    expect(review.status, 'completed');
  });
}

class _FakeImportReviewRepository implements ImportReviewRepository {
  _FakeImportReviewRepository({
    List<ImportReview>? inspectResponses,
    this.submitResult,
  }) : inspectResponses = inspectResponses ?? const [];

  final submission = Completer<ImportReview>();
  final List<ImportReview> inspectResponses;
  final ImportReview? submitResult;
  int submitCount = 0;
  int inspectCount = 0;

  @override
  Future<ImportReview> inspect({
    required String reviewId,
    required String token,
  }) async {
    final responseIndex = inspectCount;
    inspectCount += 1;
    if (responseIndex < inspectResponses.length) {
      return inspectResponses[responseIndex];
    }
    return const ImportReview(
      status: 'pending',
      version: 1,
      expiresAt: null,
      items: [],
    );
  }

  @override
  Future<ImportReview> submit({
    required String reviewId,
    required String token,
    required int version,
    required Map<String, List<String>?> selections,
  }) {
    submitCount += 1;
    if (submitResult != null) return Future.value(submitResult);
    return submission.future;
  }
}
