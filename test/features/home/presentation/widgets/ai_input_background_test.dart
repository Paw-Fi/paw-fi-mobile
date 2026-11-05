import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/data/repositories/ai_input_capture_repository.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart'
    show sharedPreferencesProvider;
import 'package:moneko/features/home/presentation/services/ai_background_execution.dart';
import 'package:moneko/features/home/presentation/widgets/ai_correction_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/privacy/data/ai_processing_consent_repository.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'test@example.com');
}

class _Repository extends Mock implements AppLockRepository {}

class _Hasher extends Mock implements AppLockPasscodeHasher {}

class _Biometrics extends Mock implements AppLockBiometricService {}

class _Lock extends AppLockController {
  _Lock()
      : super(
            userId: 'owner',
            repository: _Repository(),
            hasher: _Hasher(),
            biometricService: _Biometrics(),
            isEnabledFlagSet: false,
            setEnabledFlag: (_) async {});
}

class _Drainer extends MobileOutboxDrainer {
  _Drainer()
      : super(() async => throw StateError('fixture is offline for saves'));
  @override
  Future<int> drain({int maxMutations = 20}) async => 0;
}

class _Bridge extends AiExecutionBridge {
  final events = StreamController<String>.broadcast(sync: true);
  final stops = StreamController<String>.broadcast(sync: true);
  final journal = <Map<String, dynamic>>[];
  final failures = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> pendingFailures() async =>
      List.of(failures);
  @override
  Future<void> acknowledgeFailure(String id) async =>
      failures.removeWhere((s) => s['id'] == id);
  @override
  Stream<String> get stopped => stops.stream;
  @override
  Future<List<Map<String, dynamic>>> pendingStops() async => List.of(journal);
  @override
  Future<void> acknowledgeStop(String id) async =>
      journal.removeWhere((s) => s['id'] == id);
  final calls = <Map<String, dynamic>>[];
  bool granted = true;
  @override
  Stream<String> get expired => events.stream;
  @override
  Future<bool> start(Map<String, dynamic> payload) async {
    calls.add({'method': 'start', ...payload});
    return granted;
  }

  @override
  Future<void> update(Map<String, dynamic> payload) async =>
      calls.add({'method': 'update', ...payload});
  @override
  Future<void> finish(Map<String, dynamic> payload) async =>
      calls.add({'method': 'finish', ...payload});
  @override
  Future<void> dispose() async {
    await events.close();
    await stops.close();
  }
}

Map<String, dynamic> _ready() => {
      'success': true,
      'data': {
        'interactiveVersion': 1,
        'requireCorrection': false,
        'items': [
          {
            'type': 'expense',
            'amount': 12.5,
            'category': 'food',
            'currency': 'EUR',
            'date': '2026-11-04',
            'description': '昼食',
            'merchant': 'Café',
            'destination': {
              'householdId': null,
              'isPortfolio': false,
              'accountId': null,
              'accountCurrency': null,
              'spaceLabel': 'Personal'
            },
          }
        ],
      },
    };

