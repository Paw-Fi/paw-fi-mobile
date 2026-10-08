import 'dart:async';

import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Opt-in local diagnostics; never enabled in a release build.
class PerformanceTrace {
  static const _requested = bool.fromEnvironment('MONEKO_PERFORMANCE_TRACE');
  static final _reasonKey = Object();
  static int _nextId = 0;

  @visibleForTesting
  static void Function(Map<String, Object?> event)? testSink;

  static bool get enabled => !kReleaseMode && (_requested || testSink != null);
  static String get reason =>
      Zone.current[_reasonKey] as String? ?? 'provider-read';

  static T withReason<T>(String reason, T Function() action) =>
      runZoned(action, zoneValues: {_reasonKey: reason});

  static PerformanceSpan? start(
    String readType, {
    Map<String, Object?> Function()? identity,
  }) {
    if (!enabled) return null;
    final fields = <String, Object?>{
      'id': ++_nextId,
      'readType': readType,
      'reason': reason,
      for (final entry
          in (identity?.call() ?? const <String, Object?>{}).entries)
        entry.key: _jsonValue(entry.value),
    };
    final task = TimelineTask()..start(readType, arguments: fields);
    _emit({...fields, 'event': 'start'});
    return PerformanceSpan._(task, fields);
  }

  static T measureSync<T>(String readType, T Function() action,
      {Map<String, Object?> Function()? identity}) {
    final span = start(readType, identity: identity);
    try {
      final result = action();
      span?.finish();
      return result;
    } catch (_) {
      span?.finish(success: false);
      rethrow;
    }
  }

  static Future<T> measureAsync<T>(String readType, Future<T> Function() action,
      {Map<String, Object?> Function()? identity}) async {
    final span = start(readType, identity: identity);
    try {
      final result = await action();
      span?.finish();
      return result;
    } catch (_) {
      span?.finish(success: false);
      rethrow;
    }
  }

  static void event(String readType, Map<String, Object?> Function() fields) {
    if (!enabled) return;
    _emit({'readType': readType, 'reason': reason, ...fields()});
  }

  static Object? _jsonValue(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Iterable) return value.map(_jsonValue).toList(growable: false);
    if (value is Map) {
      return value
          .map((key, value) => MapEntry(key.toString(), _jsonValue(value)));
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }

  static void _emit(Map<String, Object?> event) {
    final normalized =
        event.map((key, value) => MapEntry(key, _jsonValue(value)));
    final sink = testSink;
    if (sink != null) {
      sink(normalized);
    }
  }
}

class PerformanceSpan {
  PerformanceSpan._(this._task, this._fields);

  final TimelineTask _task;
  final Map<String, Object?> _fields;
  final Stopwatch _clock = Stopwatch()..start();
  bool _finished = false;

  void finish({bool success = true, Map<String, Object?> fields = const {}}) {
    if (_finished) return;
    _finished = true;
    _clock.stop();
    final result = {
      'success': success,
      'elapsedUs': _clock.elapsedMicroseconds,
      ...fields
    };
    _task.finish(arguments: result);
    PerformanceTrace._emit({..._fields, 'event': 'end', ...result});
  }
}
