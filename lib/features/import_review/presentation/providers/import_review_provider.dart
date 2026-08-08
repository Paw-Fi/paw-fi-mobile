import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import_review/data/import_review_repository.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final importReviewRepositoryProvider = Provider<ImportReviewRepository>(
  (ref) => ImportReviewRepository(Supabase.instance.client),
);

final importReviewProvider = AsyncNotifierProvider.autoDispose
    .family<ImportReviewNotifier, ImportReview, ImportReviewLaunch>(
  ImportReviewNotifier.new,
);

class ImportReviewLaunch {
  const ImportReviewLaunch({required this.reviewId, required this.token});

  final String reviewId;
  final String token;

  @override
  bool operator ==(Object other) =>
      other is ImportReviewLaunch &&
      other.reviewId == reviewId &&
      other.token == token;

  @override
  int get hashCode => Object.hash(reviewId, token);
}

class ImportReviewNotifier
    extends AutoDisposeFamilyAsyncNotifier<ImportReview, ImportReviewLaunch> {
  late ImportReviewLaunch _launch;

  @override
  Future<ImportReview> build(ImportReviewLaunch arg) {
    _launch = arg;
    return ref
        .read(importReviewRepositoryProvider)
        .inspect(reviewId: arg.reviewId, token: arg.token);
  }

  Future<void> submit(Map<String, List<String>> selections) async {
    final review = state.valueOrNull;
    if (review == null || state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(importReviewRepositoryProvider).submit(
              reviewId: _launch.reviewId,
              token: _launch.token,
              version: review.version,
              selections: selections,
            ));
  }
}
