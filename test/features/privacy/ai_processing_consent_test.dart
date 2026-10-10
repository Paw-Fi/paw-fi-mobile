import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/privacy/data/ai_processing_consent_repository.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_dialog.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/features/auth/auth.dart';

class MockPreferences extends Mock implements SharedPreferences {}

class FakeConsentRepository implements AiProcessingConsentRepository {
  Future<Object?> Function() read = () async => consent(false);
  Future<Object?> Function(bool) write = (granted) async => consent(granted);
  int writes = 0;

  @override
  Future<Object?> getConsent(String userId) => read();

  @override
  Future<Object?> setConsent(String userId, bool granted) {
    writes++;
    return write(granted);
  }
}

Map<String, Object?> consent(bool granted,
        {String owner = 'A', String? version}) =>
    {
      'user_id': owner,
      'granted': granted,
      'disclosure_version': version ?? aiProcessingDisclosureVersion,
      'granted_at': granted ? '2026-10-10T12:00:00Z' : null,
      'revoked_at': granted ? null : '2026-10-10T13:00:00Z',
    };

class TestConsentAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'A', email: 'a@example.com');

  void setUser(String userId) => state = AppUser(uid: userId, email: '');
}

void main() {
  late FakeConsentRepository repository;
  late ProviderContainer container;

  void setActor(String userId) =>
      (container.read(authProvider.notifier) as TestConsentAuth)
          .setUser(userId);

  setUp(() {
    repository = FakeConsentRepository();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
      aiConsentSavingDelayProvider.overrideWithValue(() async {}),
    ]);
    container.listen(aiProcessingConsentProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  Future<SharedPreferences> useLocalPreferences({bool mockDelay = true}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container.dispose();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      sharedPreferencesProvider.overrideWithValue(preferences),
      if (mockDelay)
        aiConsentSavingDelayProvider.overrideWithValue(() async {}),
    ]);
    container.listen(aiProcessingConsentProvider, (_, __) {});
    return preferences;
  }

  test(
      'local consent persists version and timestamps across containers per account',
      () async {
    final preferences = await useLocalPreferences();
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    expect(await notifier.setGranted(true), isTrue);
    final key = SharedPreferencesAiProcessingConsentRepository.storageKey('A');
    final stored = jsonDecode(preferences.getString(key)!) as Map;
    expect(stored['user_id'], 'A');
    expect(stored['disclosure_version'], aiProcessingDisclosureVersion);
    expect(DateTime.tryParse(stored['granted_at'] as String), isNotNull);
    expect(stored['revoked_at'], isNull);

    container.dispose();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      sharedPreferencesProvider.overrideWithValue(preferences),
      aiConsentSavingDelayProvider.overrideWithValue(() async {}),
    ]);
    container.listen(aiProcessingConsentProvider, (_, __) {});
    expect(await container.read(aiProcessingConsentProvider.notifier).refresh(),
        isTrue);
    setActor('B');
    expect(await container.read(aiProcessingConsentProvider.notifier).refresh(),
        isFalse);
    setActor('A');
    final restored = container.read(aiProcessingConsentProvider.notifier);
    expect(await restored.refresh(), isTrue);
    expect(await restored.setGranted(false), isTrue);
    final revoked = jsonDecode(preferences.getString(key)!) as Map;
    expect(revoked['granted'], isFalse);
    expect(revoked['granted_at'], stored['granted_at']);
    expect(DateTime.tryParse(revoked['revoked_at'] as String), isNotNull);
  });

  test('corrupt stored consent fails closed', () async {
    final preferences = await useLocalPreferences();
    await preferences.setString(
        SharedPreferencesAiProcessingConsentRepository.storageKey('A'),
        'broken JSON');
    expect(await container.read(aiProcessingConsentProvider.notifier).refresh(),
        isFalse);
    expect(container.read(aiProcessingConsentProvider).error, isNotNull);
  });

  test('failed local write retains the previous confirmed value', () async {
    final preferences = MockPreferences();
    final key = SharedPreferencesAiProcessingConsentRepository.storageKey('A');
    final previous = jsonEncode(consent(true));
    when(() => preferences.getString(key)).thenReturn(previous);
    when(() => preferences.setString(key, any()))
        .thenAnswer((_) async => false);
    container.dispose();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      sharedPreferencesProvider.overrideWithValue(preferences),
      aiConsentSavingDelayProvider.overrideWithValue(() async {}),
    ]);
    container.listen(aiProcessingConsentProvider, (_, __) {});
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    expect(await notifier.setGranted(false), isFalse);
    expect(
        container.read(aiProcessingConsentProvider).consent?.granted, isTrue);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    verify(() => preferences.setString(key, previous)).called(1);
  });

  test('account switch during injected delay prevents persistence', () async {
    await container.read(aiProcessingConsentProvider.notifier).refresh();
    final delay = Completer<void>();
    container.updateOverrides([
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
      aiConsentSavingDelayProvider.overrideWithValue(() => delay.future),
    ]);
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final saved = notifier.setGranted(true);
    expect(repository.writes, 0);
    setActor('B');
    container.read(aiProcessingConsentProvider);
    delay.complete();
    expect(await saved, isFalse);
    expect(repository.writes, 0);
  });

  test('A to B to A during delay cannot revive a stale save', () async {
    final delay = Completer<void>();
    container.updateOverrides([
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
      aiConsentSavingDelayProvider.overrideWithValue(() => delay.future),
    ]);
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final saved = notifier.setGranted(true);
    setActor('B');
    setActor('A');
    delay.complete();
    expect(await saved, isFalse);
    expect(repository.writes, 0);
  });

  testWidgets('default save waits two seconds before writing local consent',
      (tester) async {
    final preferences = await useLocalPreferences(mockDelay: false);
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final saved = notifier.setGranted(true);
    final key = SharedPreferencesAiProcessingConsentRepository.storageKey('A');
    expect(container.read(aiProcessingConsentProvider).isSaving, isTrue);
    expect(preferences.containsKey(key), isFalse);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(preferences.containsKey(key), isFalse);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await saved, isTrue);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isTrue);
    expect(preferences.containsKey(key), isTrue);
  });

  test('initial loading and read errors fail closed', () async {
    repository.read = () async => throw StateError('offline');
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    await container.read(aiProcessingConsentProvider.notifier).refresh();
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    expect(container.read(aiProcessingConsentProvider).error, isNotNull);
  });

  test('restores local consent and rejects obsolete disclosure and wrong owner',
      () async {
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    repository.read = () async => consent(true);
    expect(await notifier.refresh(), isTrue);
    repository.read = () async => consent(true, version: 'old');
    expect(await notifier.refresh(), isFalse);
    repository.read = () async => consent(true, owner: 'B');
    expect(await notifier.refresh(), isFalse);
  });

  test('grant is pending until confirmed, duplicate writes cannot overlap',
      () async {
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final pending = Completer<Object?>();
    repository.write = (_) => pending.future;
    final result = notifier.setGranted(true);
    expect(container.read(aiProcessingConsentProvider).isSaving, isTrue);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    expect(await notifier.setGranted(false), isFalse);
    pending.complete(consent(true));
    expect(await result, isTrue);
    expect(repository.writes, 1);
  });

  test('cancelled grant cannot persist or replace a newer pending grant',
      () async {
    final cancelledDelay = Completer<void>();
    final newerDelay = Completer<void>();
    var attempts = 0;
    container.updateOverrides([
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
      aiConsentSavingDelayProvider.overrideWithValue(
        () => attempts++ == 0 ? cancelledDelay.future : newerDelay.future,
      ),
    ]);
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final previous = container.read(aiProcessingConsentProvider);
    final cancelled = notifier.setGranted(true);
    notifier.cancelPendingGrant();
    expect(identical(container.read(aiProcessingConsentProvider), previous),
        isTrue);
    final newer = notifier.setGranted(true);
    cancelledDelay.complete();
    expect(await cancelled, isFalse);
    expect(repository.writes, 0);
    expect(container.read(aiProcessingConsentProvider).isSaving, isTrue);
    newerDelay.complete();
    expect(await newer, isTrue);
    expect(repository.writes, 1);
  });

  test('failed revocation retains confirmed value but cannot authorize AI',
      () async {
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    repository.read = () async => consent(true);
    await notifier.refresh();
    repository.write = (_) async => throw StateError('offline');
    expect(await notifier.setGranted(false), isFalse);
    expect(
        container.read(aiProcessingConsentProvider).consent?.granted, isTrue);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
  });

  test('A response after switching to B cannot authorize B', () async {
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final pending = Completer<Object?>();
    repository.write = (_) => pending.future;
    final result = notifier.setGranted(true);
    setActor('B');
    repository.read = () async => consent(false, owner: 'B');
    container.read(aiProcessingConsentProvider);
    pending.complete(consent(true));
    expect(await result, isFalse);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
  });

  test('cached refresh remains visible but cannot authorize while loading',
      () async {
    repository.read = () async => consent(true);
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    final pending = Completer<Object?>();
    repository.read = () => pending.future;
    final refreshed = notifier.refresh();
    expect(
        container.read(aiProcessingConsentProvider).consent?.isCurrent, isTrue);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    pending.complete(consent(false));
    expect(await refreshed, isFalse);
  });

  test('malformed and unconfirmed grants are rejected', () async {
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    await notifier.refresh();
    for (final response in [
      null,
      {},
      {...consent(true), 'granted_at': null},
      {...consent(true), 'granted': 'true'},
      consent(false)
    ]) {
      repository.write = (_) async => response;
      expect(await notifier.setGranted(true), isFalse);
      expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
    }
  });

  test('a fresh container restores the latest stored consent', () async {
    repository.read = () async => consent(true);
    expect(await container.read(aiProcessingConsentProvider.notifier).refresh(),
        isTrue);
    container.dispose();
    repository.read = () async => consent(false);
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
    ]);
    container.listen(aiProcessingConsentProvider, (_, __) {});
    expect(await container.read(aiProcessingConsentProvider.notifier).refresh(),
        isFalse);
    expect(
        container.read(aiProcessingConsentProvider).consent?.granted, isFalse);
  });

  test('signed-out state does not write consent', () async {
    setActor('');
    final notifier = container.read(aiProcessingConsentProvider.notifier);
    expect(await notifier.refresh(), isFalse);
    expect(await notifier.setGranted(true), isFalse);
    expect(repository.writes, 0);
  });

  Future<void> launch(WidgetTester tester, void Function(bool) result,
      {double scale = 1}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Consumer(
            builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                      onPressed: () async =>
                          result(await ensureAiProcessingConsent(context, ref)),
                      child: const Text('AI')),
                )),
      ),
    ));
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
  }

  testWidgets('dismissal is false and performs no write', (tester) async {
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(repository.writes, 0);
  });

  testWidgets('verified existing consent returns true without disclosure',
      (tester) async {
    repository.read = () async => consent(true);
    bool? result;
    await launch(tester, (value) => result = value);
    expect(result, isTrue);
    expect(find.byType(AiProcessingConsentDialog), findsNothing);
    expect(repository.writes, 0);
  });

  testWidgets('read failure cannot open disclosure or authorize',
      (tester) async {
    repository.read = () async => throw StateError('offline');
    bool? result;
    await launch(tester, (value) => result = value);
    expect(result, isFalse);
    expect(find.byType(AiProcessingConsentDialog), findsNothing);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  testWidgets('slow gate keeps its provider alive without any external watch',
      (tester) async {
    container.dispose();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestConsentAuth.new),
      aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
    ]);
    final pending = Completer<Object?>();
    repository.read = () => pending.future;
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.pump(const Duration(seconds: 1));
    expect(result, isNull);
    pending.complete(consent(true));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('failed grant stays open and retry requires local confirmation',
      (tester) async {
    repository.write = (_) async => throw StateError('offline');
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(AiProcessingConsentDialog), findsOneWidget);
    repository.write = (_) async => consent(true);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets(
      'account change during grant cannot complete another account gate',
      (tester) async {
    final pending = Completer<Object?>();
    repository.write = (_) => pending.future;
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pump();
    setActor('B');
    await tester.pumpAndSettle();
    pending.complete(consent(true));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
  });

  testWidgets('affirmative disclosure persists before returning true',
      (tester) async {
    bool? result;
    final pending = Completer<Object?>();
    repository.write = (_) => pending.future;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pump();
    expect(result, isNull);
    expect(find.text('Saving your choice...'), findsOneWidget);
    pending.complete(consent(true));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('local disclosure shows saving for the default two-second delay',
      (tester) async {
    final preferences = await useLocalPreferences(mockDelay: false);
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pump();
    expect(find.text('Saving your choice...'), findsOneWidget);
    expect(result, isNull);
    final key = SharedPreferencesAiProcessingConsentRepository.storageKey('A');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(result, isNull);
    expect(preferences.containsKey(key), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(preferences.containsKey(key), isTrue);
  });

  for (final dismissal in ['Not now', 'back', 'barrier']) {
    testWidgets(
        'local commit blocks $dismissal until the original action succeeds',
        (tester) async {
      container.dispose();
      container = ProviderContainer(overrides: [
        authProvider.overrideWith(TestConsentAuth.new),
        aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
      ]);
      final pendingWrite = Completer<Object?>();
      repository.write = (_) => pendingWrite.future;
      bool? result;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
              builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                      onPressed: () async => result =
                          await ensureAiProcessingConsent(context, ref),
                      child: const Text('AI'),
                    ),
                  )),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Allow AI processing'));
      await tester.tap(find.text('Allow AI processing'));
      await tester.pump();
      expect(container.read(aiProcessingConsentProvider).isCommitting, isFalse);
      expect(repository.writes, 0);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(repository.writes, 1);
      expect(container.read(aiProcessingConsentProvider).isCommitting, isTrue);

      switch (dismissal) {
        case 'Not now':
          await tester.ensureVisible(find.text('Not now'));
          await tester.tap(find.text('Not now'));
        case 'back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AiProcessingConsentDialog), findsOneWidget);
      expect(result, isNull);
      expect(container.read(aiProcessingConsentProvider).isCommitting, isTrue);
      expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
      pendingWrite.complete(consent(true));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(AiProcessingConsentDialog), findsNothing);
      expect(container.read(aiProcessingConsentProvider).isCommitting, isFalse);
      expect(container.read(aiProcessingConsentProvider).mayProcess, isTrue);
    });

    testWidgets('disclosure $dismissal cancels the pending two-second grant',
        (tester) async {
      final preferences = await useLocalPreferences(mockDelay: false);
      final key =
          SharedPreferencesAiProcessingConsentRepository.storageKey('A');
      final previous = jsonEncode(consent(false));
      await preferences.setString(key, previous);
      final notifier = container.read(aiProcessingConsentProvider.notifier);
      await notifier.refresh();
      bool? result;
      await launch(tester, (value) => result = value);
      await tester.ensureVisible(find.text('Allow AI processing'));
      await tester.tap(find.text('Allow AI processing'));
      await tester.pump();
      expect(container.read(aiProcessingConsentProvider).isSaving, isTrue);
      await tester.pump(const Duration(milliseconds: 1000));

      switch (dismissal) {
        case 'Not now':
          await tester.ensureVisible(find.text('Not now'));
          await tester.tap(find.text('Not now'));
        case 'back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
      }

      // Cancellation must restore state before dismissal animations finish.
      expect(container.read(aiProcessingConsentProvider).isSaving, isFalse);
      expect(
          identical(
              container.read(aiProcessingConsentProvider.notifier), notifier),
          isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AiProcessingConsentDialog), findsNothing);
      expect(preferences.getString(key), previous);
      expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
      expect(result, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed local commit restores dialog dismissal', (tester) async {
    final pendingWrite = Completer<Object?>();
    repository.write = (_) => pendingWrite.future;
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pump();
    expect(container.read(aiProcessingConsentProvider).isCommitting, isTrue);
    pendingWrite.completeError(StateError('local write failed'));
    await tester.pumpAndSettle();
    expect(container.read(aiProcessingConsentProvider).isCommitting, isFalse);
    expect(result, isNull);
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(AiProcessingConsentDialog), findsNothing);
    expect(container.read(aiProcessingConsentProvider).mayProcess, isFalse);
  });

  testWidgets('concurrent capture gates approve only the first caller',
      (tester) async {
    Future<bool>? first;
    Future<bool>? duplicate;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
            builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      first = ensureAiProcessingConsent(context, ref);
                      duplicate = ensureAiProcessingConsent(context, ref);
                    },
                    child: const Text('Two captures'),
                  ),
                )),
      ),
    ));
    await tester.tap(find.text('Two captures'));
    await tester.pumpAndSettle();
    expect(find.byType(AiProcessingConsentDialog), findsOneWidget);
    expect(await duplicate, isFalse);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await duplicate, isFalse);
    expect(repository.writes, 1);
  });

  testWidgets(
      'switching account during local disclosure delay writes neither account',
      (tester) async {
    final preferences = await useLocalPreferences(mockDelay: false);
    bool? result;
    await launch(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pump();
    setActor('B');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(
        preferences.containsKey(
            SharedPreferencesAiProcessingConsentRepository.storageKey('A')),
        isFalse);
    expect(
        preferences.containsKey(
            SharedPreferencesAiProcessingConsentRepository.storageKey('B')),
        isFalse);
  });

  testWidgets('account switch dismisses A disclosure without writing B',
      (tester) async {
    bool? result;
    await launch(tester, (value) => result = value);
    setActor('B');
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(repository.writes, 0);
  });

  testWidgets('disclosure controls remain reachable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester, (_) {}, scale: 2.5);
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
