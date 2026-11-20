import 'dart:async';
import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as tests;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/profile/presentation/pages/android_notification_capture_page.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _actor = '11111111-1111-4111-8111-111111111111';
const _otherActor = '22222222-2222-4222-8222-222222222222';
const _captureChannel = MethodChannel('moneko/notification_capture');
const _permissionChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: _actor, email: 'capture@example.test');
}

class _PlusSubscription extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => Subscription(
        id: 'plus',
        userId: _actor,
        plan: 'lifetime',
        status: 'active',
        createdAt: DateTime(2026),
      );
}

class _HouseholdRepository extends Mock implements HouseholdRepository {}

Map<String, dynamic> _session(String actor) => {
      'access_token': 'header.${base64Url.encode(utf8.encode(jsonEncode({
                'sub': actor,
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
              }))).replaceAll('=', '')}.signature',
      'refresh_token': 'refresh-$actor',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': actor,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-01T00:00:00Z',
      },
    };

class _CaptureFixture {
  bool access = false;
  bool nativeEnabled = false;
  bool failSettingsLaunch = false;
  int saveStatus = 200;
  int settingsLaunches = 0;
  int accessChecks = 0;
  int contactReads = 0;
  final nativeEnableWrites = <Map<Object?, Object?>>[];
  final nativeCalls = <String>[];
  final saves = <http.Request>[];
  final unexpectedRequests = <Uri>[];
  Completer<void>? saveRelease;
  Completer<void>? accessCheckRelease;
  Completer<void>? enableWriteRelease;

  Future<Object?> native(MethodCall call) async {
    nativeCalls.add(call.method);
    switch (call.method) {
      case 'getConfig':
        return {
          'enabled': nativeEnabled,
          'scopeId': 'personal',
          'scopeName': 'Personal',
          'hasAuthStorage': true,
          'hasCredentials': true,
          'isReady': true,
          'hasNotificationAccess': access,
          'enabledPackages': ['test.bank'],
          'recentApps': [
            {
              'packageName': 'test.bank',
              'appLabel': 'Test Bank',
              'enabled': true
            },
          ],
        };
      case 'checkNotificationAccess':
        accessChecks++;
        final observedAccess = access;
        await accessCheckRelease?.future;
        return observedAccess;
      case 'getRecentApps':
        return [
          {
            'packageName': 'test.bank',
            'appLabel': 'Test Bank',
            'enabled': true
          },
        ];
      case 'setConfig':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        if (args['enabled'] is bool) {
          nativeEnabled = args['enabled'] as bool;
          if (nativeEnabled) nativeEnableWrites.add(args);
          if (nativeEnabled) await enableWriteRelease?.future;
        }
        return null;
      case 'openNotificationSettings':
        settingsLaunches++;
        if (failSettingsLaunch) {
          throw PlatformException(code: 'settings_unavailable');
        }
        return null;
      case 'syncAuthContext':
      case 'clearAuthContext':
        return null;
      case 'syncPendingCaptures':
      case 'getPendingCaptureStatus':
        return <String, Object?>{};
      default:
        throw MissingPluginException(
            'Unexpected capture method ${call.method}');
    }
  }

  Future<http.Response> request(http.Request request) async {
    const headers = {'content-type': 'application/json'};
    if (request.url.path == '/rest/v1/user_contacts') {
      contactReads++;
      return http.Response(
        jsonEncode([
          {'id': 'contact', 'wallet_capture_enabled': false}
        ]),
        200,
        headers: headers,
        request: request,
      );
    }
    if (request.url.path == '/functions/v1/update-wallet-capture-setting') {
      saves.add(request);
      await saveRelease?.future;
      return http.Response('{"contactId":"contact"}', saveStatus,
          headers: headers, request: request);
    }
    unexpectedRequests.add(request.url);
    return http.Response('{}', 500, headers: headers, request: request);
  }

