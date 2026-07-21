import 'package:moneko/core/plaid/models/synced_transaction.dart';

bool isPlaidInitialImportIncomplete(PlaidSyncStatus? syncStatus) =>
    syncStatus?.initialUpdateComplete != true;

bool canFinishPlaidReview({
  required bool isPlaid,
  required PlaidSyncStatus? syncStatus,
  required bool isPreparing,
  required bool isUpdatingWallet,
  required bool isCompleting,
  required bool hasError,
  required bool hasUnresolvedReview,
}) {
  if (isPreparing ||
      isUpdatingWallet ||
      isCompleting ||
      hasError ||
      hasUnresolvedReview) {
    return false;
  }
  return !isPlaid || !isPlaidInitialImportIncomplete(syncStatus);
}
