import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/core/plaid/plaid_sync_review_state.dart';

void main() {
  group('Plaid sync review gate', () {
    test('fails closed when Plaid sync status is unavailable', () {
      expect(
        canFinishPlaidReview(
          isPlaid: true,
          syncStatus: null,
          isPreparing: false,
          isUpdatingWallet: false,
          isCompleting: false,
          hasError: false,
          hasUnresolvedReview: false,
        ),
        isFalse,
      );
    });

    test('blocks completion until initial Plaid import is complete', () {
      const incomplete = PlaidSyncStatus(
        initialUpdateComplete: false,
        historicalUpdateComplete: false,
      );
      const completeEnough = PlaidSyncStatus(
        initialUpdateComplete: true,
        historicalUpdateComplete: false,
      );

      expect(
        canFinishPlaidReview(
          isPlaid: true,
          syncStatus: incomplete,
          isPreparing: false,
          isUpdatingWallet: false,
          isCompleting: false,
          hasError: false,
          hasUnresolvedReview: false,
        ),
        isFalse,
      );
      expect(
        canFinishPlaidReview(
          isPlaid: true,
          syncStatus: completeEnough,
          isPreparing: false,
          isUpdatingWallet: false,
          isCompleting: false,
          hasError: false,
          hasUnresolvedReview: false,
        ),
        isTrue,
      );
    });

    test('blocks every exit while work, errors, or review remain', () {
      const complete = PlaidSyncStatus(
        initialUpdateComplete: true,
        historicalUpdateComplete: true,
      );

      for (final state in [
        (true, false, false, false, false),
        (false, true, false, false, false),
        (false, false, true, false, false),
        (false, false, false, true, false),
        (false, false, false, false, true),
      ]) {
        expect(
          canFinishPlaidReview(
            isPlaid: true,
            syncStatus: complete,
            isPreparing: state.$1,
            isUpdatingWallet: state.$2,
            isCompleting: state.$3,
            hasError: state.$4,
            hasUnresolvedReview: state.$5,
          ),
          isFalse,
        );
      }
    });

    test('non-Plaid review does not require Plaid status metadata', () {
      expect(
        canFinishPlaidReview(
          isPlaid: false,
          syncStatus: null,
          isPreparing: false,
          isUpdatingWallet: false,
          isCompleting: false,
          hasError: false,
          hasUnresolvedReview: false,
        ),
        isTrue,
      );
    });
  });
}
