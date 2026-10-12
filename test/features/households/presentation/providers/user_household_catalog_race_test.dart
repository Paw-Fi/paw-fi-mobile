import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

class _Repository extends Mock implements HouseholdRepository {}

Household _space(String id) => Household(
      id: id,
      name: 'Space $id',
      ownerId: 'u1',
      currency: 'USD',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late ProviderContainer container;
  final original = _space('old');
  final created = _space('new');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Repository();
    container = ProviderContainer(overrides: [
      householdRepositoryProvider.overrideWithValue(repository),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
      preloadedUserHouseholdsProvider('u1').overrideWith((ref) => [original]),
    ]);
  });
  tearDown(() => container.dispose());

  test(
      'a pre-creation read cannot erase the new space or its persisted catalog',
      () async {
    final started = Completer<void>();
    final response = Completer<List<Household>>();
    when(() => repository.getUserHouseholds('u1')).thenAnswer((_) {
      started.complete();
      return response.future;
    });
    final notifier = container.read(userHouseholdsProvider('u1').notifier);
    final loading = notifier.load();
    await started.future;
    notifier.addOrReplaceHousehold(created);
    response.complete([original]);
    await loading;
    expect(container.read(userHouseholdsProvider('u1')).valueOrNull,
        [original, created]);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    final cached =
        jsonDecode(prefs.getString('households:user-list:v1:u1')!) as Map;
    expect((cached['state']['items'] as List).map((row) => row['id']),
        ['old', 'new']);
  });

  test('bootstrap seed updates do not replace the mounted catalog notifier',
      () {
    final notifier = container.read(userHouseholdsProvider('u1').notifier);
    notifier.addOrReplaceHousehold(created);
    container.read(preloadedUserHouseholdsProvider('u1').notifier).state = [
      original
    ];
    expect(
        container.read(userHouseholdsProvider('u1').notifier), same(notifier));
    expect(container.read(userHouseholdsProvider('u1')).valueOrNull,
        [original, created]);
  });

  test('a pre-removal read cannot resurrect a removed space', () async {
    final started = Completer<void>();
    final response = Completer<List<Household>>();
    when(() => repository.getUserHouseholds('u1')).thenAnswer((_) {
      started.complete();
      return response.future;
    });
    final notifier = container.read(userHouseholdsProvider('u1').notifier);
    final loading = notifier.load();
    await started.future;
    notifier.removeHousehold(original.id);
    response.complete([original]);
    await loading;
    expect(container.read(userHouseholdsProvider('u1')).valueOrNull, isEmpty);
  });

  test('failed refresh retains the confirmed created space', () async {
    when(() => repository.getUserHouseholds('u1'))
        .thenThrow(TimeoutException('offline'));
    final notifier = container.read(userHouseholdsProvider('u1').notifier);
    notifier.addOrReplaceHousehold(created);
    await notifier.load();
    expect(container.read(userHouseholdsProvider('u1')).valueOrNull,
        [original, created]);
  });

  test('fresh reads still reconcile authoritative removals', () async {
    when(() => repository.getUserHouseholds('u1'))
        .thenAnswer((_) async => [original]);
    final notifier = container.read(userHouseholdsProvider('u1').notifier);
    notifier.addOrReplaceHousehold(created);
    await notifier.load();
    expect(
        container.read(userHouseholdsProvider('u1')).valueOrNull, [original]);
  });
}
