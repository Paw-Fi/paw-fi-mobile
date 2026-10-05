import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'actor', email: 'actor@example.com');
  void switchAccount() {
    state = const AppUser(uid: 'other', email: 'other@example.com');
  }
}

// Suppress unrelated read-side bootstrapping; all save/reconciliation methods
// and the provider's actual disposal remain the production implementation.
class _SaveOnlyPockets extends PocketsNotifier {
  _SaveOnlyPockets(super.ref, super.params);
  @override
  Future<void> load({bool bypassCache = false}) async {}
  Future<void> loadAfterDisposal() => super.load();
}

void main() {
  late Completer<http.Response> response;
  late Completer<void> dispatched;
  var requestCount = 0;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-key',
      httpClient: MockClient((request) async {
        requestCount++;
        dispatched.complete();
        final reply = await response.future;
        return http.Response(reply.body, reply.statusCode,
            headers: reply.headers, request: request);
      }),
    );
  });

  late MonekoDatabase database;
  late ProviderContainer container;
  final scope = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      periodMonth: DateTime(2026, 10),
      currency: 'EUR');
  const mutation =
      PocketsMutationHandle(clientMutationId: 'month', revision: 'first');
  setUp(() async {
    response = Completer<http.Response>();
    dispatched = Completer<void>();
    requestCount = 0;
    database = MonekoDatabase.inMemory();
    await database.enqueueMutation(
      clientMutationId: 'month',
      entityType: 'pockets_month',
      entityId: 'month',
      operation: 'save_pockets_month',
      payload: {
        'userId': 'actor',
        'scope': 'personal',
        'periodMonth': '2026-10-01',
        'currency': 'EUR',
        'mutationRevision': 'first',
        'expectedServerRevision': 0,
        'pockets': <Object>[],
      },
    );
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
      localTransactionRevisionProvider
          .overrideWith((ref) => const Stream.empty()),
      pocketsProvider(scope)
          .overrideWith((ref) => _SaveOnlyPockets(ref, scope)),
    ]);
  });
  tearDown(() {
    container.dispose();
    database.close();
  });

  test('a server acknowledgement survives disposal of the real Pocket notifier',
      () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    await dispatched.future;
    container.invalidate(pocketsProvider(scope));
    await container.pump();
    expect(notifier.mounted, isFalse);
    await (notifier as _SaveOnlyPockets).loadAfterDisposal();
    response.complete(http.Response(
        jsonEncode({
          'success': true,
          'budgetId': 'canonical-budget',
          'revision': 1,
          'canonicalPocketIds': <String, String>{},
        }),
        200,
        headers: {'content-type': 'application/json'}));
    expect((await save).revision, 1);
    await notifier.markQueuedPocketsSnapshotSynced(mutation);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
  });

  test('a late acknowledgement cannot project into a different account',
      () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    final previous = container.read(pocketsProvider(scope));
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    await dispatched.future;
    (container.read(authProvider.notifier) as _TestAuth).switchAccount();
    response.complete(http.Response(
        jsonEncode({
          'success': true,
          'budgetId': 'canonical-budget',
          'revision': 1,
          'canonicalPocketIds': <String, String>{},
        }),
        200,
        headers: {'content-type': 'application/json'}));
    await save;
    expect(container.read(pocketsProvider(scope)), same(previous));
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
  });

  test('a rejection after an account switch retains the original queued save',
      () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    final failure = expectLater(
        save, throwsA(predicate<Object>(shouldKeepQueuedPocketsMutation)));
    await dispatched.future;
    (container.read(authProvider.notifier) as _TestAuth).switchAccount();
    response.complete(http.Response(
        jsonEncode({
          'code': '42501',
          'message': 'actor no longer matches request',
        }),
        403,
        headers: {'content-type': 'application/json'}));
    await failure;
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusQueued);
  });

  test('a rejection for the same actor remains terminal', () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    final failure = expectLater(
        save,
        throwsA(predicate<Object>(
            (error) => !shouldKeepQueuedPocketsMutation(error))));
    await dispatched.future;
    response.complete(http.Response(
        jsonEncode({
          'code': '42501',
          'message': 'Pocket write forbidden',
        }),
        403,
        headers: {'content-type': 'application/json'}));
    await failure;
    await notifier.cancelQueuedPocketsSnapshot(
        mutation, StateError('rejected'));
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
  });

  test('an ambiguous acknowledgement remains in review after disposal',
      () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    final failure = expectLater(
        save, throwsA(predicate<Object>(shouldKeepQueuedPocketsMutation)));
    await dispatched.future;
    container.invalidate(pocketsProvider(scope));
    await container.pump();
    response.complete(http.Response('{"success":true}', 200,
        headers: {'content-type': 'application/json'}));
    await failure;
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusNeedsReview);
  });

  test('an account switch before dispatch preserves the original queued save',
      () async {
    final notifier = container.read(pocketsProvider(scope).notifier);
    (container.read(authProvider.notifier) as _TestAuth).switchAccount();
    response.complete(http.Response(
        jsonEncode({
          'success': true,
          'budgetId': 'canonical-budget',
          'revision': 1,
          'canonicalPocketIds': <String, String>{},
        }),
        200,
        headers: {'content-type': 'application/json'}));
    final save = notifier.persistQueuedPocketsSnapshotNow(mutation);
    // The queued write must be deferred rather than dispatched under another
    // account or treated as an authoritative rejection of the original draft.
    await expectLater(
        save, throwsA(predicate<Object>(shouldKeepQueuedPocketsMutation)));
    expect(requestCount, 0);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusQueued);
  });
}
