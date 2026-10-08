import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Performance monitoring to track slow operations
class PerformanceMonitor {
  static final Map<String, _OperationTracker> _activeOperations = {};

  /// Start tracking an operation
  static void startOperation(String operationName, {String? details}) {
    _activeOperations[operationName] = _OperationTracker(
      name: operationName,
      details: details,
      startTime: DateTime.now(),
    );
  }

  /// Complete tracking an operation
  static void endOperation(String operationName, {bool success = true}) {
    _activeOperations.remove(operationName);
  }

  /// Get currently running operations
  static List<String> getActiveOperations() {
    final now = DateTime.now();
    return _activeOperations.entries.map((e) {
      final duration = now.difference(e.value.startTime);
      return '${e.key} (${duration.inSeconds}s)';
    }).toList();
  }

  /// Clear all tracked operations (use on app reset)
  static void reset() {
    _activeOperations.clear();
  }
}

class _OperationTracker {
  final String name;
  final String? details;
  final DateTime startTime;

  _OperationTracker({
    required this.name,
    this.details,
    required this.startTime,
  });
}

/// Provider to track active operations
final performanceMonitorProvider = Provider((ref) => PerformanceMonitor);

/// Extension to add performance tracking to async operations
extension FuturePerformanceTracking<T> on Future<T> {
  Future<T> trackPerformance(String operationName, {String? details}) async {
    PerformanceMonitor.startOperation(operationName, details: details);
    try {
      final result = await this;
      PerformanceMonitor.endOperation(operationName, success: true);
      return result;
    } catch (e) {
      PerformanceMonitor.endOperation(operationName, success: false);
      rethrow;
    }
  }
}
