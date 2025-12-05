import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

/// Performance monitoring to track slow operations
class PerformanceMonitor {
  static final Map<String, _OperationTracker> _activeOperations = {};
  static Timer? _watchdogTimer;
  
  /// Start tracking an operation
  static void startOperation(String operationName, {String? details}) {
    _activeOperations[operationName] = _OperationTracker(
      name: operationName,
      details: details,
      startTime: DateTime.now(),
    );
    
    debugPrint('🚀 [PERF] Started: $operationName ${details != null ? "($details)" : ""}');
    _ensureWatchdog();
  }
  
  /// Complete tracking an operation
  static void endOperation(String operationName, {bool success = true}) {
    final tracker = _activeOperations.remove(operationName);
    if (tracker == null) return;
    
    final duration = DateTime.now().difference(tracker.startTime);
    final emoji = success ? '✅' : '❌';
    final status = success ? 'Completed' : 'Failed';
    
    debugPrint('$emoji [PERF] $status: ${tracker.name} in ${duration.inMilliseconds}ms');
    
    // Log slow operations
    if (duration.inSeconds > 3) {
      debugPrint('⚠️ [PERF] SLOW OPERATION: ${tracker.name} took ${duration.inSeconds}s!');
    }
  }
  
  /// Check for stuck operations
  static void _ensureWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final stuckOps = <String>[];
      
      _activeOperations.forEach((name, tracker) {
        final duration = now.difference(tracker.startTime);
        if (duration.inSeconds > 10) {
          stuckOps.add(name);
          debugPrint('🚨 [PERF] STUCK OPERATION: $name running for ${duration.inSeconds}s!');
          if (tracker.details != null) {
            debugPrint('   Details: ${tracker.details}');
          }
        }
      });
      
      if (stuckOps.isNotEmpty) {
        debugPrint('🚨 [PERF] ${stuckOps.length} operations potentially stuck: ${stuckOps.join(", ")}');
      }
      
      // Stop watchdog if no operations
      if (_activeOperations.isEmpty) {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
      }
    });
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
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    debugPrint('🔄 [PERF] Performance monitor reset');
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