  Future<void> mount(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_Auth.new),
        subscriptionNotifierProvider.overrideWith(_PlusSubscription.new),
        for (final actor in [_actor, _otherActor])
          userHouseholdsProvider(actor).overrideWith((ref) =>
              UserHouseholdsNotifier(_HouseholdRepository(), actor, ref,
                  initialHouseholds: [])),
        walletsByHouseholdIdProvider(null).overrideWith((ref) async => []),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AndroidNotificationCapturePage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(contactReads, 1,
        reason: 'The real page must finish its remote read.');
    expect(nativeCalls, contains('setConfig'));
    expect(tester.widget<AdaptiveSwitch>(captureSwitch).value, isFalse);
    expect(saves, isEmpty);
    expect(tester.takeException(), isNull);
  }

  Finder get captureSwitch => find.byType(AdaptiveSwitch).first;

  // FunctionsClient encodes/decodes JSON on a real isolate; fake-clock pumps
  // alone can settle before the HTTP request has even been dispatched.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapEnable(WidgetTester tester) async {
    await tester.ensureVisible(captureSwitch);
    await tester.pumpAndSettle();
    await tester.tap(captureSwitch);
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  }

  void expectDisabled(WidgetTester tester) {
    expect(saves, isEmpty);
    expect(nativeEnableWrites, isEmpty);
    expect(nativeEnabled, isFalse);
    expect(tester.widget<AdaptiveSwitch>(captureSwitch).value, isFalse);
  }

  void expectEnabledOnce(WidgetTester tester) {
    expect(saves, hasLength(1),
        reason: 'Granting access must complete the original enable intent. '
            'Native calls: $nativeCalls; unexpected HTTP: $unexpectedRequests');
    expect(jsonDecode(saves.single.body), {'enabled': true});
    expect(saves.single.method.toUpperCase(), 'POST');
    expect(saves.single.headers['Authorization'],
        'Bearer ${Supabase.instance.client.auth.currentSession!.accessToken}');
    expect(nativeEnableWrites, hasLength(1));
    expect(nativeEnabled, isTrue);
    expect(tester.widget<AdaptiveSwitch>(captureSwitch).value, isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _CaptureFixture fixture;

  void testWidgets(String name, WidgetTesterCallback body) {
    tests.testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput: 'SUPABASE_URL=https://capture.test\n'
            'SUPABASE_ANON_KEY=test-anon');
    fixture = _CaptureFixture();
    messenger.setMockMethodCallHandler(_captureChannel, fixture.native);
    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      if (call.method == 'checkPermissionStatus') return 1;
      throw MissingPluginException(
          'Unexpected permission method ${call.method}');
    });
    await Supabase.initialize(
      url: 'https://capture.test',
      anonKey: 'test-anon',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(fixture.request),
    );
    await Supabase.instance.client.auth
        .recoverSession(jsonEncode(_session(_actor)));
    NotificationCaptureService.instance.initializeSessionBridge(
        authReady: () async => Supabase.instance.client.auth);
  });

  tearDown(() async {
    fixture.saveRelease?.complete();
    expect(fixture.unexpectedRequests, isEmpty);
    await Supabase.instance.dispose();
    messenger.setMockMethodCallHandler(_captureChannel, null);
    messenger.setMockMethodCallHandler(_permissionChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('already granted access enables capture with one save',
      (tester) async {
    fixture.access = true;
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 0);
    fixture.expectEnabledOnce(tester);
  });

  testWidgets(
      'grant on return completes Enable Auto Capture without a second tap',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    fixture.expectDisabled(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    expect(fixture.accessChecks, greaterThan(1));
    fixture.expectEnabledOnce(tester);
  });

  testWidgets(
      'denied return consumes intent and unrelated resume cannot enable',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    await fixture.leave(tester);
    await fixture.resume(tester);
    fixture.expectDisabled(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    fixture.expectDisabled(tester);
    // A fresh explicit action must still work after the denied attempt.
    await fixture.tapEnable(tester);
    fixture.expectEnabledOnce(tester);
  });

  testWidgets(
      'repeated resume while enable save is pending sends only one save',
      (tester) async {
    fixture.saveRelease = Completer<void>();
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    await fixture.leave(tester);
    await fixture.resume(tester);
    fixture.saveRelease!.complete();
    fixture.saveRelease = null;
    await fixture.settle(tester);
    await fixture.leave(tester);
    await fixture.resume(tester);
    fixture.expectEnabledOnce(tester);
  });

  testWidgets('standalone Grant Access does not create an enable intent',
      (tester) async {
    await fixture.mount(tester);
    final grant = find.widgetWithText(ElevatedButton, 'Grant Access');
    await tester.ensureVisible(grant);
    await tester.pumpAndSettle();
    await tester.tap(grant);
    await tester.pumpAndSettle();
    expect(fixture.settingsLaunches, 1);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    fixture.expectDisabled(tester);
  });

  testWidgets('leaving during native enable still finishes the remote save',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    await fixture.leave(tester);
    fixture.enableWriteRelease = Completer<void>();
    fixture.access = true;
    await fixture.resume(tester);
    expect(fixture.nativeEnableWrites, hasLength(1));
    expect(fixture.saves, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.enableWriteRelease!.complete();
    fixture.enableWriteRelease = null;
    await fixture.settle(tester);
    expect(fixture.saves, hasLength(1));
    expect(fixture.nativeEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'leaving during remote enable does not roll back a successful save',
      (tester) async {
    fixture.saveRelease = Completer<void>();
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    expect(fixture.saves, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.saveRelease!.complete();
    fixture.saveRelease = null;
    await fixture.settle(tester);
    expect(fixture.nativeEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected automatic enable restores the disabled setting',
      (tester) async {
    fixture.saveStatus = 403;
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    expect(fixture.saves, hasLength(1));
    expect(fixture.nativeEnabled, isFalse);
    expect(tester.widget<AdaptiveSwitch>(fixture.captureSwitch).value, isFalse);
    await fixture.leave(tester);
    await fixture.resume(tester);
    expect(fixture.saves, hasLength(1));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  testWidgets('started enable retains its original actor after page dismissal',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    await fixture.leave(tester);
    fixture.enableWriteRelease = Completer<void>();
    fixture.access = true;
    final originalToken =
        Supabase.instance.client.auth.currentSession!.accessToken;
    await fixture.resume(tester);
    expect(fixture.nativeEnableWrites, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.auth
        .recoverSession(jsonEncode(_session(_otherActor))));
    fixture.enableWriteRelease!.complete();
    fixture.enableWriteRelease = null;
    await fixture.settle(tester);
    expect(fixture.saves, hasLength(1));
    expect(
        fixture.saves.single.headers['Authorization'], 'Bearer $originalToken');
    expect(tester.takeException(), isNull);
  });

  for (final granted in [true, false]) {
    testWidgets('settings return queues behind an earlier recheck: $granted',
        (tester) async {
      await fixture.mount(tester);
      // An ordinary resume's access read is delayed before the user starts setup.
      fixture.accessCheckRelease = Completer<void>();
      await fixture.leave(tester);
      await fixture.resume(tester);
      await fixture.tapEnable(tester);
      await fixture.leave(tester);
      fixture.access = granted;
      await fixture.resume(tester);
      fixture.accessCheckRelease!.complete();
      fixture.accessCheckRelease = null;
      await fixture.settle(tester);
      if (granted) {
        fixture.expectEnabledOnce(tester);
      } else {
        fixture.expectDisabled(tester);
        await fixture.leave(tester);
        fixture.access = true;
        await fixture.resume(tester);
        fixture.expectDisabled(tester);
      }
    });
  }

  testWidgets('new actor enable survives the previous actor delayed recheck',
      (tester) async {
    await fixture.mount(tester);
    fixture.accessCheckRelease = Completer<void>();
    await fixture.leave(tester);
    await fixture.resume(tester);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AndroidNotificationCapturePage)));
    await tester.runAsync(() => Supabase.instance.client.auth
        .recoverSession(jsonEncode(_session(_otherActor))));
    container.read(authProvider.notifier).state =
        const AppUser(uid: _otherActor, email: 'other@example.test');
    await tester.pumpAndSettle();
    await fixture.tapEnable(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    fixture.accessCheckRelease!.complete();
    fixture.accessCheckRelease = null;
    await fixture.settle(tester);
    fixture.expectEnabledOnce(tester);
  });

  testWidgets('disposed page cannot finish a stale enable intent',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    await fixture.leave(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.access = true;
    await fixture.resume(tester);
    expect(fixture.saves, isEmpty);
    expect(fixture.nativeEnableWrites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account switch cancels the previous actor enable intent',
      (tester) async {
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    await fixture.leave(tester);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AndroidNotificationCapturePage)));
    await tester.runAsync(() => Supabase.instance.client.auth
        .recoverSession(jsonEncode(_session(_otherActor))));
    container.read(authProvider.notifier).state =
        const AppUser(uid: _otherActor, email: 'other@example.test');
    await tester.pumpAndSettle();
    fixture.access = true;
    await fixture.resume(tester);
    fixture.expectDisabled(tester);
  });

  testWidgets('settings launch failure cancels intent before a later resume',
      (tester) async {
    fixture.failSettingsLaunch = true;
    await fixture.mount(tester);
    await fixture.tapEnable(tester);
    expect(fixture.settingsLaunches, 1);
    fixture.expectDisabled(tester);
    await fixture.leave(tester);
    fixture.access = true;
    await fixture.resume(tester);
    fixture.expectDisabled(tester);
    // Drain the error toast animation before widget-test teardown.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });
}
