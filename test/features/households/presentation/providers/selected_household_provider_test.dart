import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

Household _household(String id) {
  final now = DateTime(2024, 1, 1);
  return Household(
    id: id,
    name: 'Household $id',
    ownerId: 'owner',
    currency: 'USD',
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer _container({
  required SharedPreferences prefs,
  required AppUser user,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(() => _TestAuth(user)),
    ],
  );
  return container;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('boots householdId from per-user SharedPreferences key', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'h2');

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, 'h2');
    expect(state.household, isNull);
  });

  test('does not boot a persisted optimistic household ID', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'selected_household_id:u1',
      'optimistic-household-1783843926425266',
    );

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, isNull);
    expect(state.household, isNull);
  });

  test(
      'initialize resolves saved legacy selection and migrates to per-user key',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id', 'h2');

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    await container
        .read(selectedHouseholdProvider.notifier)
        .initialize(preloadedHouseholds: [_household('h1'), _household('h2')]);

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, 'h2');
    expect(state.household?.id, 'h2');

    expect(prefs.getString('selected_household_id:u1'), 'h2');
    expect(prefs.getString('selected_household_id'), isNull);
  });

  test(
      'initialize prefers legacy when per-user key is stale and migrates correctly',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'hx');
    await prefs.setString('selected_household_id', 'h2');

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    await container
        .read(selectedHouseholdProvider.notifier)
        .initialize(preloadedHouseholds: [_household('h1'), _household('h2')]);

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, 'h2');
    expect(state.household?.id, 'h2');

    expect(prefs.getString('selected_household_id:u1'), 'h2');
    expect(prefs.getString('selected_household_id'), isNull);
  });

  test('initialize does not overwrite a valid saved selection', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'h2');

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    await container
        .read(selectedHouseholdProvider.notifier)
        .initialize(preloadedHouseholds: [_household('h1'), _household('h2')]);

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, 'h2');
    expect(state.household?.id, 'h2');
  });

  test('initialize refreshes metadata for the same selected household ID',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'h2');
    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);
    final notifier = container.read(selectedHouseholdProvider.notifier);

    await notifier.initialize(preloadedHouseholds: [_household('h2')]);
    expect(container.read(selectedHouseholdProvider).household?.isPortfolio,
        isFalse);

    await notifier.initialize(
      preloadedHouseholds: [_household('h2').copyWith(isPortfolio: true)],
    );

    expect(container.read(selectedHouseholdProvider).household?.isPortfolio,
        isTrue);
  });

  test('clearSelection removes persisted keys for current user', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'h2');
    await prefs.setString('selected_household_id', 'h2');

    final container = _container(
      prefs: prefs,
      user: const AppUser(uid: 'u1', email: 'u1@example.com'),
    );
    addTearDown(container.dispose);

    await container.read(selectedHouseholdProvider.notifier).clearSelection();

    final state = container.read(selectedHouseholdProvider);
    expect(state.householdId, isNull);
    expect(state.household, isNull);

    expect(prefs.getString('selected_household_id:u1'), isNull);
    expect(prefs.getString('selected_household_id'), isNull);
  });

  test('late empty initialization cannot clear a newly selected space',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com'))),
      preloadedUserHouseholdsProvider('u1').overrideWith((ref) => []),
      householdRepositoryProvider.overrideWithValue(_UnusedRepository()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(selectedHouseholdProvider.notifier);
    final initializing = notifier.initialize();
    container
        .read(userHouseholdsProvider('u1').notifier)
        .addOrReplaceHousehold(_household('new'));
    await notifier.selectHousehold('new');
    await initializing;
    expect(container.read(selectedHouseholdProvider).householdId, 'new');
    expect(prefs.getString('selected_household_id:u1'), 'new');
  });

  for (final clear in [false, true]) {
    test('late selection cannot replace a newer ${clear ? 'clear' : 'space'}',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final response = Completer<Household?>();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
            () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com'))),
        preloadedUserHouseholdsProvider('u1')
            .overrideWith((ref) => [_household('new')]),
        householdRepositoryProvider.overrideWithValue(_UnusedRepository()),
        householdProvider('slow').overrideWith((ref) => response.future),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(selectedHouseholdProvider.notifier);
      final stale = notifier.selectHousehold('slow');
      if (clear) {
        await notifier.clearSelection();
      } else {
        await notifier.selectHousehold('new');
      }
      response.complete(_household('slow'));
      await stale;
      expect(container.read(selectedHouseholdProvider).householdId,
          clear ? null : 'new');
      expect(prefs.getString('selected_household_id:u1'), clear ? null : 'new');
    });
  }
}

class _UnusedRepository implements HouseholdRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
