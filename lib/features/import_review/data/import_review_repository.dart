import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ImportReviewRepository {
  Future<ImportReview> inspect({
    required String reviewId,
    required String token,
  });

  Future<ImportReview> submit({
    required String reviewId,
    required String token,
    required int version,
    required Map<String, List<String>?> selections,
  });
}

class SupabaseImportReviewRepository implements ImportReviewRepository {
  const SupabaseImportReviewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ImportReview> inspect(
      {required String reviewId, required String token}) async {
    final response = await _client.functions.invoke(
      'email-import-review-inspect',
      body: {'reviewId': reviewId, 'token': token},
    );
    return ImportReview.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<ImportReview> submit({
    required String reviewId,
    required String token,
    required int version,
    required Map<String, List<String>?> selections,
  }) async {
    final response = await _client.functions.invoke(
      'email-import-review-submit',
      body: {
        'reviewId': reviewId,
        'token': token,
        'version': version,
        'decisions': selections.entries
            .map((entry) => {
                  'itemId': entry.key,
                  if (entry.value == null)
                    'decline': true
                  else
                    'optionIds': entry.value,
                })
            .toList(growable: false),
      },
    );
    return ImportReview.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
}
