import 'dart:convert';

import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPendingStore {
  NotificationPendingStore({this.key = 'pending_notification_intents_v1'});

  final String key;

  Future<void> add(NotificationIntent intent) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(key) ?? <String>[];
    existing.add(jsonEncode(intent.toJson()));
    await prefs.setStringList(key, existing);
  }

  Future<List<NotificationIntent>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(key) ?? <String>[];
    return existing
        .map((item) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            return NotificationIntent.fromJson(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<NotificationIntent>()
        .toList(growable: false);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
