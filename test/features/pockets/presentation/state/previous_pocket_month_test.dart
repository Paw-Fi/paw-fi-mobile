import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

void main() {
  for (final scope in PocketsScopeType.values) {
    test('nearest previous setup skips missing months in ${scope.name}',
        () async {
      final client = SupabaseClient('http://localhost', 'test-key',
          httpClient: MockClient((request) async {
        final query = request.url.queryParameters;
        expect(query['period_month'], 'lt.2026-10-01');
        expect(query['select'], contains('budget_envelopes!inner'));
        expect(query['order'], startsWith('period_month.desc'));
        expect(query['limit'], '1');
        expect(query['currency'], 'in.("EUR","USD")');
        expect(query['budget_envelopes.currency'], 'in.("EUR","USD")');
        expect(query['household_id'],
            scope == PocketsScopeType.personal ? 'is.null' : 'eq.house');
        expect(query['user_id'],
            scope == PocketsScopeType.household ? isNull : 'eq.actor');
        return http.Response(
            jsonEncode([
              {'period_month': '2026-07-01'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }));
      addTearDown(client.dispose);
      final month = await loadLatestPreviousPocketMonth(
        client: client,
        userId: 'actor',
        params: PocketsScopeParams(
          scope: scope,
          householdId: scope == PocketsScopeType.personal ? null : 'house',
          currency: 'EUR',
          selectedCurrencies: const ['EUR', 'USD'],
          periodMonth: DateTime(2026, 10, 15),
          financialMonthStartDay: 15,
        ),
      );
      expect(month, DateTime(2026, 7, 15));
    });
  }

  test('no historical pockets returns no source, not last month', () async {
    final client = SupabaseClient('http://localhost', 'test-key',
        httpClient: MockClient((request) async => http.Response('[]', 200,
            headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    expect(
        await loadLatestPreviousPocketMonth(
          client: client,
          userId: 'actor',
          params: PocketsScopeParams(
              scope: PocketsScopeType.personal,
              currency: 'EUR',
              periodMonth: DateTime(2026, 10)),
        ),
        isNull);
  });

  test('failed history lookup remains an error rather than no history',
      () async {
    final client = SupabaseClient('http://localhost', 'test-key',
        httpClient: MockClient((request) async => http.Response(
            '{"message":"unavailable","code":"503"}', 503,
            headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    await expectLater(
        loadLatestPreviousPocketMonth(
          client: client,
          userId: 'actor',
          params: PocketsScopeParams(
              scope: PocketsScopeType.personal,
              currency: 'EUR',
              periodMonth: DateTime(2026, 10)),
        ),
        throwsA(isA<PostgrestException>()));
  });
}
