import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef WalletsDebugLogSink = void Function(String message);

final walletsDebugLoggingEnabledProvider = Provider<bool>((ref) => kDebugMode);

final walletsDebugLogSinkProvider = Provider<WalletsDebugLogSink>((ref) {
  return debugPrint;
});

String describeWalletsScopeQuery({
  required String userId,
  required String? householdId,
  required String selectedCurrency,
  required DateTime currentMonthStart,
}) {
  return [
    'user=${userId.trim().isEmpty ? '<empty>' : userId.trim()}',
    'household=${_normalizeWalletsDebugValue(householdId)}',
    'currency=${selectedCurrency.trim().toUpperCase()}',
    'month=${_formatWalletsMonth(currentMonthStart)}',
  ].join(' ');
}

String describeWalletsMonthQuery({
  required String userId,
  required String? householdId,
  required String selectedCurrency,
  required DateTime currentMonthStart,
  required DateTime monthStart,
}) {
  return [
    describeWalletsScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: selectedCurrency,
      currentMonthStart: currentMonthStart,
    ),
    'targetMonth=${_formatWalletsMonth(monthStart)}',
  ].join(' ');
}

class WalletsDebugTrace {
  WalletsDebugTrace({
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
  final WalletsDebugLogSink logSink;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  final Map<String, Object?> _contextFields;

  void mark(String event,
      [Map<String, Object?> fields = const <String, Object?>{}]) {
    if (!enabled) {
      return;
    }

    final mergedFields = <String, Object?>{
      ...fields,
      ..._contextFields,
    };
    final suffix = _formatWalletsDebugFields(mergedFields);
    logSink(
      '[WalletsTrace][$label][${_clock().difference(_startedAt).inMilliseconds}ms] $event$suffix',
    );
  }
}

String _formatWalletsDebugFields(Map<String, Object?> fields) {
  if (fields.isEmpty) {
    return '';
  }

  final entries = fields.entries
      .where((entry) => entry.value != null)
      .map((entry) =>
          MapEntry(entry.key, _stringifyWalletsDebugValue(entry.value)))
      .toList(growable: false)
    ..sort((left, right) => left.key.compareTo(right.key));

  if (entries.isEmpty) {
    return '';
  }

  return ' ${entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}';
}

String _stringifyWalletsDebugValue(Object? value) {
  if (value == null) {
    return '<null>';
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Iterable) {
    return '[${value.map(_stringifyWalletsDebugValue).join(',')}]';
  }
  return value.toString().replaceAll(RegExp(r'\s+'), '_');
}

String _normalizeWalletsDebugValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '<none>';
  }
  return trimmed;
}

String _formatWalletsMonth(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
