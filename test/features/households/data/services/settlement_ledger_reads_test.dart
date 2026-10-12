import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/ui/notifications/app_mutation_error_provider.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/data/services/household_service.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

const householdId = '00000000-0000-0000-0000-000000000001';

class _Client extends Mock implements SupabaseClient {}

class _AuthClient extends Mock implements GoTrueClient {}

class _User extends Mock implements User {}

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'me', email: 'me@example.com');
}

Map<String, dynamic> _split(int index) => {
      'id': 'group-$index',
      'household_id': householdId,
      'expense_id': 'expense-$index',
      'payer_user_id': 'alex',
      'split_type': 'amount',
      'currency': 'EUR',
      'total_amount_cents': 100,
      'created_at': '2026-10-12T00:00:00Z',
      'updated_at': '2026-10-12T00:00:00Z',
      'expense_split_lines': [
        {
          'id': 'line-$index',
          'split_group_id': 'group-$index',
          'user_id': 'me',
          'amount_cents': 100,
          'is_settled': false,
          'created_at': '2026-10-12T00:00:00Z',
          'updated_at': '2026-10-12T00:00:00Z',
        }
      ],
    };

http.Response _json(http.Request request, Object body) => http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test(
      'background snapshot conflict retires projection and reports an app-level error',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.enqueueHouseholdSettlementMutation(
        householdId: householdId,
        memberUserId: 'alex',
        mode: 'to_member',
        amountCents: 4000,
        currency: 'EUR',
        note: null,
        expectedSnapshotToken: 'v1:${List.filled(64, 'a').join()}',
        clientMutationId: 'conflict');
    final transport = SupabaseClient('https://settlement.test', 'test-key',
        httpClient: MockClient((request) async => _json(request, {
              'status': 'snapshot_conflict',
              'replayed': false,
              'client_mutation_id': 'conflict',
              'settlement_event_id': null,
              'requested_amount_cents': 4000,
              'applied_amount_cents': 0,
              'pair_balance_before_cents': 10000,
              'pair_balance_after_cents': 10000,
              'current_net_cents': 10000,
              'cleared_pair_balance': false,
              'result_snapshot_token': 'v1:${List.filled(64, 'b').join()}'
            })));
    addTearDown(transport.dispose);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      mobileOutboxSupabaseClientProvider.overrideWithValue(transport)
    ]);
    addTearDown(container.dispose);
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    expect(await coordinator.drainOutbox(maxMutations: 1), 1);
    expect(
        await database.getPendingHouseholdSettlementMutations(
            householdId: householdId),
        isEmpty);
    expect(
        await database.getHouseholdSettlementAcknowledgements(
            actorUserId: 'me', householdId: householdId),
        isEmpty);
    expect(container.read(appMutationErrorProvider)?.id, 'conflict');
  });

  test('a late old event response cannot overwrite a newer persisted snapshot',
      () async {
    final old = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final row = {
      'id': 'event-new',
      'household_id': householdId,
      'actor_user_id': 'me',
      'payer_user_id': 'alex',
      'participant_user_id': 'me',
      'amount_cents': 4000,
      'currency': 'EUR',
      'created_at': '2026-10-12T00:00:00Z',
      'is_express_netting': false
    };
    http.Request? first;
    final transport = SupabaseClient('https://settlement.test', 'test-key',
        httpClient: MockClient((request) async {
      if (++calls == 1) {
        first = request;
        started.complete();
        return old.future;
      }
      return _json(request, {
        'household_id': householdId,
        'actor_user_id': 'me',
        'events': [row],
        'event_count': 1
      });
    }));
    addTearDown(transport.dispose);
    final client = _Client();
    final auth = _AuthClient();
    final user = _User();
    when(() => user.id).thenReturn('me');
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
        (call) => transport.rpc(call.positionalArguments.single as String,
            params: call.namedArguments[#params] as Map<String, dynamic>?));
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      supabaseClientProvider.overrideWithValue(client),
      householdServiceProvider.overrideWithValue(HouseholdService(client)),
      localDatabaseProvider.overrideWith((ref) async => database)
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(
        householdSettlementEventsProvider(householdId), (_, __) {});
    addTearDown(sub.close);
    await started.future;
    container.invalidate(householdSettlementEventsProvider(householdId));
    expect(
        (await container
                .read(householdSettlementEventsProvider(householdId).future))
            .length,
        1);
    old.complete(_json(first!, {
      'household_id': householdId,
      'actor_user_id': 'me',
      'events': [],
      'event_count': 0
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(
        'households:settlement-payments:v2:$householdId:me')!) as Map;
    expect((saved['state']['items'] as List).length, 1);
  });

  test('history fetch failure is an error, never proof of empty history',
      () async {
    final transport = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient: MockClient((request) async => http.Response(
          jsonEncode({'code': 'XX000', 'message': 'history unavailable'}), 503,
          request: request, headers: {'content-type': 'application/json'})),
    );
    addTearDown(transport.dispose);
    final client = _Client();
    final auth = _AuthClient();
    final user = _User();
    when(() => user.id).thenReturn('me');
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    when(() => client.from(any())).thenAnswer(
        (call) => transport.from(call.positionalArguments.single as String));
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
        (call) => transport.rpc(call.positionalArguments.single as String,
            params: call.namedArguments[#params] as Map<String, dynamic>?));
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      supabaseClientProvider.overrideWithValue(client),
      householdServiceProvider.overrideWithValue(HouseholdService(client)),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(householdSettlementHistoryProvider(
                const SettlementHistoryParams(
                    householdId: householdId, limit: 0))
            .future),
        throwsA(isA<PostgrestException>()));
  });

  test('background acknowledgement keeps 60 EUR while confirmed reads lag',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.enqueueHouseholdSettlementMutation(
      householdId: householdId,
      memberUserId: 'alex',
      mode: 'to_member',
      amountCents: 4000,
      currency: 'EUR',
      note: null,
      expectedSnapshotToken: 'v1:${List.filled(64, 'a').join()}',
      clientMutationId: 'lagging-read',
    );
    final transport = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient: MockClient((request) async => _json(
          request,
          request.url.path.endsWith('households_settle_amount_and_notify_v2')
              ? {
                  'status': 'applied',
                  'replayed': false,
                  'client_mutation_id': 'lagging-read',
                  'settlement_event_id': 'event-lag',
                  'requested_amount_cents': 4000,
                  'applied_amount_cents': 4000,
                  'pair_balance_before_cents': 10000,
                  'pair_balance_after_cents': 6000,
                  'current_net_cents': 6000,
                  'cleared_pair_balance': false,
                  'result_snapshot_token': 'v1:${List.filled(64, 'b').join()}'
                }
              : {
                  'household_id': householdId,
                  'actor_user_id': 'me',
                  'events': [],
                  'event_count': 0
                })),
    );
    addTearDown(transport.dispose);
    final client = _Client();
    final auth = _AuthClient();
    final user = _User();
    when(() => user.id).thenReturn('me');
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
        (call) => transport.rpc(call.positionalArguments.single as String,
            params: call.namedArguments[#params] as Map<String, dynamic>?));
    final original = _split(0);
    final debt = ExpenseSplitGroup.fromJson({
      ...original,
      'total_amount_cents': 10000,
      'expense_split_lines': [
        <String, dynamic>{
          ...Map<String, dynamic>.from(
              (original['expense_split_lines'] as List).single as Map),
          'amount_cents': 10000,
        }
      ],
    });
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      supabaseClientProvider.overrideWithValue(client),
      mobileOutboxSupabaseClientProvider.overrideWithValue(transport),
      householdServiceProvider.overrideWithValue(HouseholdService(client)),
      localDatabaseProvider.overrideWith((ref) async => database),
      cachedHouseholdSplitsProvider.overrideWith((ref, params) async => [debt]),
    ]);
    addTearDown(container.dispose);
    final observed = <int>[];
    final sub =
        container.listen(settlementOverviewProvider(householdId), (_, value) {
      final overview = value.valueOrNull;
      if (overview != null) {
        observed.add(computePairwiseNet(
                splits: overview.splits,
                currentUserId: 'me',
                otherUserId: 'alex',
                currencyFilter: 'EUR',
                settlementPayments: overview.payments)
            .netCents);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    await container
        .read(pendingHouseholdSettlementPaymentsProvider(householdId).future);
    await container
        .read(householdSettlementPaymentsProvider(householdId).future);
    await Future<void>.delayed(Duration.zero);
    expect(observed.last, 6000);
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    expect(await coordinator.drainOutbox(maxMutations: 1), 1);
    container
        .invalidate(pendingHouseholdSettlementPaymentsProvider(householdId));
    await container
        .read(pendingHouseholdSettlementPaymentsProvider(householdId).future);
    await container
        .read(householdSettlementPaymentsProvider(householdId).future);
    await Future<void>.delayed(Duration.zero);
    expect(observed, everyElement(6000));
  });

  for (final size in [100, 1000, 1001, 2000, 10000]) {
    test('complete split read preserves all $size financial obligations',
        () async {
      final rows = List.generate(size, _split);
      final client = SupabaseClient(
        'https://settlement.test',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/rpc/')) {
            return _json(request, {
              'household_id': householdId,
              'actor_user_id': 'me',
              'splits': rows,
              'split_count': size,
            });
          }
          // Reproduce the configured PostgREST cap, even for limit=10000.
          return _json(request, rows.take(1000).toList());
        }),
      );
      addTearDown(client.dispose);
      final result = await HouseholdService(client).getHouseholdSplits(
        householdId: householdId,
      );
      expect(result.length, size);
      expect(
          computePairwiseNet(
            splits: result.map(ExpenseSplitGroup.fromJson).toList(),
            currentUserId: 'me',
            otherUserId: 'alex',
            currencyFilter: 'EUR',
          ).netCents,
          size * 100);
    });
  }

  test(
      'a truncated scalar snapshot fails rather than certifying a partial ledger',
      () async {
    final client = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient:
          MockClient((request) async => request.url.path.contains('/rpc/')
              ? _json(request, {
                  'household_id': householdId,
                  'actor_user_id': 'me',
                  'splits': [_split(0)],
                  'split_count': 1001
                })
              : _json(request, [_split(0)])),
    );
    addTearDown(client.dispose);
    await expectLater(
        HouseholdService(client).getHouseholdSplits(
          householdId: householdId,
        ),
        throwsA(isA<FormatException>()));
  });

  test(
      'confirmed event visible before pending retirement is counted once after restart',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.enqueueHouseholdSettlementMutation(
      householdId: householdId,
      memberUserId: 'alex',
      mode: 'to_member',
      amountCents: 4000,
      currency: 'EUR',
      note: null,
      expectedSnapshotToken: 'v1:${List.filled(64, 'a').join()}',
      clientMutationId: 'same-payment',
    );
    final event = {
      'id': 'event-1',
      'household_id': householdId,
      'payer_user_id': 'alex',
      'participant_user_id': 'me',
      'actor_user_id': 'me',
      'client_mutation_id': 'same-payment',
      'amount_cents': 4000,
      'currency': 'EUR',
      'created_at': '2026-10-12T00:00:00Z',
      'is_express_netting': false,
    };
    final transport = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient: MockClient((request) async => _json(
          request,
          request.url.path.contains('/rpc/')
              ? {
                  'household_id': householdId,
                  'actor_user_id': 'me',
                  'events': [event],
                  'event_count': 1
                }
              : [event])),
    );
    addTearDown(transport.dispose);
    final client = _Client();
    final auth = _AuthClient();
    final user = _User();
    when(() => user.id).thenReturn('me');
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    when(() => client.from(any())).thenAnswer(
        (call) => transport.from(call.positionalArguments.single as String));
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
        (call) => transport.rpc(call.positionalArguments.single as String,
            params: call.namedArguments[#params] as Map<String, dynamic>?));
    for (var restart = 0; restart < 2; restart++) {
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        supabaseClientProvider.overrideWithValue(client),
        householdServiceProvider.overrideWithValue(HouseholdService(client)),
        localDatabaseProvider.overrideWith((ref) async => database),
        cachedHouseholdSplitsProvider.overrideWith((ref, params) async => [
              ExpenseSplitGroup.fromJson({
                ..._split(0),
                'total_amount_cents': 10000,
                'expense_split_lines': [
                  <String, dynamic>{
                    ...Map<String, dynamic>.from(
                        (_split(0)['expense_split_lines'] as List).single
                            as Map),
                    'amount_cents': 10000
                  }
                ]
              }),
            ]),
      ]);
      final sub = container.listen(
          settlementOverviewProvider(householdId), (_, __) {},
          fireImmediately: true);
      try {
        await Future.wait([
          container
              .read(householdSettlementPaymentsProvider(householdId).future),
          container.read(
              pendingHouseholdSettlementPaymentsProvider(householdId).future),
          container.read(cachedHouseholdSplitsProvider(
                  const HouseholdSplitsParams(householdId: householdId))
              .future),
        ]);
        await Future<void>.delayed(Duration.zero);
        final overview = sub.read().requireValue;
        expect(
            computePairwiseNet(
                    splits: overview.splits,
                    currentUserId: 'me',
                    otherUserId: 'alex',
                    currencyFilter: 'EUR',
                    settlementPayments: overview.payments)
                .netCents,
            6000);
      } finally {
        sub.close();
        container.dispose();
      }
    }
  });
}
