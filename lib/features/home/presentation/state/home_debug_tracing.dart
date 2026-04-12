import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef HomeDebugLogSink = void Function(String message);

final homeDebugLoggingEnabledProvider = Provider<bool>((ref) => kDebugMode);

final homeDebugLogSinkProvider = Provider<HomeDebugLogSink>((ref) {
  return debugPrint;
});

class HomeDebugTrace {
  HomeDebugTrace({
    required this.label,
    required this.enabled,
    required this.logSink,
    DateTime Function()? clock,
    Map<String, Object?> contextFields = const <String, Object?>{},
  })  : _clock = clock ?? DateTime.now,
        _contextFields = contextFields,
        _startedAt = (clock ?? DateTime.now)();

  final String label;
  final bool enabled;
  final HomeDebugLogSink logSink;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  final Map<String, Object?> _contextFields;

  void mark(String event,
      [Map<String, Object?> fields = const <String, Object?>{}]) {
    if (!enabled) {
      return;
    }

    final merged = <String, Object?>{
      ...fields,
      ..._contextFields,
    };
    final suffix = _formatHomeDebugFields(merged);
    logSink(
      '[HomeTrace][$label][${_clock().difference(_startedAt).inMilliseconds}ms] $event$suffix',
    );
  }
}

String formatHomeScopeDebug({
  required String scope,
  required String? householdId,
  required String? currency,
}) {
  return [
    'scope=$scope',
    'household=${householdId ?? '<none>'}',
    'currency=${(currency ?? '<none>').toUpperCase()}',
  ].join(' ');
}

String _formatHomeDebugFields(Map<String, Object?> fields) {
  if (fields.isEmpty) {
    return '';
  }

  final entries = fields.entries
      .where((entry) => entry.value != null)
      .map(
          (entry) => MapEntry(entry.key, _stringifyHomeDebugValue(entry.value)))
      .toList(growable: false)
    ..sort((left, right) => left.key.compareTo(right.key));

  if (entries.isEmpty) {
    return '';
  }

  return ' ${entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}';
}

String _stringifyHomeDebugValue(Object? value) {
  if (value == null) {
    return '<null>';
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Iterable) {
    return '[${value.map(_stringifyHomeDebugValue).join(',')}]';
  }
  return value.toString().replaceAll(RegExp(r'\s+'), '_');
}
