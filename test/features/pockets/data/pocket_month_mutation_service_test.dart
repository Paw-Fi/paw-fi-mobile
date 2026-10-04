import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/data/pocket_month_mutation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('unknown acknowledgement recovery', () {
    const payload = <String, dynamic>{
      'userId': 'actor',
      'scope': 'personal',
      'householdId': null,
      'periodMonth': '2026-10-01',
      'currency': 'EUR',
      'expectedServerRevision': 0,
      'mutationRevision': 'first',
      'pockets': [
        {'id': 'optimistic-new'}
      ],
    };

    test('uses the original request key and gets the canonical creation ID',
        () async {
      final result = await recoverPocketMonthAcknowledgement(
        clientMutationId: 'month',
        payload: payload,
        invokeRpc: (name, params) async {
          expect(name, 'save_pockets_month_v1');
          expect(params['p_mutation_id'], 'month:first');
          expect(params['p_expected_revision'], 0);
          expect(params['p_snapshot'], payload);
          return {
            'success': true,
            'budgetId': 'budget',
            'revision': 1,
            'canonicalPocketIds': {'optimistic-new': 'canonical-new'}
          };
        },
      );
      expect(result!.canonicalPocketIds['optimistic-new'], 'canonical-new');
    });

    test('only a confirmed conflict allows a new save with a fresh revision',
        () async {
      expect(
          await recoverPocketMonthAcknowledgement(
              clientMutationId: 'month',
              payload: payload,
              invokeRpc: (_, params) async => {
                    'success': false,
                    'code': 'REVISION_CONFLICT',
                    'currentRevision': 2
                  }),
          isNull);
      await expectLater(
          recoverPocketMonthAcknowledgement(
              clientMutationId: 'month',
              payload: payload,
              invokeRpc: (_, params) async => {'success': true, 'revision': 1}),
          throwsA(isA<PocketMonthRevisionResponseError>()));
    });

    test('keeps transport errors unresolved', () async {
      await expectLater(
          recoverPocketMonthAcknowledgement(
              clientMutationId: 'month',
              payload: payload,
              invokeRpc: (_, params) async => throw const PostgrestException(
                  message: 'Connection unavailable', code: '08006')),
          throwsA(isA<PostgrestException>()));
    });
  });
  test('unknown acknowledgement never authorizes an offline rollback', () {
    expect(
        pocketMonthReviewAllowsRollback(pocketMonthReviewError(
            const PocketMonthRevisionResponseError('Missing acknowledgement'))),
        isFalse);
    expect(
        pocketMonthReviewNeedsAcknowledgement(pocketMonthReviewError(
            const PocketMonthRevisionResponseError('Missing acknowledgement'))),
        isTrue);
    expect(pocketMonthReviewAllowsRollback('legacy free-form error'), isFalse);
    expect(
        pocketMonthReviewAllowsRollback(pocketMonthReviewError(
            const PocketMonthRevisionConflict(
                expectedRevision: 1, currentRevision: 2))),
        isTrue);
  });
  group('savePocketMonthSnapshot', () {
    test(
        'authoritative validation rejection is terminal and infrastructure failure remains retryable',
        () async {
      Future<PocketMonthWriteResult> failure(String code) =>
          savePocketMonthSnapshot(
              userId: 'actor',
              scope: 'personal',
              householdId: null,
              periodMonth: '2026-10-01',
              currency: 'USD',
              expectedRevision: 0,
              mutationId: code,
              snapshot: const {},
              invokeRpc: (_, params) async =>
                  throw PostgrestException(message: 'Rejected', code: code));
      await expectLater(
          failure('22023'), throwsA(isA<PocketMonthWriteRejected>()));
      await expectLater(failure('XX000'), throwsA(isA<PostgrestException>()));
    });
    test('an undeployed RPC keeps the plan available for review', () async {
      await expectLater(
          savePocketMonthSnapshot(
              userId: 'actor',
              scope: 'personal',
              householdId: null,
              periodMonth: '2026-10-01',
              currency: 'USD',
              expectedRevision: 0,
              mutationId: 'old-backend',
              snapshot: const {},
              invokeRpc: (_, params) async => throw const PostgrestException(
                  message: 'Missing function', code: 'PGRST202')),
          throwsA(isA<PocketMonthRevisionUnavailable>()));
    });
    test('preserves the financial-cycle date and maps canonical IDs', () async {
      final calls = <({String name, Map<String, dynamic> params})>[];

      final result = await savePocketMonthSnapshot(
        userId: 'actor-1',
        scope: 'household',
        householdId: 'space-1',
        periodMonth: '2026-10-05',
        currency: 'eur',
        expectedRevision: 4,
        mutationId: 'mobile:pocket-month:10:1',
        snapshot: const {
          'totalBudgetCents': 100000,
          'replaceCategories': true,
          'pockets': [
            {'id': 'optimistic-pocket-1', 'name': 'Home'}
          ],
          'deletedPocketIds': <String>[],
        },
        invokeRpc: (name, params) async {
          calls.add((name: name, params: params));
          return {
            'success': true,
            'budgetId': 'budget-1',
            'revision': 5,
            'canonicalPocketIds': {'optimistic-pocket-1': 'pocket-1'},
          };
        },
      );

      expect(calls, hasLength(1));
      expect(calls.single.name, 'save_pockets_month_v1');
      expect(calls.single.params, containsPair('p_user_id', 'actor-1'));
      expect(calls.single.params, containsPair('p_scope', 'household'));
      expect(calls.single.params, containsPair('p_household_id', 'space-1'));
      expect(calls.single.params, containsPair('p_period_month', '2026-10-05'));
      expect(calls.single.params, containsPair('p_currency', 'EUR'));
      expect(calls.single.params, containsPair('p_expected_revision', 4));
      expect(
        calls.single.params,
        containsPair('p_mutation_id', 'mobile:pocket-month:10:1'),
      );
      expect(result.budgetId, 'budget-1');
      expect(result.revision, 5);
      expect(
        result.canonicalPocketIds,
        {'optimistic-pocket-1': 'pocket-1'},
      );
    });

    test('preserves the expected and current revisions on conflict', () async {
      await expectLater(
        savePocketMonthSnapshot(
          userId: 'actor-1',
          scope: 'personal',
          householdId: null,
          periodMonth: '2026-10-01',
          currency: 'USD',
          expectedRevision: 2,
          mutationId: 'mutation-1',
          snapshot: const {'totalBudgetCents': 1},
          invokeRpc: (name, params) async => {
            'success': false,
            'code': 'REVISION_CONFLICT',
            'expectedRevision': 2,
            'currentRevision': 7,
          },
        ),
        throwsA(
          isA<PocketMonthRevisionConflict>()
              .having((error) => error.expectedRevision, 'expected', 2)
              .having((error) => error.currentRevision, 'current', 7),
        ),
      );
    });

    test('keeps a conflict explicit when the server revision is malformed',
        () async {
      await expectLater(
        savePocketMonthSnapshot(
          userId: 'actor-1',
          scope: 'personal',
          householdId: null,
          periodMonth: '2026-10-01',
          currency: 'USD',
          expectedRevision: 2,
          mutationId: 'mutation-1',
          snapshot: const {'totalBudgetCents': 1},
          invokeRpc: (name, params) async => {
            'success': false,
            'code': 'REVISION_CONFLICT',
            'currentRevision': 'unknown',
          },
        ),
        throwsA(
          isA<PocketMonthRevisionConflict>().having(
            (error) => error.currentRevision,
            'current revision',
            isNull,
          ),
        ),
      );
    });

    test('rejects success acknowledgements without a server revision',
        () async {
      await expectLater(
        savePocketMonthSnapshot(
          userId: 'actor-1',
          scope: 'personal',
          householdId: null,
          periodMonth: '2026-10-01',
          currency: 'USD',
          expectedRevision: 2,
          mutationId: 'mutation-1',
          snapshot: const {'totalBudgetCents': 1},
          invokeRpc: (name, params) async => {
            'success': true,
            'budgetId': 'budget-1',
            'canonicalPocketIds': <String, String>{},
          },
        ),
        throwsA(isA<PocketMonthRevisionResponseError>()),
      );
    });

    test('rejects a successful new Pocket without its canonical identifier',
        () async {
      await expectLater(
        savePocketMonthSnapshot(
          userId: 'actor-1',
          scope: 'personal',
          householdId: null,
          periodMonth: '2026-10-01',
          currency: 'USD',
          expectedRevision: 2,
          mutationId: 'mutation-1',
          snapshot: const {
            'pockets': [
              {'id': 'optimistic-pocket-1'}
            ],
          },
          invokeRpc: (name, params) async => {
            'success': true,
            'budgetId': 'budget-1',
            'revision': 3,
            'canonicalPocketIds': <String, String>{},
          },
        ),
        throwsA(isA<PocketMonthRevisionResponseError>()),
      );
    });

    test('fails closed without a server revision', () async {
      var called = false;

      await expectLater(
        savePocketMonthSnapshot(
          userId: 'actor-1',
          scope: 'personal',
          householdId: null,
          periodMonth: '2026-10-01',
          currency: 'USD',
          expectedRevision: null,
          mutationId: 'mutation-1',
          snapshot: const {'totalBudgetCents': 1},
          invokeRpc: (name, params) async {
            called = true;
            return const {};
          },
        ),
        throwsA(isA<PocketMonthRevisionUnavailable>()),
      );
      expect(called, isFalse);
    });

    test('rejects malformed and unsuccessful responses', () async {
      Future<void> expectFailure(Object? response) async {
        await expectLater(
          savePocketMonthSnapshot(
            userId: 'actor-1',
            scope: 'personal',
            householdId: null,
            periodMonth: '2026-10-01',
            currency: 'USD',
            expectedRevision: 0,
            mutationId: 'mutation-1',
            snapshot: const {'totalBudgetCents': 1},
            invokeRpc: (name, params) async => response,
          ),
          throwsA(response == null
              ? isA<PocketMonthRevisionResponseError>()
              : isA<StateError>()),
        );
      }

      await expectFailure(null);
      await expectFailure({'success': false, 'error': 'Rejected'});
    });
  });
}
