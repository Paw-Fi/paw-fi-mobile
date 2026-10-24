import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

WalletEntity wallet(String id,
        {String? householdId, String currency = 'MYR'}) =>
    WalletEntity(
      id: id,
      userId: 'user-1',
      householdId: householdId,
      name: id,
      icon: 'wallet',
      color: '#6B7280',
      currency: currency,
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 0,
    );

const personalMyr = WalletsCurrencyQuery(householdId: null, currency: 'MYR');

void main() {
  test('a preloaded Space catalog supplies currency options synchronously',
      () async {
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        return [
          wallet('myr'),
          wallet('eur', currency: 'EUR'),
          wallet('archived').copyWith(isArchived: true),
          wallet('other-space', householdId: 'shared'),
        ];
      }),
    ]);
    addTearDown(container.dispose);
    await container
        .read(shortcutDestinationWalletsByHouseholdIdProvider(null).future);

    final options = container.read(walletsByCurrencyProvider(personalMyr));

    expect(options.isLoading, isFalse);
    expect(options.requireValue.map((item) => item.id), ['myr']);
    expect(reads, 1);
    final eur = container.read(walletsByCurrencyProvider(
        const WalletsCurrencyQuery(householdId: null, currency: ' eur ')));
    expect(eur.requireValue.single.id, 'eur');
    expect(reads, 1);
  });

  test('unknown catalog stays loading until the shared request resolves',
      () async {
    final pending = Completer<List<WalletEntity>>();
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) => pending.future),
    ]);
    addTearDown(container.dispose);
    final options = container.read(walletsByCurrencyProvider(personalMyr));
    expect(options.isLoading, isTrue);
    expect(options.hasValue, isFalse);
    pending.complete([wallet('loaded')]);
    expect(
      (await container.read(walletsByCurrencyProvider(personalMyr).future))
          .single
          .id,
      'loaded',
    );
  });

  test('optimistic rename, creation and archive do not refetch the catalog',
      () async {
    var reads = 0;
    final saved = wallet('saved');
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        return [saved];
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      saved.id: saved.copyWith(name: 'Renamed'),
      'new': wallet('new'),
      'foreign': wallet('foreign', currency: 'EUR'),
      'shared': wallet('shared', householdId: 'shared'),
    };
    final options = container.read(walletsByCurrencyProvider(personalMyr));
    expect(options.isLoading, isFalse);
    expect(options.requireValue.map((item) => item.id), ['saved', 'new']);
    expect(options.requireValue.first.name, 'Renamed');
    expect(reads, 1);

    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      saved.id: saved.copyWith(isArchived: true),
    };
    expect(container.read(walletsByCurrencyProvider(personalMyr)).requireValue,
        isEmpty);
    expect(reads, 1);
  });

  test('Space changes use independent catalogs and never borrow old options',
      () async {
    final shared = Completer<List<WalletEntity>>();
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        if (scope == null) return [wallet('personal')];
        return shared.future;
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    const sharedQuery =
        WalletsCurrencyQuery(householdId: 'shared', currency: 'MYR');
    expect(container.read(walletsByCurrencyProvider(sharedQuery)).hasValue,
        isFalse);
    shared.complete([wallet('shared-wallet', householdId: 'shared')]);
    expect(
      (await container.read(walletsByCurrencyProvider(sharedQuery).future))
          .single
          .id,
      'shared-wallet',
    );
  });

  test('cached options survive catalog refresh and a retryable failure',
      () async {
    final pending = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('cached')];
        return pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .id,
        'cached');
    pending.completeError(const SocketException('Network is unreachable'));
    await container.pump();
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .id,
        'cached');
  });

  test('an uncached catalog error is not reported as an empty wallet list',
      () async {
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        throw StateError('unavailable');
      }),
    ]);
    addTearDown(container.dispose);
    await expectLater(
      container.read(walletsByCurrencyProvider(personalMyr).future),
      throwsStateError,
    );
    expect(container.read(walletsByCurrencyProvider(personalMyr)).hasValue,
        isFalse);
  });

  test(
      'successful refresh replaces cached names without refetching per currency',
      () async {
    final pending = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('saved')];
        return pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(walletsByCurrencyProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .name,
        'saved');
    pending.complete([wallet('saved').copyWith(name: 'Server rename')]);
    await container.pump();
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .name,
        'Server rename');
    expect(reads, 2);
  });

  test(
      'newer optimistic edits survive catalog refresh until rollback clears them',
      () async {
    final pending = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('saved')];
        return pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(walletsByCurrencyProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      'saved': wallet('saved').copyWith(name: 'First edit'),
    };
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      'saved': wallet('saved').copyWith(name: 'Newer edit'),
    };
    pending.complete([wallet('saved')]);
    await container.pump();
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .name,
        'Newer edit');
    container.read(optimisticScopedAccountsOverridesProvider.notifier).state =
        {};
    expect(
        container
            .read(walletsByCurrencyProvider(personalMyr))
            .requireValue
            .single
            .name,
        'saved');
    expect(reads, 2);
  });

  test(
      'a new editor cannot reuse the previous actor catalog during account switch',
      () async {
    final actor = StateProvider((ref) => 'actor-a');
    final nextActor = Completer<List<WalletEntity>>();
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        if (ref.watch(actor) == 'actor-a') {
          return [
            wallet('actor-a-myr'),
            wallet('actor-a-eur', currency: 'EUR')
          ];
        }
        return nextActor.future;
      }),
    ]);
    addTearDown(container.dispose);
    await container
        .read(shortcutDestinationWalletsByHouseholdIdProvider(null).future);
    final subscription =
        container.listen(walletsByCurrencyProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.read(actor.notifier).state = 'actor-b';
    const query = WalletsCurrencyQuery(householdId: null, currency: 'EUR');
    final options = container.read(walletsByCurrencyStateProvider(query));
    expect(options.valueOrNull, isNull);
    expect(
        container.read(walletsByCurrencyStateProvider(personalMyr)).valueOrNull,
        isNull);
    nextActor.complete([wallet('actor-b-eur', currency: 'EUR')]);
    await container.read(walletsByCurrencyProvider(query).future);
  });

  test(
      'an authoritative scope denial is not turned into successful cached options',
      () async {
    final denied = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('revoked')];
        return denied.future;
      }),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(walletsByCurrencyProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    container.read(walletsByCurrencyProvider(personalMyr));
    denied.completeError(const FunctionException(
        status: 403,
        details: {'code': 'UNAUTHORIZED', 'error': 'Forbidden scope'}));
    await container.pump();
    expect(container.read(walletsByCurrencyStateProvider(personalMyr)).hasError,
        isTrue);
    expect(
        container.read(walletsByCurrencyStateProvider(personalMyr)).valueOrNull,
        isNull);
  });

  test('retrying a denied catalog does not resurrect revoked options',
      () async {
    final retry = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('revoked')];
        if (reads == 2) throw const FunctionException(status: 403);
        return retry.future;
      }),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
        walletsByCurrencyStateProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    await container.pump();
    expect(container.read(walletsByCurrencyStateProvider(personalMyr)).hasError,
        isTrue);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    final options = container.read(walletsByCurrencyStateProvider(personalMyr));
    expect(options.valueOrNull, isNull);
    retry.complete([wallet('authorized')]);
    await container.pump();
    expect(
        container
            .read(walletsByCurrencyStateProvider(personalMyr))
            .requireValue
            .single
            .id,
        'authorized');
  });

  for (final status in [400, 401, 403, 404, 408, 425, 429, 500, 503]) {
    test(
        'cached selector handles HTTP $status without hiding authoritative denial',
        () async {
      final response = Completer<List<WalletEntity>>();
      var reads = 0;
      final container = ProviderContainer(overrides: [
        shortcutDestinationWalletsByHouseholdIdProvider
            .overrideWith((ref, scope) {
          reads++;
          if (reads == 1) return [wallet('cached')];
          return response.future;
        }),
      ]);
      addTearDown(container.dispose);
      final subscription = container.listen(
          walletsByCurrencyStateProvider(personalMyr), (_, __) {});
      addTearDown(subscription.close);
      await container.read(walletsByCurrencyProvider(personalMyr).future);
      container
          .invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
      container.read(walletsByCurrencyStateProvider(personalMyr));
      response.completeError(FunctionException(status: status));
      await container.pump();
      final options =
          container.read(walletsByCurrencyStateProvider(personalMyr));
      if ([408, 425, 429, 500, 503].contains(status)) {
        expect(options.requireValue.single.id, 'cached');
      } else {
        expect(options.hasError, isTrue);
        expect(options.valueOrNull, isNull);
      }
      expect(reads, 2);
    });
  }

  test('an older successful refresh cannot overwrite a newer catalog',
      () async {
    final older = Completer<List<WalletEntity>>();
    final newer = Completer<List<WalletEntity>>();
    var reads = 0;
    final container = ProviderContainer(overrides: [
      shortcutDestinationWalletsByHouseholdIdProvider
          .overrideWith((ref, scope) {
        reads++;
        if (reads == 1) return [wallet('initial')];
        return reads == 2 ? older.future : newer.future;
      }),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
        walletsByCurrencyStateProvider(personalMyr), (_, __) {});
    addTearDown(subscription.close);
    await container.read(walletsByCurrencyProvider(personalMyr).future);
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    container.read(walletsByCurrencyStateProvider(personalMyr));
    container.invalidate(shortcutDestinationWalletsByHouseholdIdProvider(null));
    container.read(walletsByCurrencyStateProvider(personalMyr));
    newer.complete([wallet('newer')]);
    await container.pump();
    older.complete([wallet('older')]);
    await container.pump();
    expect(
        container
            .read(walletsByCurrencyStateProvider(personalMyr))
            .requireValue
            .single
            .id,
        'newer');
    expect(reads, 3);
  });
}
