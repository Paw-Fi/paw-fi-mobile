import 'package:moneko/core/core.dart';

/// Stable, language-independent identifiers for cancel reasons.
///
/// The [id] is persisted to `subscription_cancel_reasons.reason_id` so the same
/// answer maps to the same row across locales. The localized [label] is passed
/// in at call time and stored as an audit snapshot.
enum CancelReasonId {
  tooExpensive,
  foundAlternative,
  notUsingEnough,
  appIssue,
  missingSpecificFeature,
  other;

  String get id => switch (this) {
        CancelReasonId.tooExpensive => 'too_expensive',
        CancelReasonId.foundAlternative => 'found_alternative',
        CancelReasonId.notUsingEnough => 'not_using_enough',
        CancelReasonId.appIssue => 'app_issue',
        CancelReasonId.missingSpecificFeature => 'missing_specific_feature',
        CancelReasonId.other => 'other',
      };

  /// Whether selecting this reason reveals a required free-text field.
  bool get requiresDetail => switch (this) {
        CancelReasonId.appIssue => true,
        CancelReasonId.missingSpecificFeature => true,
        CancelReasonId.other => true,
        _ => false,
      };
}

class CancelReasonSubmission {
  const CancelReasonSubmission({
    required this.reason,
    required this.reasonLabel,
    this.detailText,
    this.provider,
  });

  final CancelReasonId reason;
  final String reasonLabel;
  final String? detailText;
  final String? provider;
}

/// Inserts a cancel-reason row into `subscription_cancel_reasons`.
///
/// Fire-and-forget by design: callers should wrap this in `unawaited(...)` so a
/// DB failure never blocks the cancel redirect. Errors are logged, never thrown.
Future<void> submitCancelReason(CancelReasonSubmission submission) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      appLog('submitCancelReason skipped: no authenticated user',
          name: 'CancelReason');
      return;
    }

    await supabase.from('subscription_cancel_reasons').insert({
      'user_id': userId,
      'reason_id': submission.reason.id,
      'reason_label': submission.reasonLabel,
      'detail_text': submission.reason.requiresDetail
          ? submission.detailText?.trim()
          : null,
      'provider': submission.provider,
    });
  } catch (error, stackTrace) {
    appLog('submitCancelReason failed (non-blocking)',
        name: 'CancelReason', error: error, stackTrace: stackTrace);
  }
}