void _foreground(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  late Future<http.Response> Function(http.Request) handler;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'test',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false),
        httpClient: MockClient((request) => handler(request)));
  });

  for (final scenario in [
    'background',
    'lock',
    'clarification',
    'locked-clarification',
    'expired',
    'stopped',
    'missed-stop',
    'tap-confirmation',
    'tap-confirmation-submit',
    'tap-error',
    'tap-error-offline',
    'missed-failure',
    'denied',
    'actor',
    'consent',
    'disposed-page'
  ]) {
    testWidgets(
        'analysis $scenario respects native execution and durable ownership',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final consent =
          SharedPreferencesAiProcessingConsentRepository(() => prefs);
      await consent.setConsent('owner', true);
      final root = Directory.systemTemp.createTempSync('moneko-background-');
      final database = MonekoDatabase.inMemory();
      final repository =
          AiInputCaptureRepository(database, directory: () async => root);
      final bridge = _Bridge()..granted = scenario != 'denied';
      final lock = _Lock();
      final opensAttention =
          scenario.startsWith('tap-') || scenario == 'missed-failure';
      if (opensAttention) {
        final older = (await tester.runAsync(() => repository.capture(
            userId: 'owner',
            body: {'userId': 'owner', 'text': 'older input'},
            target: {'accountType': 'personal'})))!;
        await repository.checkpoint(older, {
          'question': {
            'question': 'Older question',
            'choices': ['A', 'B'],
            'allowCustomResponse': true,
          }
        });
      }
      var capture = (await tester.runAsync(() => repository.capture(
          userId: 'owner',
          body: {'userId': 'owner', 'text': '昼食に１２，５０ユーロ'},
          target: {'accountType': 'personal'})))!;
      if (scenario == 'missed-stop') {
        capture =
            await repository.checkpoint(capture, {'executionId': 'last-run'});
        bridge.journal.add(
            {'id': 'last-run', 'userId': 'owner', 'captureId': capture.id});
      }
      if (opensAttention) {
        capture = await repository.checkpoint(capture, {
          'executionId': '${capture.id}:1:1',
          if (scenario.startsWith('tap-confirmation'))
            'question': {
              'question': 'どの通貨ですか？',
              'choices': ['EUR', 'JPY'],
              'allowCustomResponse': true,
            },
          if (scenario.startsWith('tap-error')) 'requiresAnalysisRetry': true,
        });
        if (scenario == 'missed-failure') {
          bridge.failures.add({
            'id': '${capture.id}:1:1',
            'captureId': capture.id,
            'userId': 'owner',
          });
        }
      }
      late Completer<http.Response> response;
      late Completer<void> requested;
      await tester.runAsync(() async {
        response = Completer();
        requested = Completer();
      });
      handler = (request) async {
        expect(request.url.path, '/functions/v1/analyze-expense');
        expect((jsonDecode(request.body) as Map)['text'], '昼食に１２，５０ユーロ');
        if (!requested.isCompleted) requested.complete();
        return response.future;
      };
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appUserContactProvider.overrideWithValue(null),
        localDatabaseProvider.overrideWith((ref) async => database),
        aiInputCaptureRepositoryProvider
            .overrideWith((ref) async => repository),
        networkReachabilityProvider.overrideWith(
            (ref) => Stream.value(scenario != 'tap-error-offline')),
        mobileOutboxDrainerProvider.overrideWith((ref) => _Drainer()),
        appLockControllerProvider.overrideWith((ref) => lock),
        aiExecutionBridgeProvider.overrideWithValue(bridge),
      ]);
      addTearDown(() async {
        container.dispose();
        await database.close();
        root.deleteSync(recursive: true);
      });
      late BuildContext inputContext;
      late WidgetRef inputRef;
      _foreground(tester);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(child: Consumer(builder: (context, ref, _) {
            inputContext = context;
            inputRef = ref;
            return const Scaffold(body: Text('Input'));
          })),
        ),
      ));
      await tester.pump();
      late Future<void> running;
      if (opensAttention) {
        final links = DeepLinkService();
        links.handleDeepLinkUri(
            Uri(scheme: 'moneko', host: 'ai-analysis', queryParameters: {
              'captureId': capture.id,
              'userId': 'owner',
              'executionId': '${capture.id}:1:1',
            }),
            inputRef);
        lock.state = const AppLockState(status: AppLockStatus.locked);
        await tester
            .runAsync(() => resumePendingAiInputs(inputContext, inputRef));
        await tester.pumpAndSettle();
        expect(find.byType(AiCorrectionSheet), findsNothing);
        expect(find.text('Retry'), findsNothing);
        lock.state = const AppLockState.disabled();
        await tester.runAsync(() async {
          running = resumePendingAiInputs(inputContext, inputRef);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(requested.isCompleted, isFalse);
        expect(find.text('Older question'), findsNothing);
        if (scenario.startsWith('tap-confirmation')) {
          expect(find.byType(AiCorrectionSheet), findsOneWidget);
          expect(find.text('どの通貨ですか？'), findsOneWidget);
          expect(
              bridge.calls.firstWhere((c) => c['method'] == 'start')['outcome'],
              'needsInput');
        } else {
          expect(find.text('Retry'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
          expect(
              bridge.calls.firstWhere((c) => c['method'] == 'start')['outcome'],
              'error');
        }
        if (scenario == 'tap-confirmation-submit') {
          await tester.ensureVisible(find.text('EUR'));
          await tester.tap(find.text('EUR'));
          await tester.pump();
          await tester.runAsync(() async {
            await requested.future.timeout(const Duration(seconds: 5));
            expect(
                bridge.calls
                    .lastWhere((c) => c['method'] == 'start')['outcome'],
                isNull);
            response.complete(http.Response(jsonEncode(_ready()), 200,
                headers: {'content-type': 'application/json'}));
            await running;
          });
          expect(
              await database.getRecentTransactions(
                  userId: 'owner', householdId: null),
              hasLength(1));
          expect(
              (await repository.pending('owner')).single.payload['question']
                  ['question'],
              'Older question');
          expect(bridge.calls.last['outcome'], 'queued');
          links.dispose();
          await tester.pump(const Duration(seconds: 8));
          await tester.pumpWidget(const SizedBox());
          return;
        }
        rootNavigatorKey.currentState!.pop();
        await tester.runAsync(() => running);
        expect(requested.isCompleted, isFalse);
        expect(await repository.pending('owner'), hasLength(2));
        expect(bridge.failures, isEmpty);
        expect(container.read(aiInputOpenRequestProvider), isNull);
        expect(tester.takeException(), isNull);
        links.dispose();
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpWidget(const SizedBox());
        return;
      }
      await tester.runAsync(() async {
        running = resumePendingAiInputs(inputContext, inputRef);
        if (scenario == 'missed-stop') {
          await running;
        } else {
          await requested.future;
        }
      });
      final attemptId = scenario == 'missed-stop'
          ? 'last-run'
          : bridge.calls.firstWhere((call) => call['method'] == 'start')['id']
              as String;
      if (scenario == 'disposed-page') {
        unawaited(rootNavigatorKey.currentState!.pushReplacement(
            MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Other page')))));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      if (scenario == 'lock' || scenario == 'locked-clarification') {
        lock.state = const AppLockState(status: AppLockStatus.locked);
      }
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      if (scenario == 'locked-clarification') _foreground(tester);
      if (scenario == 'expired') bridge.events.add(attemptId);
      if (scenario == 'stopped') {
        bridge.journal
            .add({'id': attemptId, 'userId': 'owner', 'captureId': capture.id});
        bridge.stops.add(attemptId);
      }
      if (scenario == 'actor') {
        container.read(authProvider.notifier).state =
            const AppUser(uid: 'other', email: 'other@example.com');
      }
      if (scenario == 'consent') {
        await consent.setConsent('owner', false);
        await tester.runAsync(() =>
            container.read(aiProcessingConsentProvider.notifier).refresh());
      }
      final payload = scenario.endsWith('clarification')
          ? {
              'success': true,
              'data': {
                'interactiveVersion': 1,
                'requireCorrection': true,
                'items': [],
                'correction': {
                  'question': 'どの通貨ですか？',
                  'choices': ['EUR', 'JPY'],
                  'allowCustomResponse': true
                }
              },
            }
          : _ready();
      await tester.runAsync(() async {
        response.complete(http.Response(jsonEncode(payload), 200,
            headers: {'content-type': 'application/json'}));
        await running;
      });
      await tester.pump();
      final shouldSave =
          ['background', 'lock', 'disposed-page'].contains(scenario);
      expect(
          await database.getRecentTransactions(
              userId: 'owner', householdId: null),
          hasLength(shouldSave ? 1 : 0));
      final pending = await repository.pending('owner');
      if (scenario == 'expired') {
        expect(pending.single.payload['requiresAnalysisRetry'], isTrue);
        expect(bridge.calls.last['outcome'], 'error');
      }
      expect(
          pending,
          hasLength(shouldSave || ['stopped', 'missed-stop'].contains(scenario)
              ? 0
              : 1));
      if (['stopped', 'missed-stop'].contains(scenario)) {
        expect(bridge.journal, isEmpty);
        expect((await database.getOutboxMutations()).single.status,
            localMutationStatusCancelled);
      }
      if (scenario == 'missed-stop') {
        expect(requested.isCompleted, isFalse);
        expect(
            bridge.calls.where((call) => call['method'] == 'start'), isEmpty);
      }
      if (scenario.endsWith('clarification')) {
        expect(pending.single.payload['question']['question'], 'どの通貨ですか？');
        expect(find.byType(AiCorrectionSheet), findsNothing);
        expect(bridge.calls.where((call) => call['outcome'] == 'needsInput'),
            isNotEmpty);
      }
      if (scenario == 'locked-clarification') {
        lock.state = const AppLockState.disabled();
        await tester.pump();
        await tester.runAsync(() async {
          running = resumePendingAiInputs(inputContext, inputRef);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(find.byType(AiCorrectionSheet), findsOneWidget);
        rootNavigatorKey.currentState!.pop();
        await tester.runAsync(() => running);
      }
      if (shouldSave) {
        final outbox = await database.getOutboxMutations();
        expect(outbox.where((row) => row.entityType == 'transaction'),
            hasLength(1));
        expect(
            jsonDecode(outbox
                .singleWhere((row) => row.entityType == 'transaction')
                .payloadJson)['aiCaptureId'],
            capture.id);
        expect(bridge.calls.last['outcome'], 'queued');
        expect(bridge.calls.last['background'], isTrue);
      }
      expect(tester.takeException(), isNull);
      _foreground(tester);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
