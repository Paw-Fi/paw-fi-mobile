import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/notifications/notification_dedupe_store.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/core/notifications/notification_pending_store.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

class _FakeDedupeStore extends NotificationDedupeStore {
  _FakeDedupeStore() : super(ttl: const Duration(hours: 24));

  final Set<String> _seen = <String>{};

  @override
  Future<bool> hasHandled(String id) async => _seen.contains(id);

  @override
  Future<void> markHandled(String id) async {
    _seen.add(id);
  }
}

class _FakePendingStore extends NotificationPendingStore {
  _FakePendingStore();

  final List<NotificationIntent> pending = <NotificationIntent>[];

  @override
  Future<void> add(NotificationIntent intent) async {
    pending.add(intent);
  }

  @override
  Future<List<NotificationIntent>> loadAll() async {
    return List<NotificationIntent>.from(pending);
  }

  @override
  Future<void> clear() async {
    pending.clear();
  }
}

void main() {
  test('queues until navigation is ready', () async {
    final executed = <String>[];
    var isReady = false;

    final dispatcher = NotificationDispatcher(
      null,
      dedupeStore: _FakeDedupeStore(),
      pendingStore: _FakePendingStore(),
      readinessOverride: () async => isReady,
      userIdOverride: () => 'user-1',
      resolverOverride: (intent) async => intent,
      executorOverride: (intent) async {
        executed.add(intent.notificationId ?? intent.action.name);
      },
    );

    await dispatcher.enqueueIntent(
      const NotificationIntent(
        action: NotificationIntentAction.openHouseholdDashboard,
        notificationId: 'n-1',
      ),
    );

    expect(executed, isEmpty);

    isReady = true;
    await dispatcher.enqueueIntent(
      const NotificationIntent(
        action: NotificationIntentAction.openHouseholdDashboard,
        notificationId: 'n-2',
      ),
    );

    expect(executed, <String>['n-1', 'n-2']);
  });

  test('persists pending intent while logged out then replays after login',
      () async {
    final executed = <String>[];
    final pendingStore = _FakePendingStore();
    String? currentUserId;

    final dispatcher = NotificationDispatcher(
      null,
      dedupeStore: _FakeDedupeStore(),
      pendingStore: pendingStore,
      readinessOverride: () async => true,
      userIdOverride: () => currentUserId,
      resolverOverride: (intent) async => intent,
      executorOverride: (intent) async {
        executed.add(intent.notificationId ?? intent.action.name);
      },
    );

    await dispatcher.enqueueIntent(
      const NotificationIntent(
        action: NotificationIntentAction.openExpenseSheet,
        notificationId: 'n-auth',
      ),
    );

    expect(executed, isEmpty);
    expect(pendingStore.pending.length, 1);

    currentUserId = 'user-1';
    await dispatcher.replayPendingIntents();

    expect(executed, <String>['n-auth']);
    expect(pendingStore.pending, isEmpty);
  });

  test('replay drains in-memory queue even when pending store is empty',
      () async {
    final executed = <String>[];
    var isReady = false;

    final dispatcher = NotificationDispatcher(
      null,
      dedupeStore: _FakeDedupeStore(),
      pendingStore: _FakePendingStore(),
      readinessOverride: () async => isReady,
      userIdOverride: () => 'user-1',
      resolverOverride: (intent) async => intent,
      executorOverride: (intent) async {
        executed.add(intent.notificationId ?? intent.action.name);
      },
    );

    await dispatcher.enqueueIntent(
      const NotificationIntent(
        action: NotificationIntentAction.openHouseholdDashboard,
        notificationId: 'queued-before-ready',
      ),
    );

    expect(executed, isEmpty);

    isReady = true;
    await dispatcher.replayPendingIntents();

    expect(executed, <String>['queued-before-ready']);
  });

  test('falls back to direct expense fetch after cache/reload misses',
      () async {
    final fetched = ExpenseEntry(
      id: 'exp-direct-1',
      date: DateTime(2026, 1, 1),
      amountCents: 4500,
      createdAt: DateTime(2026, 1, 1, 10, 0),
      currency: 'USD',
      category: 'food',
      type: 'expense',
    );

    var reloadCalls = 0;
    ExpenseEntry? injected;

    final dispatcher = NotificationDispatcher(
      null,
      cacheLookupOverride: (_) => null,
      analyticsReloadOverride: (_) async {
        reloadCalls += 1;
      },
      directExpenseFetchOverride: (_) async => fetched,
      cacheInjectionOverride: (expense) {
        injected = expense;
      },
    );

    final resolved = await dispatcher.resolveExpenseForNotification(
      expenseId: 'exp-direct-1',
      userId: 'user-1',
    );

    expect(resolved?.id, 'exp-direct-1');
    expect(reloadCalls, 3);
    expect(injected?.id, 'exp-direct-1');
  });
}
