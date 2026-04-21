import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef PocketsDebugLogSink = void Function(String message);

final pocketsDebugLoggingEnabledProvider = Provider<bool>((ref) => kDebugMode);

final pocketsDebugLogSinkProvider = Provider<PocketsDebugLogSink>((ref) {
  return debugPrint;
});

class PocketsDebugTrace {
  PocketsDebugTrace({
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
  final PocketsDebugLogSink logSink;
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
    final suffix = _formatPocketsDebugFields(merged);
    logSink(
      '[PocketsTrace][$label][${_clock().difference(_startedAt).inMilliseconds}ms] $event$suffix',
    );
  }
}

String _formatPocketsDebugFields(Map<String, Object?> fields) {
  if (fields.isEmpty) {
    return '';
  }

  final entries = fields.entries
      .where((entry) => entry.value != null)
      .map((entry) =>
          MapEntry(entry.key, _stringifyPocketsDebugValue(entry.value)))
      .toList(growable: false)
    ..sort((left, right) => left.key.compareTo(right.key));

  if (entries.isEmpty) {
    return '';
  }

  return ' ${entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}';
}

String _stringifyPocketsDebugValue(Object? value) {
  if (value == null) {
    return '<null>';
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Iterable) {
    return '[${value.map(_stringifyPocketsDebugValue).join(',')}]';
  }
  return value.toString().replaceAll(RegExp(r'\s+'), '_');
}
