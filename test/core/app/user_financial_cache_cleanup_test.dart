import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void main() {
  test('logout clears persisted data for all five main tabs', () async {
    const userId = 'user-a';
    const homeKey = 'dashboard:calendar:v1:$userId:personal:USD:<none>:<none>';
    const pocketsKey =
        'pockets:month:v2:$userId:personal:personal:2026-07:USD:USD:fmsd1:true:false';
    const walletsKey =
        'wallets:list:v7:$userId:personal:USD:2026-07-01:default';
    const otherUserPocketsKey =
        'pockets:month:v2:user-b:personal:personal:2026-07:USD:USD:fmsd1:true:false';

    SharedPreferences.setMockInitialValues({
      homeKey: '{}',
      pocketsKey: '{}',
      walletsKey: '[]',
      otherUserPocketsKey: '{}',
    });
    final prefs = await SharedPreferences.getInstance();
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
    addTearDown(container.dispose);

    final sqliteEntries = {
      'home_dashboard_snapshot': 'home:$userId',
      'recurring_transactions': 'recurring:$userId',
      'pockets_month': pocketsKey,
      'wallets_page_state':
          'wallets:page-state:v6:$userId:personal:USD:2026-07-01:fmsd1:default',
      'monthly_report': 'monthly-report:v8:$userId:personal:2026-07',
    };
    for (final entry in sqliteEntries.entries) {
      await database.upsertJsonCache(
        namespace: entry.key,
        cacheKey: entry.value,
        payload: const {'stale': true},
      );
    }

    await container
        .read(userFinancialCacheCleanupProvider)
        .clearForLogout(userId: userId);

    expect(prefs.getString(homeKey), isNull);
    expect(prefs.getString(pocketsKey), isNull);
    expect(prefs.getString(walletsKey), isNull);
    expect(prefs.getString(otherUserPocketsKey), '{}');
    for (final entry in sqliteEntries.entries) {
      expect(
        await database.getJsonCache(
          namespace: entry.key,
          cacheKey: entry.value,
        ),
        isNull,
      );
    }
  });

  test('preference cleanup continues when the local database fails', () async {
    const userId = 'user-a';
    const homeKey = 'dashboard:calendar:v1:$userId:personal:USD:<none>:<none>';
    const pocketsKey =
        'pockets:month:v2:$userId:personal:personal:2026-07:USD:USD:fmsd1:true:false';
    const walletsKey =
        'wallets:list:v7:$userId:personal:USD:2026-07-01:default';
    SharedPreferences.setMockInitialValues({
      homeKey: '{}',
      pocketsKey: '{}',
      walletsKey: '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDatabaseProvider.overrideWith(
          (ref) => Future<MonekoDatabase>.error(
            StateError('database unavailable'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(userFinancialCacheCleanupProvider)
          .clearForLogout(userId: userId),
      throwsStateError,
    );

    expect(prefs.getString(homeKey), isNull);
    expect(prefs.getString(pocketsKey), isNull);
    expect(prefs.getString(walletsKey), isNull);
  });

  test('logout keeps the main shell suspended until sign out completes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
    addTearDown(container.dispose);
    final signOutCompleter = Completer<void>();

    final logout =
        container.read(userFinancialCacheCleanupProvider).clearForLogout(
              userId: 'user-a',
              signOut: () => signOutCompleter.future,
            );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(userFinancialCacheCleanupInProgressProvider),
      isTrue,
    );

    signOutCompleter.complete();
    await logout;
    expect(
      container.read(userFinancialCacheCleanupInProgressProvider),
      isFalse,
    );
  });

  test('failed financial reset keeps the main shell suspended', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDatabaseProvider.overrideWith(
          (ref) => Future<MonekoDatabase>.error(
            StateError('database unavailable'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(userFinancialCacheCleanupProvider)
          .clearForFinancialDataReset(userId: 'user-a'),
      throwsStateError,
    );

    expect(
      container.read(userFinancialCacheCleanupInProgressProvider),
      isTrue,
    );
  });
}
