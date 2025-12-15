import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

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

  test('initialize resolves saved legacy selection and migrates to per-user key',
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
}
