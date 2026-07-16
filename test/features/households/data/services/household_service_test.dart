import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/households/data/services/household_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockFunctionResponse extends Mock implements FunctionResponse {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

String _snapshotToken(String character) =>
    'v1:${List<String>.filled(64, character).join()}';

void main() {
  late _MockSupabaseClient supabase;
  late _MockFunctionsClient functions;
  late HouseholdService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    supabase = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    when(() => supabase.functions).thenReturn(functions);
    service = HouseholdService(supabase);
  });

  group('HouseholdService.createInvite', () {
    test('sends only non-null optional fields and returns invite_url on 200',
        () async {
      final response = _MockFunctionResponse();
      when(() => response.status).thenReturn(200);
      when(() => response.data)
          .thenReturn({'invite_url': 'https://example.com/invites/TOKEN'});

      Map<String, dynamic>? capturedBody;
      when(() => functions.invoke('households-create-invite',
          body: any(named: 'body'))).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return response;
      });

      final url = await service.createInvite(
        householdId: 'hh_123',
        invitedEmail: null, // should be omitted
        personalMessage: '', // should be omitted
        expiresInDays: 5,
      );

      expect(url, 'TOKEN');
      expect(capturedBody, isNotNull);
      expect(
          capturedBody!.keys, containsAll(['household_id', 'expires_in_days']));
      expect(capturedBody!.containsKey('invited_email'), isFalse);
      expect(capturedBody!.containsKey('personal_message'), isFalse);
    });

    test('throws on non-200 response', () async {
      final response = _MockFunctionResponse();
      when(() => response.status).thenReturn(500);
      when(() => response.data).thenReturn({'error': 'boom'});
      when(() => functions.invoke('households-create-invite',
          body: any(named: 'body'))).thenAnswer((_) async => response);

      expect(
        () => service.createInvite(
          householdId: 'hh_123',
          expiresInDays: 7,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('times out and throws within ~20s when function stalls', () async {
      // Simulate an invocation that never completes
      final completer = Completer<FunctionResponse>();
      when(() => functions.invoke('households-create-invite',
          body: any(named: 'body'))).thenAnswer((_) => completer.future);

      final sw = Stopwatch()..start();
      await expectLater(
        service.createInvite(
          householdId: 'hh_123',
          expiresInDays: 7,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
      sw.stop();
      // We cannot deterministically assert exact time in unit test env, but ensure it doesn't hang indefinitely
    });
  });

  group('HouseholdService.updateHousehold', () {
    test('sends null auto split config when explicitly clearing defaults',
        () async {
      final responseJson = {
        'id': 'hh_123',
        'name': 'Home',
        'owner_id': 'user_1',
        'currency': 'USD',
        'is_portfolio': false,
        'ai_use_default_split': true,
        'ai_default_split_config': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };

      Map<String, dynamic>? capturedUpdates;
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          capturedUpdates = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(responseJson),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final serviceWithRealClient = HouseholdService(client);

      await serviceWithRealClient.updateHousehold(
        householdId: 'hh_123',
        autoSplitEnabled: true,
        autoSplitConfig: null,
        updateAutoSplitConfig: true,
      );

      expect(capturedUpdates, isNotNull);
      expect(capturedUpdates!['ai_use_default_split'], isTrue);
      expect(capturedUpdates!.containsKey('ai_default_split_config'), isTrue);
      expect(capturedUpdates!['ai_default_split_config'], isNull);
    });

    test('sends portfolio conversion when explicitly set to shared', () async {
      final responseJson = {
        'id': 'hh_123',
        'name': 'Home',
        'owner_id': 'user_1',
        'currency': 'USD',
        'is_portfolio': false,
        'ai_use_default_split': true,
        'ai_default_split_config': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };

      Map<String, dynamic>? capturedUpdates;
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          capturedUpdates = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(responseJson),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final serviceWithRealClient = HouseholdService(client);

      await serviceWithRealClient.updateHousehold(
        householdId: 'hh_123',
        isPortfolio: false,
      );

      expect(capturedUpdates, isNotNull);
      expect(capturedUpdates!['is_portfolio'], isFalse);
    });
  });

  group('HouseholdService.deleteHousehold', () {
    test('delegates deletion to the household cleanup RPC', () async {
      Map<String, dynamic>? capturedParams;
      when(() => supabase.rpc('delete_household', params: any(named: 'params')))
          .thenAnswer((invocation) {
        capturedParams =
            invocation.namedArguments[#params] as Map<String, dynamic>;
        return PostgrestClient(
          'https://example.test/rest/v1',
          headers: Map<String, String>.of(const {}),
          httpClient: MockClient(
            (request) async => http.Response('', 204, request: request),
          ),
        ).rpc<dynamic>(
          'delete_household',
          params: {'p_household_id': 'hh_123'},
        );
      });

      await service.deleteHousehold('hh_123');

      expect(capturedParams, {'p_household_id': 'hh_123'});
      verify(() => supabase.rpc('delete_household',
          params: {'p_household_id': 'hh_123'})).called(1);
    });
  });

  group('HouseholdService.getHouseholdSplitsByIds', () {
    test('chunks IDs below the PostgREST max_rows response cap', () async {
      final requestedChunkSizes = <int>[];
      final ids = List<String>.generate(
        1201,
        (index) => '00000000-0000-0000-0000-'
            '${index.toString().padLeft(12, '0')}',
      );
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            endsWith('/rest/v1/rpc/get_household_home_split_groups_v1'),
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final chunk = (body['p_split_group_ids'] as List).cast<String>();
          requestedChunkSizes.add(chunk.length);
          return http.Response(
            jsonEncode(
              chunk
                  .map((id) => {
                        'id': id,
                        'created_at': '2026-07-10T12:00:00.000Z',
                      })
                  .toList(growable: false),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final rows = await HouseholdService(client).getHouseholdSplitsByIds(
        householdId: 'household-1',
        splitGroupIds: ids,
      );

      expect(requestedChunkSizes, [500, 500, 201]);
      expect(rows, hasLength(1201));
      expect(rows.map((row) => row['id']).toSet(), ids.toSet());
    });

    test('falls back to the previous REST query for any optimized RPC error',
        () async {
      final requestedPaths = <String>[];
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path
              .endsWith('/rest/v1/rpc/get_household_home_split_groups_v1')) {
            return http.Response(
              jsonEncode({
                'code': '42501',
                'message': 'optimized path unavailable',
                'details': null,
                'hint': null,
              }),
              403,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final rows = await HouseholdService(client).getHouseholdSplitsByIds(
        householdId: '00000000-0000-0000-0000-000000000001',
        splitGroupIds: const ['00000000-0000-0000-0000-000000000002'],
      );

      expect(rows, isEmpty);
      expect(
        requestedPaths,
        contains('/rest/v1/expense_split_groups'),
      );
    });
  });

  group('HouseholdService.getHouseholdMembers', () {
    test('falls back to the previous REST query for any optimized RPC error',
        () async {
      final requestedPaths = <String>[];
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path
              .endsWith('/rest/v1/rpc/get_household_home_members_v1')) {
            return http.Response(
              jsonEncode({
                'code': '42501',
                'message': 'optimized path unavailable',
                'details': null,
                'hint': null,
              }),
              403,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final rows = await HouseholdService(client).getHouseholdMembers(
        '00000000-0000-0000-0000-000000000001',
      );

      expect(rows, isEmpty);
      expect(requestedPaths, contains('/rest/v1/household_members'));
    });
  });

  group('HouseholdService.getSettlementCalculationV3', () {
    test('requests one atomic net-and-rows snapshot with normalized currency',
        () async {
      Map<String, dynamic>? capturedBody;
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            endsWith(
              '/rest/v1/rpc/households_get_settlement_calculation_v3',
            ),
          );
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'net_cents': 6611,
              'rows': [
                {
                  'direction': 'you_owe',
                  'expense_id': 'expense-1',
                  'split_group_id': 'group-1',
                  'split_line_id': 'line-1',
                  'expense_date': '2026-07-16T00:54:59.202Z',
                  'expense_description': 'Wet and dry catfood',
                  'expense_category': 'Pets',
                  'expense_raw_text': 'Wet and dry catfood',
                  'expense_type': 'expense',
                  'total_amount_cents': 11223,
                  'remaining_amount_cents': 11223,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final response =
          await HouseholdService(client).getSettlementCalculationV3(
        householdId: 'household-1',
        memberUserId: 'member-1',
        currency: ' cad ',
      );

      expect(capturedBody, {
        'p_household_id': 'household-1',
        'p_member_user_id': 'member-1',
        'p_currency': 'CAD',
      });
      expect(response['net_cents'], 6611);
      expect(response['rows'], hasLength(1));
    });

    test('rejects a non-object RPC response instead of showing zero', () async {
      final client = SupabaseClient(
        'https://example.test',
        'anon-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );

      expect(
        () => HouseholdService(client).getSettlementCalculationV3(
          householdId: 'household-1',
          memberUserId: 'member-1',
          currency: 'CAD',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('HouseholdService.settleAmountAndNotifyV2', () {
    test('sends the immutable strict request and preserves a null note',
        () async {
      final auth = _MockGoTrueClient();
      final user = _MockUser();
      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('actor-1');

      Map<String, dynamic>? capturedParams;
      when(
        () => supabase.rpc(
          'households_settle_amount_and_notify_v2',
          params: any(named: 'params'),
        ),
      ).thenAnswer((invocation) {
        capturedParams =
            invocation.namedArguments[#params] as Map<String, dynamic>;
        return PostgrestClient(
          'https://example.test/rest/v1',
          headers: Map<String, String>.of(const {}),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'status': 'snapshot_conflict',
                'replayed': false,
                'client_mutation_id': 'mobile:settlement:1',
                'settlement_event_id': null,
                'requested_amount_cents': 2500,
                'applied_amount_cents': 0,
                'pair_balance_before_cents': 6611,
                'pair_balance_after_cents': 6611,
                'current_net_cents': 6611,
                'cleared_pair_balance': false,
                'result_snapshot_token': _snapshotToken('b'),
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        ).rpc<dynamic>('households_settle_amount_and_notify_v2');
      });

      final result = await service.settleAmountAndNotifyV2(
        householdId: 'household-1',
        memberUserId: 'member-1',
        mode: 'to_member',
        amountCents: 2500,
        currency: ' cad ',
        expectedSnapshotToken: _snapshotToken('a'),
        clientMutationId: ' mobile:settlement:1 ',
        settlementNote: '   ',
      );

      expect(capturedParams, {
        'p_household_id': 'household-1',
        'p_member_user_id': 'member-1',
        'p_mode': 'to_member',
        'p_amount_cents': 2500,
        'p_currency': 'CAD',
        'p_expected_snapshot_token': _snapshotToken('a'),
        'p_client_mutation_id': 'mobile:settlement:1',
        'p_settlement_note': null,
      });
      expect(result['status'], 'snapshot_conflict');
    });

    test('rejects malformed intent before invoking the RPC', () async {
      final auth = _MockGoTrueClient();
      final user = _MockUser();
      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('actor-1');

      expect(
        () => service.settleAmountAndNotifyV2(
          householdId: 'household-1',
          memberUserId: 'member-1',
          mode: 'both',
          amountCents: 2500,
          currency: 'CAD',
          expectedSnapshotToken: 'not-a-snapshot-token',
          clientMutationId: 'mobile:settlement:1',
        ),
        throwsA(isA<FormatException>()),
      );
      verifyNever(
        () => supabase.rpc(
          'households_settle_amount_and_notify_v2',
          params: any(named: 'params'),
        ),
      );
    });
  });
}
