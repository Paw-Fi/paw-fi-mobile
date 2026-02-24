import 'package:shared_preferences/shared_preferences.dart';

class NotificationDedupeStore {
  NotificationDedupeStore({
    this.key = 'notifications_handled_v1',
    this.ttl = const Duration(hours: 24),
  });

  final String key;
  final Duration ttl;

  Future<bool> hasHandled(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getStringList(key) ?? <String>[];
    final keep = <String>[];
    var found = false;

    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length != 2) {
        continue;
      }
      final seenId = parts[0];
      final seenAt = int.tryParse(parts[1]) ?? 0;
      if (nowMs - seenAt > ttl.inMilliseconds) {
        continue;
      }
      keep.add(entry);
      if (seenId == id) {
        found = true;
      }
    }

    if (keep.length != raw.length) {
      await prefs.setStringList(key, keep);
    }

    return found;
  }

  Future<void> markHandled(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getStringList(key) ?? <String>[];
    raw.add('$id|$nowMs');
    await prefs.setStringList(key, raw);
  }
}
