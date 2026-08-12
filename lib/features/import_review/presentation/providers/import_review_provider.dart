import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import_review/data/import_review_repository.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final importReviewRepositoryProvider = Provider<ImportReviewRepository>(
  (ref) => SupabaseImportReviewRepository(Supabase.instance.client),
);

final importReviewLaunchProvider = Provider<ImportReviewLaunch>(
  (ref) => throw StateError('Import review launch is not configured'),
);

final importReviewProvider =
    AsyncNotifierProvider.autoDispose<ImportReviewNotifier, ImportReview>(
  ImportReviewNotifier.new,
  dependencies: [importReviewLaunchProvider],
);

class ImportReviewLaunch {
  const ImportReviewLaunch({required this.reviewId, required this.token});

  final String reviewId;
  final String token;
}

class ImportReviewNotifier extends AutoDisposeAsyncNotifier<ImportReview> {
  late ImportReviewLaunch _launch;
  var _isDisposed = false;

  @override
  Future<ImportReview> build() {
    _launch = ref.watch(importReviewLaunchProvider);
    ref.onDispose(() => _isDisposed = true);
    return _inspectUntilSettled();
  }

  Future<void> submit(Map<String, List<String>?> selections) async {
    final review = state.valueOrNull;
    if (review == null || review.isSubmitting) return;
    state = AsyncData(
      review.copyWith(isSubmitting: true, clearSubmissionError: true),
    );
    try {
      final result = await ref.read(importReviewRepositoryProvider).submit(
            reviewId: _launch.reviewId,
            token: _launch.token,
            version: review.version,
            selections: selections,
          );
      if (result.status != 'processing') {
        state = AsyncData(result);
        return;
      }
      final inspected = await _inspectUntilSettled();
      if (!_isDisposed) state = AsyncData(inspected);
    } catch (_) {
      if (_isDisposed) return;
      state = AsyncData(
        review.copyWith(
          submissionError:
              'We could not confirm this import. Please try again.',
        ),
      );
    }
  }

  Future<ImportReview> _inspectUntilSettled() async {
    var inspected = await ref.read(importReviewRepositoryProvider).inspect(
          reviewId: _launch.reviewId,
          token: _launch.token,
        );
    while (!_isDisposed && inspected.status == 'processing') {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (_isDisposed) return inspected;
      inspected = await ref.read(importReviewRepositoryProvider).inspect(
            reviewId: _launch.reviewId,
            token: _launch.token,
          );
    }
    return inspected;
  }
}
