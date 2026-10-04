import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/notifications/notification_badge_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app_badge_plus');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('$platform clears the native badge to zero', () async {
      debugDefaultTargetPlatformOverride = platform;
      await NotificationBadgeService().clear();
      expect(calls.single.method, 'updateBadge');
      expect(calls.single.arguments, {'count': 0});
    });
  }

  test('clears a cold launch that is already resumed', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final service = NotificationBadgeService()..start();
    addTearDown(service.dispose);
    await pumpEventQueue();
    expect(calls, hasLength(1));
  });

  test('waits for foreground launch and clears again on each resume', () async {
    final service = NotificationBadgeService()..start();
    addTearDown(service.dispose);
    await pumpEventQueue();
    expect(calls, isEmpty);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(calls, hasLength(1));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(calls, hasLength(1));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(calls, hasLength(2));
  });

  test('duplicate startup does not attach duplicate listeners', () async {
    final service = NotificationBadgeService()
      ..start()
      ..start();
    addTearDown(service.dispose);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(calls, hasLength(1));
  });

  test('provider disposal removes the lifecycle listener', () async {
    final container = ProviderContainer();
    container.read(notificationBadgeServiceProvider).start();
    container.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  test('plugin errors are contained and the next clear retries', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      if (calls.length == 1) throw PlatformException(code: 'unavailable');
      return null;
    });
    final service = NotificationBadgeService();
    await service.clear();
    await service.clear();
    expect(calls, hasLength(2));
  });

  test('missing plugin does not interrupt notification handling', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await NotificationBadgeService().clear();
  });

  test('desktop platforms do not invoke the mobile badge plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await NotificationBadgeService().clear();
    expect(calls, isEmpty);
  });
}
