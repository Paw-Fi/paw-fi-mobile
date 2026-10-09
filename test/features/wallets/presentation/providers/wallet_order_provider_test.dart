import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_order_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const personal = (userId: 'u1', householdId: null, isPreview: false);

class ControlledOrderStore extends WalletOrderStore {
  ControlledOrderStore(super.preferences);
  final writes = <Completer<void>>[];

  @override
  Future<void> save(WalletOrderScope scope, List<String> ids) {
    final result = Completer<void>();
    writes.add(result);
    return result.future;
  }
}

class TestWalletOrderNotifier extends WalletOrderNotifier {
  TestWalletOrderNotifier(super.scope, super.store);
  List<String> get current => state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hydrates synchronously and restores saved order in a fresh container',
      () async {
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer create() => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]);
    final first = create();
    expect(first.read(walletOrderProvider(personal)), isEmpty);
    final save =
        first.read(walletOrderProvider(personal).notifier).reorder(['b', 'a']);
    expect(first.read(walletOrderProvider(personal)), ['b', 'a']);
    await save;
    first.dispose();
    await prefs.reload();
    final restarted = create();
    addTearDown(restarted.dispose);
    expect(restarted.read(walletOrderProvider(personal)), ['b', 'a']);
  });

  test(
      'scope separates actors, Spaces and preview; old global order is ignored',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('wallet_accounts_order', ['legacy']);
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await container
        .read(walletOrderProvider(personal).notifier)
        .reorder(['b', 'a']);
    for (final scope in [
      (userId: 'u2', householdId: null, isPreview: false),
      (userId: 'u1', householdId: 'space', isPreview: false),
      (userId: 'u1', householdId: null, isPreview: true),
    ]) {
      expect(container.read(walletOrderProvider(scope)), isEmpty);
    }
  });

  test('filtered reorders retain hidden wallets and append new wallets stably',
      () {
    final merged = mergeVisibleWalletOrder(['a', 'hidden', 'b'], ['b', 'a']);
    expect(merged, ['b', 'hidden', 'a']);
    expect(applyWalletOrder(['new', 'a', 'b', 'hidden'], merged, (id) => id),
        ['b', 'hidden', 'a', 'new']);
    expect(applyWalletOrder(['a', 'b'], ['deleted', 'b', 'b'], (id) => id),
        ['b', 'a']);
  });

  test('terminal local failure restores the last durable order', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(walletOrderStorageKey(personal), ['a', 'b']);
    final store = ControlledOrderStore(prefs);
    final notifier = TestWalletOrderNotifier(personal, store);
    addTearDown(notifier.dispose);
    final save = notifier.reorder(['b', 'a']);
    final expectation = expectLater(save, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.current, ['b', 'a']);
    store.writes.single.completeError(StateError('disk failure'));
    await expectation;
    expect(notifier.current, ['a', 'b']);
  });

  test('writes serialize and an older failure cannot overwrite a newer reorder',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ControlledOrderStore(prefs);
    final notifier = TestWalletOrderNotifier(personal, store);
    addTearDown(notifier.dispose);
    final first = notifier.reorder(['b', 'a', 'c']);
    final firstError = expectLater(first, throwsStateError);
    final second = notifier.reorder(['c', 'b', 'a']);
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, hasLength(1));
    store.writes.first.completeError(StateError('first disk failure'));
    await firstError;
    await Future<void>.delayed(Duration.zero);
    expect(notifier.current, ['c', 'b', 'a']);
    expect(store.writes, hasLength(2));
    store.writes.last.complete();
    await second;
    expect(notifier.current, ['c', 'b', 'a']);
  });

  test('a latest failure restores the preceding successful overlapping write',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ControlledOrderStore(prefs);
    final notifier = TestWalletOrderNotifier(personal, store);
    addTearDown(notifier.dispose);
    final first = notifier.reorder(['b', 'a', 'c']);
    final second = notifier.reorder(['c', 'b', 'a']);
    final secondError = expectLater(second, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    store.writes.first.complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    store.writes.last.completeError(StateError('second disk failure'));
    await secondError;
    expect(notifier.current, ['b', 'a', 'c']);
  });
}
