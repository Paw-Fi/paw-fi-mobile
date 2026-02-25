import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/init_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InitCacheManager', () {
    test('load invalidates on version change; loadBestEffort still loads',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final manager = InitCacheManager(prefs);

      await manager.save(
        {
          'user': {'id': 'u1'},
          'timestamp': DateTime.now().toIso8601String(),
        },
        '1.0.0+1',
      );

      expect(manager.load('2.0.0+1'), isNull);
      expect(manager.loadBestEffort('2.0.0+1'), isNotNull);
    });

    test('loadBestEffort respects expiry even across version changes',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final manager = InitCacheManager(prefs);

      await manager.save(
        {
          'user': {'id': 'u1'},
          'timestamp': DateTime.now().toIso8601String(),
        },
        '1.0.0+1',
      );

      final expiredTimestamp = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;
      await prefs.setInt('app_init_cache_timestamp_v2', expiredTimestamp);

      expect(manager.loadBestEffort('2.0.0+1'), isNull);
    });

    test('loadBestEffort returns null on corrupted JSON', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'app_init_cache_v2': '{not valid json',
        'app_init_cache_timestamp_v2': now,
        'app_init_cache_version': '1.0.0+1',
      });

      final prefs = await SharedPreferences.getInstance();
      final manager = InitCacheManager(prefs);

      expect(manager.loadBestEffort('2.0.0+1'), isNull);
    });

    test('loadBestEffort returns decoded map', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'user': {'id': 'u1'},
        'subscription': null,
        'households': const [],
        'timestamp': DateTime.now().toIso8601String(),
      };
      SharedPreferences.setMockInitialValues({
        'app_init_cache_v2': jsonEncode(payload),
        'app_init_cache_timestamp_v2': now,
        'app_init_cache_version': '1.0.0+1',
      });

      final prefs = await SharedPreferences.getInstance();
      final manager = InitCacheManager(prefs);

      final loaded = manager.loadBestEffort('2.0.0+1');
      expect(loaded, isA<Map<String, dynamic>>());
      expect(loaded?['user'], isA<Map>());
    });
  });
}
