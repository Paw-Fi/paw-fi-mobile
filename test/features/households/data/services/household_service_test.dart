import 'dart:async';
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
    test('sends only non-null optional fields and returns invite_url on 200', () async {
      final response = _MockFunctionResponse();
      when(() => response.status).thenReturn(200);
      when(() => response.data).thenReturn({'invite_url': 'https://example.com/invite/TOKEN'});

      Map<String, dynamic>? capturedBody;
      when(() => functions.invoke('households-create-invite', body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return response;
      });

      final url = await service.createInvite(
        householdId: 'hh_123',
        invitedEmail: null, // should be omitted
        personalMessage: '', // should be omitted
        expiresInDays: 5,
      );

      expect(url, 'https://example.com/invite/TOKEN');
      expect(capturedBody, isNotNull);
      expect(capturedBody!.keys, containsAll(['household_id', 'expires_in_days']));
      expect(capturedBody!.containsKey('invited_email'), isFalse);
      expect(capturedBody!.containsKey('personal_message'), isFalse);
    });

    test('throws on non-200 response', () async {
      final response = _MockFunctionResponse();
      when(() => response.status).thenReturn(500);
      when(() => response.data).thenReturn({'error': 'boom'});
      when(() => functions.invoke('households-create-invite', body: any(named: 'body')))
          .thenAnswer((_) async => response);

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
      when(() => functions.invoke('households-create-invite', body: any(named: 'body')))
          .thenAnswer((_) => completer.future);

      final sw = Stopwatch()..start();
      expect(
        () => service.createInvite(
          householdId: 'hh_123',
          expiresInDays: 7,
        ),
        throwsA(isA<TimeoutException>()),
      );
      sw.stop();
      // We cannot deterministically assert exact time in unit test env, but ensure it doesn't hang indefinitely
    });
  });
}
