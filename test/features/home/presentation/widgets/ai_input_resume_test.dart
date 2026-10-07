import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/data/repositories/ai_input_capture_repository.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'owner@example.com');
  void changeUser() {
    state = const AppUser(uid: 'other', email: 'other@example.com');
  }
}

class _Store implements AppLockKeyValueStore {
  @override
  Future<void> delete(String key) async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Biometrics implements AppLockBiometricService {
  @override
  Future<bool> authenticate() async => false;
  @override
  Future<AppLockBiometricAvailability> getAvailability() async =>
      const AppLockBiometricAvailability.unavailable();
}

class _PausedDrainer extends MobileOutboxDrainer {
  _PausedDrainer()
      : super(() async => throw StateError('network disabled in fixture'));
  @override
  Future<int> drain({int maxMutations = 20}) async => 0;
}

Map<String, dynamic> _item(String currency, String wallet,
        {bool income = false}) =>
    {
      'type': income ? 'income' : 'expense',
      'amount': income ? 20 : 50,
      'category': income ? 'salary' : 'food',
      'currency': currency,
      'date': '2026-10-03',
      'description': income ? '給料' : '小商店で買い物',
      'merchant': '小商店',
      'merchant_id': 'merchant-id',
      'merchant_structured_name': '小商店',
      'breakdown': ['一品'],
      if (!income) 'transactionTime': '18:30:00',
      if (income) 'isRecurring': true,
      if (income)
        'recurrence_rule': {
          'frequency': 'monthly',
          'anchor_date': '2026-10-03',
          'interval': 1
        },
      'destination': {
        'householdId': null,
        'isPortfolio': false,
        'accountId': wallet,
        'accountCurrency': currency,
        'spaceLabel': 'Personal'
      },
    };

void main() {
  late Future<http.Response> Function(http.Request) requestHandler;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'anon',
        authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(), detectSessionInUri: false),
        httpClient: MockClient((request) => requestHandler(request)));
  });

  for (final scenario in [
    'cancel',
    'dismiss',
    'owner-change',
    'retryable',
    'offline'
  ]) {
    final cancel = scenario == 'cancel';
    testWidgets(
        'resumed analysis $scenario preserves durable capture ownership',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final root = Directory.systemTemp.createTempSync('moneko-ai-cancel-');
      final database = MonekoDatabase.inMemory();
      final repository =
          AiInputCaptureRepository(database, directory: () async => root);
      final capture = (await tester.runAsync(() => repository.capture(
          userId: 'owner',
          body: {'userId': 'owner', 'text': '買い物５０円'},
          target: {'accountType': 'personal'})))!;
      var requests = 0;
      requestHandler = (request) async {
        expect(request.url.path, '/functions/v1/analyze-expense');
        requests++;
        return http.Response(
            jsonEncode({'success': false}), scenario == 'retryable' ? 503 : 200,
            headers: {'content-type': 'application/json'});
      };
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(preferences),
        appUserContactProvider.overrideWithValue(null),
        localDatabaseProvider.overrideWith((ref) async => database),
        aiInputCaptureRepositoryProvider
            .overrideWith((ref) async => repository),
        networkReachabilityProvider
            .overrideWith((ref) => Stream.value(scenario != 'offline')),
        mobileOutboxDrainerProvider.overrideWith((ref) => _PausedDrainer()),
        appLockControllerProvider.overrideWith((ref) => AppLockController(
            userId: 'owner',
            repository: AppLockRepository(store: _Store()),
            hasher: AppLockPasscodeHasher(),
            biometricService: _Biometrics(),
            isEnabledFlagSet: false,
            setEnabledFlag: (_) async {})),
      ]);
      addTearDown(() async {
        container.dispose();
        await database.close();
        root.deleteSync(recursive: true);
      });
      late BuildContext mountedContext;
      late WidgetRef mountedRef;
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Consumer(builder: (context, ref, _) {
                mountedContext = context;
                mountedRef = ref;
                return const Scaffold(body: SizedBox());
              }))));
      await tester.pump();
      await container.read(networkReachabilityProvider.future);
      late Future<void> processing;
      await tester.runAsync(() async {
        processing = resumePendingAiInputs(mountedContext, mountedRef);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = AppLocalizations.of(mountedContext)!;
      final showsDialog = scenario != 'offline' && scenario != 'retryable';
      for (var attempt = 0;
          showsDialog &&
              attempt < 20 &&
              find.text(l10n.failedToAnalyze).evaluate().isEmpty;
          attempt++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (showsDialog) {
        expect(find.text(l10n.failedToAnalyze), findsOneWidget);
        if (scenario == 'owner-change') {
          (container.read(authProvider.notifier) as _Auth).changeUser();
          await tester.pump();
        }
        if (cancel || scenario == 'owner-change') {
          await tester.tap(find.text(l10n.cancel));
        } else {
          Navigator.of(mountedContext).pop();
        }
      } else {
        expect(find.text(l10n.failedToAnalyze), findsNothing);
      }
      await tester.runAsync(() => processing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, scenario == 'offline' ? 0 : 1);
      final pending = await repository.pending('owner');
      expect(pending, cancel ? isEmpty : hasLength(1));
      expect((await database.getOutboxMutations()).single.status,
          cancel ? localMutationStatusCancelled : 'awaiting_ai');
      expect(
          await database.getRecentTransactions(
              userId: 'owner', householdId: null),
          isEmpty);
      if (cancel) {
        container.read(aiInputResumeControllerProvider).wake();
        await tester
            .runAsync(() => resumePendingAiInputs(mountedContext, mountedRef));
        expect(requests, 1);
      } else {
        expect(pending.single.id, capture.id);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final interactive in [true, false]) {
    for (final marker in [true, false, null]) {
      testWidgets(
          'resumed ready result interactive=$interactive blocker=$marker uses the Home save contract and cannot materialize twice',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final root = Directory.systemTemp.createTempSync('moneko-ai-resume-');
        var database = MonekoDatabase.fromExistingDatabaseForTesting(
            sqlite.sqlite3.open('${root.path}/capture.sqlite'));
        var repository =
            AiInputCaptureRepository(database, directory: () async => root);
        final capturedAt = DateTime.utc(2026, 10, 2, 23, 30);
        var capture = (await tester.runAsync(() => repository.capture(
            userId: 'owner',
            body: {
              'userId': 'owner',
              'text': '買い物５０円、給料２０ドル',
              'date': '2026-10-03',
              'currency': 'JPY'
            },
            target: {'accountType': 'personal'},
            preferredTimezone: 'Asia/Tokyo',
            capturedAt: capturedAt,
            isOnboarding: true)))!;
        final items = [
          _item('JPY', 'jpy-wallet'),
          _item('USD', 'usd-wallet', income: true)
        ];
        for (final item in items) {
          if (marker != null) item['merchant_auto_resolution_blocked'] = marker;
        }
        capture = await repository.checkpoint(capture, {
          'readyResponse': {
            'success': true,
            'data': {
              if (interactive) 'interactiveVersion': 1,
              'requireCorrection': false,
              'preferredTimezone': 'Asia/Tokyo',
              'items': items
            }
          },
          'destinationKeys': !interactive
              ? ['default']
              : items
                  .map((item) => jsonEncode([
                        null,
                        false,
                        (item['destination'] as Map)['accountId'],
                        (item['destination'] as Map)['accountCurrency']
                      ]))
                  .toList(),
          'completedDestinations': <String>[],
        });
        await database.close();
        database = MonekoDatabase.fromExistingDatabaseForTesting(
            sqlite.sqlite3.open('${root.path}/capture.sqlite'));
        repository =
            AiInputCaptureRepository(database, directory: () async => root);
        expect((await repository.pending('owner')).single.readyResponse,
            capture.readyResponse);
        final container = ProviderContainer(overrides: [
          authProvider.overrideWith(_Auth.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          appUserContactProvider.overrideWithValue(null),
          localDatabaseProvider.overrideWith((ref) async => database),
          aiInputCaptureRepositoryProvider
              .overrideWith((ref) async => repository),
          networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
          mobileOutboxDrainerProvider.overrideWith((ref) => _PausedDrainer()),
          appLockControllerProvider.overrideWith((ref) => AppLockController(
              userId: 'owner',
              repository: AppLockRepository(store: _Store()),
              hasher: AppLockPasscodeHasher(),
              biometricService: _Biometrics(),
              isEnabledFlagSet: false,
              setEnabledFlag: (_) async {})),
        ]);
        addTearDown(() async {
          container.dispose();
          await database.close();
          root.deleteSync(recursive: true);
        });
        late BuildContext mountedContext;
        late WidgetRef mountedRef;
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Consumer(builder: (context, ref, _) {
                  mountedContext = context;
                  mountedRef = ref;
                  return const Scaffold(body: SizedBox());
                }))));
        await tester.pump();
        await tester
            .runAsync(() => resumePendingAiInputs(mountedContext, mountedRef));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(await repository.pending('owner'), isEmpty);
        final rows = await database.getRecentTransactions(
            userId: 'owner', householdId: null);
        expect(rows, hasLength(2));
        final expense = rows.singleWhere((row) => row.type == 'expense');
        expect(expense.walletId, interactive ? 'jpy-wallet' : null);
        expect(expense.currency, 'JPY');
        expect(expense.merchant, '小商店');
        expect(
            expense.createdAt.toUtc(),
            interactive
                ? DateTime.utc(2026, 10, 3, 9, 30)
                : DateTime(2026, 10, 3, 18, 30).toUtc());
        final mutations = (await database.getOutboxMutations())
            .where((row) => row.entityType == 'transaction')
            .toList();
        expect(mutations, hasLength(2));
        final requests =
            mutations.map((row) => jsonDecode(row.payloadJson) as Map).toList();
        final expenseRequest = requests.singleWhere(
                (row) => row['functionName'] == 'save-expense')['requestBody']
            as Map;
        expect(expenseRequest['merchant'], '小商店');
        expect(expenseRequest['merchantId'], 'merchant-id');
        expect(expenseRequest['merchantStructuredName'], '小商店');
        expect(expenseRequest.containsKey('merchantAutoResolutionBlocked'),
            marker == true);
        if (marker == true) {
          expect(expenseRequest['merchantAutoResolutionBlocked'], true);
        }
        expect(expenseRequest['breakdown'], ['一品']);
        final incomeRequest = requests.singleWhere(
                (row) => row['functionName'] == 'save-income')['requestBody']
            as Map;
        expect(incomeRequest['currency'], 'USD');
        expect(incomeRequest['accountId'], interactive ? 'usd-wallet' : null);
        expect(incomeRequest.containsKey('merchantAutoResolutionBlocked'),
            marker == true);
        if (marker == true) {
          expect(incomeRequest['merchantAutoResolutionBlocked'], true);
        }
        expect(incomeRequest['isRecurring'], true);
        expect(incomeRequest['recurrence_rule'], {
          'frequency': 'monthly',
          'anchor_date': '2026-10-03',
          'interval': 1
        });
        expect(incomeRequest['clientCreatedAt'], capturedAt.toIso8601String());
        expect(
            requests.every((row) => row['aiCaptureId'] == capture.id), isTrue);
        expect(container.read(transactionsFeedRefreshSignalProvider),
            greaterThan(0));
        expect(container.read(dashboardRefreshSignalProvider), greaterThan(0));
        container.read(aiInputResumeControllerProvider).wake();
        await tester
            .runAsync(() => resumePendingAiInputs(mountedContext, mountedRef));
        expect(
            await database.getRecentTransactions(
                userId: 'owner', householdId: null),
            hasLength(2));
        (container.read(authProvider.notifier) as _Auth).changeUser();
        await tester
            .runAsync(() => resumePendingAiInputs(mountedContext, mountedRef));
        expect(
            await database.getRecentTransactions(
                userId: 'other', householdId: null),
            isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
