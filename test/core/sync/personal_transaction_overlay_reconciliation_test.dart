import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _actor = StateProvider((ref) => 'user-1');

class _Auth extends Auth {
  @override
  AppUser build() => AppUser(uid: ref.watch(_actor), email: 'test@example.com');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Future<http.Response> Function(http.Request) respond;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage()),
      httpClient: MockClient((request) => respond(request)),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  late MonekoDatabase database;
  late ProviderContainer container;
  late ExpenseEntry optimistic;
  setUp(() async {
    database = MonekoDatabase.inMemory();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
    optimistic = ExpenseEntry(
      id: 'optimistic_import',
      userId: 'user-1',
      date: DateTime(2026, 10, 8),
      createdAt: DateTime(2026, 10, 12),
      amountCents: 185590,
      currency: 'TRY',
      rawText: 'alışveriş',
      type: 'expense',
    );
    container
        .read(analyticsProvider.notifier)
        .addOptimisticTransaction(optimistic);
    await database.writeOptimisticTransaction(
      entry: optimistic,
      clientMutationId: 'mobile:optimistic_import',
      operation: 'create',
      payload: {
        'aiCaptureId': 'capture-1',
        'transaction': optimistic.toJson(),
        'functionName': 'save-expense',
        'requestBody': {'amount': 1855.9, 'currency': 'TRY'},
      },
    );
    respond = (_) async => http.Response(
        jsonEncode({
          'success': true,
          'data': optimistic.copyWith(id: 'server-import').toJson(),
        }),
        200,
        headers: {'content-type': 'application/json'});
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('background create replaces the Personal analytics alias', () async {
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    await coordinator.drainOutbox(maxMutations: 1);
    final visible = container.read(analyticsProvider).allExpenses;
    expect(visible.map((e) => e.id), ['server-import']);
    expect(visible.single.amountCents, 185590);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
  });

  test('a retryable save retains the alias until canonical acknowledgement',
      () async {
    respond = (_) async => http.Response(
        jsonEncode({'success': false, 'error': 'offline'}), 503,
        headers: {'content-type': 'application/json'});
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    await coordinator.drainOutbox(maxMutations: 1);
    expect(
        container.read(analyticsProvider).allExpenses.single.id, optimistic.id);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusFailed);
  });

  test(
      'terminal rejection removes the old alias without discarding another input',
      () async {
    final other = optimistic.copyWith(id: 'optimistic_other');
    container.read(analyticsProvider.notifier).addOptimisticTransaction(other);
    respond = (_) async => http.Response(
        jsonEncode({'success': false, 'error': 'Invalid transaction'}), 400,
        headers: {'content-type': 'application/json'});
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    await coordinator.drainOutbox(maxMutations: 1);
    expect(container.read(analyticsProvider).allExpenses.map((e) => e.id),
        [other.id]);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
  });

  test('a late create acknowledgement preserves a newer local edit', () async {
    final dispatched = Completer<void>();
    final reply = Completer<http.Response>();
    respond = (_) {
      dispatched.complete();
      return reply.future;
    };
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    final drain = coordinator.drainOutbox(maxMutations: 1);
    await dispatched.future;
    final edited = optimistic.copyWith(amountCents: 200000);
    await database.writeOptimisticTransaction(
      entry: edited,
      clientMutationId: 'edit-1',
      operation: 'update_transaction',
      payload: {
        'expenseId': optimistic.id,
        'originalEntry': optimistic.toJson()
      },
    );
    container
        .read(analyticsProvider.notifier)
        .replaceOptimisticTransaction(optimistic.id, edited);
    reply.complete(http.Response(
        jsonEncode({
          'success': true,
          'data': optimistic.copyWith(id: 'server-import').toJson(),
        }),
        200,
        headers: {'content-type': 'application/json'}));
    await drain;
    final visible = container.read(analyticsProvider).allExpenses;
    expect(visible.map((e) => e.id), ['server-import']);
    expect(visible.single.amountCents, 200000);
  });

  test('an old actor acknowledgement cannot enter the next actor analytics',
      () async {
    final dispatched = Completer<void>();
    final reply = Completer<http.Response>();
    respond = (_) {
      dispatched.complete();
      return reply.future;
    };
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    final drain = coordinator.drainOutbox(maxMutations: 1);
    await dispatched.future;
    container.read(_actor.notifier).state = 'user-2';
    container
        .read(analyticsProvider.notifier)
        .removeOptimisticTransactionById(optimistic.id);
    reply.complete(http.Response(
        jsonEncode({
          'success': true,
          'data': optimistic.copyWith(id: 'server-import').toJson(),
        }),
        200,
        headers: {'content-type': 'application/json'}));
    await drain;
    expect(container.read(analyticsProvider).allExpenses, isEmpty);
  });
}
