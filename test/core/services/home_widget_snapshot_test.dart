import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/home_widget_snapshot.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_manager.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

HomeWidgetSnapshot snapshot(
        {double spent = 180, List<WidgetPocketData>? categories}) =>
    HomeWidgetSnapshot(
        userId: 'user-1',
        currency: 'EUR',
        periodMonth: '2026-09-25',
        totalSpent: spent,
        totalBudget: 1085,
        pockets: [],
        topCategories: categories);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final storage = <String, Object?>{};
  final updates = <MethodCall>[];
  Future<void> Function(MethodCall)? beforeCall;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    storage.clear();
    updates.clear();
    beforeCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      await beforeCall?.call(call);
      final args = call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'getWidgetData':
          return storage[args['id']] ?? args['defaultValue'];
        case 'saveWidgetData':
          storage[args['id'] as String] = args['data'];
          return true;
        case 'updateWidget':
          updates.add(call);
          return true;
        case 'setAppGroupId':
          return true;
      }
      throw MissingPluginException(call.method);
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unknown financial reads publish no temporary zeros', () {
    expect(
        buildHomeWidgetSnapshot(
            userId: 'user-1', state: PocketsState.initial()),
        isNull);
    final offlineMonth = PocketsState.initial().copyWith(
        isLoading: false, periodMonth: DateTime(2026, 10), currency: 'EUR');
    expect(
        buildHomeWidgetSnapshot(userId: 'user-1', state: offlineMonth), isNull);
    final confirmedEmpty = offlineMonth
        .copyWith(nativeBudgetByCurrency: {'EUR': 0}, aggregateTotalSpent: 0);
    expect(
        buildHomeWidgetSnapshot(userId: 'user-1', state: confirmedEmpty)!
            .totalSpent,
        0);
    expect(
        buildHomeWidgetSnapshot(
            userId: 'user-1',
            state: PocketsState.initial()
                .copyWith(isLoading: false, error: 'offline')),
        isNull);
  });

  test(
      'uses converted canonical aggregates and leaves Pocket rows native including rollover',
      () {
    final pocket = PocketEnvelope(
        id: 'usd',
        name: '旅行',
        budgetAmountCents: 10000,
        availableBudgetCents: 12500,
        spent: 200,
        currency: 'USD',
        lastUpdated: DateTime(2026));
    final state = PocketsState.initial().copyWith(
        isLoading: false,
        saved: [pocket],
        editing: [pocket],
        periodMonth: DateTime(2026, 9, 25),
        currency: 'EUR',
        totalBudget: 1085,
        savedTotalBudget: 1085,
        aggregateTotalSpent: 180);
    final result = buildHomeWidgetSnapshot(userId: 'user-1', state: state)!;
    expect(result.totalSpent, 180);
    expect(result.totalBudget, 1085);
    expect(result.pockets.single.spent, 200);
    expect(result.pockets.single.budget, 125);
    expect(result.pockets.single.currency, 'USD');
    expect(result.pockets.single.id, 'usd');
    expect(result.periodMonth, '2026-09-25');
    expect(
        buildHomeWidgetSnapshot(
                userId: 'user-1',
                state: state.copyWith(isLoading: true, error: 'offline'))!
            .totalSpent,
        180);
    expect(
        buildHomeWidgetSnapshot(
            userId: 'user-1', state: state.copyWith(totalBudget: 500)),
        isNull);
    expect(
        buildHomeWidgetSnapshot(
            userId: 'user-1',
            state: state.copyWith(aggregateTotalSpent: double.nan)),
        isNull);
  });

  test('zero budget retains spend and over-budget progress clamps', () {
    final data = const HomeWidgetSnapshot(
        userId: 'user-1',
        currency: 'USD',
        periodMonth: '2026-10-01',
        totalSpent: 24.5,
        totalBudget: 0,
        pockets: []).toJson();
    expect(data['remainingBudget'], contains('-'));
    expect(data['progress'], 0);
    expect(snapshot(spent: 2000).toJson()['progress'], 1);
  });

  test('publishes a single owned snapshot and reloads both iOS kinds',
      () async {
    await WidgetService().synchronizeOwner('user-1');
    updates.clear();
    expect(
        await WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => true),
        isTrue);
    final data = jsonDecode(storage['widget_snapshot_personal_EUR'] as String)
        as Map<String, dynamic>;
    expect(data['userId'], 'user-1');
    expect(data['totalSpent'], contains('180'));
    expect(data['remainingBudget'], contains('905'));
    expect(data['progress'], closeTo(180 / 1085, .000001));
    expect(updates.map((call) => (call.arguments as Map)['ios']),
        ['MonekoWidget', 'MonekoTopCategoriesWidget']);
    expect(storage.containsKey('total_spent_personal_EUR'), isFalse);
  });

  test('offline storage failure retains previous snapshot and can retry',
      () async {
    storage['widget_user_id'] = 'user-1';
    storage['widget_snapshot_personal_EUR'] = 'previous';
    beforeCall = (call) async {
      if (call.method == 'saveWidgetData') {
        throw PlatformException(code: 'storage');
      }
    };
    await expectLater(
        WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => true),
        throwsA(isA<PlatformException>()));
    expect(storage['widget_snapshot_personal_EUR'], 'previous');
    expect(updates, isEmpty);
    beforeCall = null;
    expect(
        await WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => true),
        isTrue);
  });

  test('owner mismatch is deferred and expired publication is discarded',
      () async {
    storage['widget_user_id'] = 'user-2';
    expect(
        await WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => true),
        isFalse);
    storage['widget_user_id'] = 'user-1';
    expect(
        await WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => false),
        isFalse);
    expect(storage.keys, ['widget_user_id']);
  });

  test('queued stale owner transport cannot restore the previous account',
      () async {
    storage['widget_user_id'] = 'user-2';
    await WidgetService().synchronizeOwner('user-1', isCurrent: () => false);
    expect(storage['widget_user_id'], 'user-2');
    expect(updates, isEmpty);
  });

  test(
      'new publication serializes after older work and revokes old account on logout',
      () async {
    storage['widget_user_id'] = 'user-1';
    final blocked = Completer<void>();
    final started = Completer<void>();
    var first = true;
    beforeCall = (call) async {
      if (call.method == 'saveWidgetData' && first) {
        first = false;
        started.complete();
        await blocked.future;
      }
    };
    final old = WidgetService().publishSnapshot(
        scopeId: 'personal',
        snapshot: snapshot(spent: 100),
        isCurrent: () => true);
    await started.future;
    final newer = WidgetService().publishSnapshot(
        scopeId: 'personal',
        snapshot: snapshot(spent: 200),
        isCurrent: () => true);
    blocked.complete();
    await Future.wait([old, newer]);
    expect(
        jsonDecode(
            storage['widget_snapshot_personal_EUR'] as String)['totalSpent'],
        contains('200'));
    await WidgetService().synchronizeOwner('');
    expect(storage['widget_user_id'], '');
    expect(
        await WidgetService().publishSnapshot(
            scopeId: 'personal', snapshot: snapshot(), isCurrent: () => true),
        isFalse);
  });
}
