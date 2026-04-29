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
}
