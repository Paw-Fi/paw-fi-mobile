import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_month_review.dart';

void main() {
  test(
      'parses outstanding v4 review facts and suggestions without calculating recommendations',
      () {
    final review = PocketsMonthReview.fromV4Payload({
      'pockets_v4': {
        'review': {
          'id': 'review-2026-09',
          'reviewed_at': null,
          'setup_revision': 7,
          'monthly_budget_cents': 50000,
          'unassigned_cents': 42000,
          'carry_cents': 8000,
          'facts': {
            'spent_cents': 158000,
            'remaining_cents': 42000,
          },
          'suggestions': [
            {
              'lineage_id': 'food-lineage',
              'envelope_id': 'food',
              'label': 'Food',
              'amount_cents': 25000,
            },
            {
              'lineage_id': 'transport-lineage',
              'envelope_id': 'transport',
              'label': 'Transport',
              'amount_cents': 17000,
            },
          ],
        },
      },
    });

    expect(review, isNotNull);
    expect(review!.isOutstanding, isTrue);
    expect(review.setupRevision, 7);
    expect(review.unassignedCents, 42000);
    expect(review.monthlyBudgetCents, 50000);
    expect(review.carryCents, 8000);
    expect(review.facts['spent_cents'], 158000);
    expect(review.suggestions.map((item) => item.lineageId), [
      'food-lineage',
      'transport-lineage',
    ]);
  });

  test('uses production v4 parent permissions and root currency metadata', () {
    final review = PocketsMonthReview.fromV4Payload({
      'selected_currency': 'eur',
      'pockets_v4': {
        'can_edit': true,
        'is_current_period': true,
        'carry_cents': 5000,
        'previous_allocations': [
          {'lineage_id': 'food-lineage', 'amount_cents': 12000},
        ],
        'review': {
          'id': 'review-2026-09',
          'reviewed_at': null,
          'setup_revision': 7,
          'can_edit': false,
          'is_current_period': false,
          'currency': 'usd',
        },
      },
    });

    expect(review!.currency, 'EUR');
    expect(review.canEdit, isTrue);
    expect(review.isCurrentPeriod, isTrue);
    expect(review.carryCents, 5000);
    expect(review.facts['previous_allocations'], [
      {'lineage_id': 'food-lineage', 'amount_cents': 12000},
    ]);
  });

  test('treats a reviewed backend review as resolved', () {
    final review = PocketsMonthReview.fromV4Payload({
      'pockets_v4': {
        'review': {
          'id': 'review-2026-09',
          'reviewed_at': '2026-09-30T12:00:00Z',
          'setup_revision': 7,
        },
      },
    });

    expect(review!.isOutstanding, isFalse);
  });

  test('shows an outstanding review only once during a page visit', () {
    final gate = PocketsMonthReviewVisitGate();
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      monthlyBudgetCents: 42000,
      unassignedCents: 1,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
      canEdit: true,
      isCurrentPeriod: true,
    );

    expect(gate.shouldShow(review), isTrue);
    expect(gate.shouldShow(review), isFalse);
    expect(gate.shouldShow(null), isFalse);
  });

  test(
      'allows partial review allocations but rejects negative or over-unassigned drafts',
      () {
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      monthlyBudgetCents: 42000,
      unassignedCents: 42000,
      carryCents: 8000,
      facts: const {},
      suggestions: const [],
    );

    expect(
      validatePocketsMonthReviewDraft(
        review: review,
        allocationsCentsByEnvelopeId: const {'food': 25000},
      ).isValid,
      isTrue,
    );
    expect(
      validatePocketsMonthReviewDraft(
        review: review,
        allocationsCentsByEnvelopeId: const {'food': 42001},
      ).isValid,
      isFalse,
    );
    expect(
      validatePocketsMonthReviewDraft(
        review: review,
        allocationsCentsByEnvelopeId: const {'food': -1},
      ).isValid,
      isFalse,
    );
  });

  test('retains a draft only when the backend setup revision is unchanged', () {
    final current = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      unassignedCents: 42000,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
    );

    expect(
      shouldPreservePocketsMonthReviewDraft(
        current: current,
        refreshed: current,
      ),
      isTrue,
    );
    expect(
      shouldPreservePocketsMonthReviewDraft(
        current: current,
        refreshed: PocketsMonthReview(
          id: 'review-2026-09',
          isOutstanding: true,
          setupRevision: 8,
          reviewedAt: null,
          monthlyBudgetCents: 42000,
          unassignedCents: 42000,
          carryCents: 0,
          facts: const {},
          suggestions: const [],
        ),
      ),
      isFalse,
    );
  });

  test('keeps only drafts owned by the loaded review currency and revision',
      () {
    final usd = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      unassignedCents: 1,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
      currency: 'USD',
    );
    final eur = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 8,
      reviewedAt: null,
      unassignedCents: 1,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
      currency: 'EUR',
    );

    final retained = retainPocketsMonthReviewDrafts(
      draftsByReviewKey: {
        pocketsMonthReviewDraftKey(usd): const {'food': 100},
        pocketsMonthReviewDraftKey(eur): const {'food': 200},
      },
      reviews: [usd],
    );

    expect(retained, {
      pocketsMonthReviewDraftKey(usd): const {'food': 100}
    });
  });

  test('auto-opens only editable reviews for the current server period', () {
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      unassignedCents: 1,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
      canEdit: false,
      isCurrentPeriod: true,
    );

    expect(review.canAutoOpen, isFalse);
    expect(
      review.copyWith(status: 'pending_sync').canAutoOpen,
      isFalse,
    );
  });

  test('scopes an auto-open dismissal to its lifecycle review revision', () {
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      unassignedCents: 1,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
      currency: 'USD',
    );

    final key = pocketsMonthReviewAutoOpenKey(
      review: review,
      scope: 'household',
      householdId: 'household-1',
    );

    expect(key, contains('household:household-1:review-2026-09:r7'));
    expect(
      pocketsMonthReviewAutoOpenKey(
        review: review.copyWith(status: 'pending_sync'),
        scope: 'household',
        householdId: 'household-1',
      ),
      key,
    );
  });

  test(
      'uses revision and normalized draft contents in confirmation mutation IDs',
      () {
    final first = buildPocketsMonthReviewMutationId(
      userId: 'user-1',
      reviewId: 'review-2026-09',
      periodMonth: '2026-09-01',
      currency: 'USD',
      setupRevision: 7,
      allocationsCentsByLineageId: const {
        'food': 25000,
        'transport': 17000,
      },
    );
    final reordered = buildPocketsMonthReviewMutationId(
      userId: 'user-1',
      reviewId: 'review-2026-09',
      periodMonth: '2026-09-01',
      currency: 'USD',
      setupRevision: 7,
      allocationsCentsByLineageId: const {
        'transport': 17000,
        'food': 25000,
      },
    );
    final nextRevision = buildPocketsMonthReviewMutationId(
      userId: 'user-1',
      reviewId: 'review-2026-09',
      periodMonth: '2026-09-01',
      currency: 'USD',
      setupRevision: 8,
      allocationsCentsByLineageId: const {'food': 25000, 'transport': 17000},
    );

    expect(first, reordered);
    expect(first, contains('_r7_'));
    expect(nextRevision, isNot(first));
  });

  test(
      'builds SQL confirmation payload with setup revision and lineage allocations',
      () {
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      monthlyBudgetCents: 42000,
      unassignedCents: 42000,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
    );

    final payload = buildPocketsMonthReviewConfirmationPayload(
      userId: 'user-1',
      scope: 'personal',
      householdId: null,
      budgetMonth: '2026-09-01',
      currency: 'USD',
      review: review,
      allocationsCentsByLineageId: const {'food-lineage': 25000},
    );

    expect(payload['p_expected_setup_revision'], 7);
    expect(payload.containsKey('p_review_id'), isFalse);
    expect(payload['p_allocations'], [
      {'lineage_id': 'food-lineage', 'amount_cents': 25000},
    ]);
  });

  test('keeps explicit zero allocations in the exact RPC payload', () {
    final review = PocketsMonthReview(
      id: 'review-2026-09',
      isOutstanding: true,
      setupRevision: 7,
      reviewedAt: null,
      unassignedCents: 42000,
      carryCents: 0,
      facts: const {},
      suggestions: const [],
    );

    expect(
      buildPocketsMonthReviewConfirmationPayload(
        userId: 'user-1',
        scope: 'personal',
        householdId: null,
        budgetMonth: '2026-09-01',
        currency: 'USD',
        review: review,
        allocationsCentsByLineageId: const {
          'food-lineage': 0,
          'transport-lineage': 25000,
        },
      ),
      {
        'p_user_id': 'user-1',
        'p_scope': 'personal',
        'p_household_id': null,
        'p_budget_month': '2026-09-01',
        'p_currency': 'USD',
        'p_expected_setup_revision': 7,
        'p_allocations': [
          {'lineage_id': 'food-lineage', 'amount_cents': 0},
          {'lineage_id': 'transport-lineage', 'amount_cents': 25000},
        ],
      },
    );
  });
}
