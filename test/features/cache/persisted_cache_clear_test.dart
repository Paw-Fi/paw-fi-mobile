import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_cache_store.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';

final _clearPocketsCachesProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  await clearAllPersistedPocketsCachesForUser(ref, userId: userId);
});

final _clearDashboardCachesProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  await clearAllDashboardPersistedCachesForUser(ref, userId: userId);
});

final _clearWalletsCachesProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  await clearAllWalletsCachesForUser(ref, userId: userId);
});

void main() {
  Future<ProviderContainer> buildContainerWithPrefs(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();

    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  group('Persisted cache clearing', () {
    test('clearAllPersistedPocketsCachesForUser removes current matching keys',
        () async {
      const userId = 'user-a';
      final container = await buildContainerWithPrefs({
        'pockets:month:v2:$userId:personal:personal:2026-04:USD:USD:fmsd1:true:false':
            '{}',
        'pockets:month:v2:user-b:personal:personal:2026-04:USD:USD:fmsd1:true:false':
            '{}',
      });
      addTearDown(container.dispose);

      await container.read(_clearPocketsCachesProvider(userId).future);

      final prefs = container.read(sharedPreferencesProvider);
      expect(
        prefs.getString(
            'pockets:month:v2:$userId:personal:personal:2026-04:USD:USD:fmsd1:true:false'),
        isNull,
      );
      expect(
        prefs.getString(
            'pockets:month:v2:user-b:personal:personal:2026-04:USD:USD:fmsd1:true:false'),
        '{}',
      );
    });

    test('clearAllDashboardPersistedCachesForUser removes dashboard keys only',
        () async {
      const userId = 'user-a';
      final container = await buildContainerWithPrefs({
        'dashboard:calendar:v1:$userId:personal:USD:<none>:<none>': '{}',
        'dashboard:recent:v1:$userId:personal:USD:20': '{}',
        'dashboard:budgets:v1:legacy-contact-id': '{}',
        'dashboard:calendar:v1:user-b:personal:USD:<none>:<none>': '{}',
      });
      addTearDown(container.dispose);

      await container.read(_clearDashboardCachesProvider(userId).future);

      final prefs = container.read(sharedPreferencesProvider);
      expect(
        prefs.getString(
            'dashboard:calendar:v1:$userId:personal:USD:<none>:<none>'),
        isNull,
      );
      expect(
        prefs.getString('dashboard:recent:v1:$userId:personal:USD:20'),
        isNull,
      );
      expect(
        prefs.getString('dashboard:budgets:v1:legacy-contact-id'),
        isNull,
      );
      expect(
        prefs.getString(
            'dashboard:calendar:v1:user-b:personal:USD:<none>:<none>'),
        '{}',
      );
    });

    test('clearAllWalletsCachesForUser removes wallets keys only', () async {
      const userId = 'user-a';
      final container = await buildContainerWithPrefs({
        'wallets:list:v2:$userId:personal': '{}',
        'wallets:page-state:v2:$userId:personal:USD:2026-04-01': '{}',
        'wallets:list:v2:user-b:personal': '{}',
      });
      addTearDown(container.dispose);

      await container.read(_clearWalletsCachesProvider(userId).future);

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('wallets:list:v2:$userId:personal'), isNull);
      expect(
        prefs
            .getString('wallets:page-state:v2:$userId:personal:USD:2026-04-01'),
        isNull,
      );
      expect(prefs.getString('wallets:list:v2:user-b:personal'), '{}');
    });

    test('clearAllWalletsCachesForUser removes current local page-state cache',
        () async {
      const userId = 'user-a';
      const cacheKey =
          'wallets:page-state:v6:$userId:personal:USD:2026-04-01:fmsd1:default';
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);
      SharedPreferences.setMockInitialValues({cacheKey: '{}'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localDatabaseProvider.overrideWith((ref) async => database),
        ],
      );
      addTearDown(container.dispose);
      await database.upsertJsonCache(
        namespace: 'wallets_page_state',
        cacheKey: cacheKey,
        payload: const {'total_net_worth': 42},
      );

      await container.read(_clearWalletsCachesProvider(userId).future);

      expect(
        await database.getJsonCache(
          namespace: 'wallets_page_state',
          cacheKey: cacheKey,
        ),
        isNull,
      );
      expect(prefs.getString(cacheKey), isNull);
    });
  });
}
