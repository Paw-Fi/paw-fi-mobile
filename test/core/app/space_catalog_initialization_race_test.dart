import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/services/init_cache_manager.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'u1', email: 'user@example.com');
}

class _Repository implements HouseholdRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Household _space(String id) => Household(
    id: id,
    name: 'Space $id',
    ownerId: 'u1',
    currency: 'USD',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in const [
    (empty: false, cached: false),
    (empty: true, cached: false),
    (empty: false, cached: true),
  ]) {
    final emptySnapshot = scenario.empty;
    final cachedSnapshot = scenario.cached;
    test(
        '${cachedSnapshot ? 'cached catalog: ' : ''}late ${emptySnapshot ? 'empty' : 'old'} startup snapshot cannot remove or deselect a confirmed new space',
        () async {
      final original = _space('old');
      final created = _space('new');
      SharedPreferences.setMockInitialValues(cachedSnapshot
          ? {
              'app_init_cache_version': '1+1',
              'app_init_cache_timestamp_v2':
                  DateTime.now().millisecondsSinceEpoch,
              'app_init_cache_v2': jsonEncode({
                'household_cache_schema_version': 1,
                'households': [original.toJson()],
                'timestamp': DateTime(2026).toIso8601String()
              }),
              'households:user-list:v1:u1': jsonEncode({
                'state': {
                  'items': [original.toJson(), created.toJson()]
                }
              }),
            }
          : {});
      PackageInfo.setMockInitialValues(
          appName: 'Moneko',
          packageName: 'moneko',
          version: '1',
          buildNumber: '1',
          buildSignature: 'test');
      InitCacheManagerProvider.reset();
      final prefs = await SharedPreferences.getInstance();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await Supabase.initialize(
          url: 'https://example.test',
          anonKey: 'test-key',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/initialize_app_v2')) {
              started.complete();
              final queued = await response.future;
              return http.Response(queued.body, queued.statusCode,
                  headers: queued.headers, request: request);
            }
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }));
      addTearDown(() async {
        await Supabase.instance.dispose();
        InitCacheManagerProvider.reset();
      });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        householdRepositoryProvider.overrideWithValue(_Repository()),
        preloadedUserHouseholdsProvider('u1')
            .overrideWith((ref) => cachedSnapshot ? null : [original]),
      ]);
      addTearDown(container.dispose);
      final completed = Completer<void>();
      container.listen(appInitializationV2Provider, (previous, next) {
        if (next.hasFreshData && !completed.isCompleted) {
          completed.complete();
        }
      });
      await started.future.timeout(const Duration(seconds: 3), onTimeout: () {
        throw StateError(container
            .read(appInitializationV2Provider.notifier)
            .getDebugSnapshot()
            .toString());
      });
      final catalog = container.read(userHouseholdsProvider('u1').notifier);
      final beforeFresh =
          container.read(userHouseholdsProvider('u1')).valueOrNull;
      catalog.addOrReplaceHousehold(created);
      await container
          .read(selectedHouseholdProvider.notifier)
          .selectHousehold(created.id);
      container.read(viewModeProvider.notifier).setMode(ViewMode.household);
      response.complete(http.Response(
          jsonEncode({
            'households': emptySnapshot ? [] : [original.toJson()]
          }),
          200,
          headers: {'content-type': 'application/json'}));
      await completed.future.timeout(const Duration(seconds: 3), onTimeout: () {
        throw StateError(container
            .read(appInitializationV2Provider.notifier)
            .getDebugSnapshot()
            .toString());
      });
      await Future<void>.delayed(Duration.zero);
      if (cachedSnapshot) expect(beforeFresh, [original, created]);
      expect(
          container.read(userHouseholdsProvider('u1').notifier), same(catalog));
      expect(container.read(userHouseholdsProvider('u1')).valueOrNull,
          [original, created]);
      expect(container.read(selectedHouseholdProvider).householdId, created.id);
      expect(container.read(viewModeProvider).mode, ViewMode.household);
      expect(container.read(appInitializationV2Provider).data?.households,
          [original, created]);
      final cache = jsonDecode(prefs.getString('app_init_cache_v2')!) as Map;
      expect((cache['households'] as List).map((row) => row['id']),
          ['old', 'new']);
    });
  }
}
