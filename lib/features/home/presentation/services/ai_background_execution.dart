import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_cancellation_provider.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

enum AiExecutionOutcome { needsInput, queued, review, error, paused, cancelled }

abstract class AiExecutionBridge {
  Stream<String> get expired;
  Stream<String> get stopped => const Stream.empty();
  Future<List<Map<String, dynamic>>> pendingStops() async => [];
  Future<void> acknowledgeStop(String id) async {}
  Future<List<Map<String, dynamic>>> pendingFailures() async => [];
  Future<void> acknowledgeFailure(String id) async {}
  Future<bool> start(Map<String, dynamic> payload);
  Future<void> update(Map<String, dynamic> payload);
  Future<void> finish(Map<String, dynamic> payload);

  /// Removes native presentation that no in-memory attempt owns, such as an
  /// attention state left behind by a previous process.
  Future<void> clear() async {}
  Future<void> dispose();
}

class MethodChannelAiExecutionBridge extends AiExecutionBridge {
  MethodChannelAiExecutionBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'expired' && call.arguments is String) {
        _expired.add(call.arguments as String);
      } else if (call.method == 'stopped' && call.arguments is String) {
        _stopped.add(call.arguments as String);
      }
    });
  }

  static const _channel = MethodChannel('moneko/ai_background_execution');
  final _expired = StreamController<String>.broadcast(sync: true);
  final _stopped = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> get expired => _expired.stream;
  @override
  Stream<String> get stopped => _stopped.stream;

  @override
  Future<List<Map<String, dynamic>>> pendingStops() async {
    return _pendingRecords('pendingStops');
  }

  @override
  Future<List<Map<String, dynamic>>> pendingFailures() =>
      _pendingRecords('pendingFailures');

  Future<List<Map<String, dynamic>>> _pendingRecords(String method) async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      return [];
    }
    try {
      final rows = await _channel.invokeListMethod<dynamic>(method);
      return [
        for (final row in rows ?? []) Map<String, dynamic>.from(row as Map)
      ];
    } on MissingPluginException {
      return [];
    }
  }

  @override
  Future<void> acknowledgeStop(String id) =>
      _channel.invokeMethod<void>('acknowledgeStop', {'id': id});
  @override
  Future<void> acknowledgeFailure(String id) =>
      _channel.invokeMethod<void>('acknowledgeFailure', {'id': id});

  @override
  Future<bool> start(Map<String, dynamic> payload) async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      return false;
    }
    try {
      // A denied notification permission must not discard a captured input.
      await _requestNotificationPermissionOnce();
    } catch (_) {
      // Native execution may still be available when permission UI is absent.
    }
    return await _channel.invokeMethod<bool>('start', payload) ?? false;
  }

  static const _permissionRequestedKey =
      'ai_background_notification_permission_requested';

  /// Asks at most once, in context of the first background-capable analysis.
  /// Later denials are respected; Settings remains the place to change them.
  /// Completes before `start` so iOS is active when the Live Activity starts.
  Future<void> _requestNotificationPermissionOnce() async {
    if (!(await Permission.notification.status).isDenied) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_permissionRequestedKey) == true) return;
    await preferences.setBool(_permissionRequestedKey, true);
    await Permission.notification.request();
  }

  @override
  Future<void> update(Map<String, dynamic> payload) =>
      _channel.invokeMethod<void>('update', payload);
  @override
  Future<void> finish(Map<String, dynamic> payload) =>
      _channel.invokeMethod<void>('finish', payload);
  @override
  Future<void> clear() async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // No native presentation exists on this host.
    }
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _expired.close();
    await _stopped.close();
  }
}

class AiExecutionLease {
  AiExecutionLease(this.id, this.messages,
      {required this.captureId, required this.userId});
  final String id;
  final String captureId;
  final String userId;
  final Map<String, String> messages;
  bool _granted = false;
  bool _ended = false;
  bool _interrupted = false;
  bool _cancelled = false;
  final _interruption = Completer<void>();
  bool get isInterrupted => _interrupted;
  bool get isCancelled => _cancelled;
  bool get canRunInBackground => _granted && !_ended;

  void _interrupt() {
    _ended = true;
    _interrupted = true;
    if (!_interruption.isCompleted) _interruption.complete();
  }

  Future<T> untilInterrupted<T>(Future<T> operation) => Future.any([
        operation,
        _interruption.future
            .then<T>((_) => throw const AiExecutionInterrupted()),
      ]);
}

class AiExecutionInterrupted implements Exception {
  const AiExecutionInterrupted();
}

/// Execution lifetime belongs to the application, not the submitting widget.
/// Financial data and retry ownership remain in the existing capture/outbox.
class AiBackgroundExecution {
  AiBackgroundExecution(this._bridge, {Future<void> Function()? onStopped}) {
    _expirationSubscription = _bridge.expired.listen((id) {
      if (_active?.id == id) {
        _active!._interrupt();
      }
    });
    _stopSubscription = _bridge.stopped.listen((id) {
      stopAttempt(id);
      // The durable journal is acknowledged only after SQLite commits Stop.
      if (onStopped != null) unawaited(onStopped().catchError((Object _) {}));
    });
  }

  final AiExecutionBridge _bridge;
  late final StreamSubscription<String> _expirationSubscription;
  late final StreamSubscription<String> _stopSubscription;
  AiExecutionLease? _active;
  AiExecutionLease? _attention;
  AiExecutionLease? _notice;
  bool _presentationAllowed = true;
  bool _disposed = false;
  int _attempt = 0;
  final _deferredPresentation = <void Function()>[];

  void stopAttempt(String id) {
    final lease = _active ?? _attention ?? _notice;
    if (lease?.id != id) return;
    lease!._cancelled = true;
    lease._interrupt();
    _deferredPresentation.clear();
  }

  Future<AiExecutionLease> start(String captureId,
      {required Map<String, String> messages,
      String userId = '',
      AiExecutionOutcome? initialOutcome,
      Future<void> Function(String id)? beforeStart}) async {
    final lease = AiExecutionLease(
        '$captureId:${DateTime.now().microsecondsSinceEpoch}:${++_attempt}',
        Map.unmodifiable(messages),
        captureId: captureId,
        userId: userId);
    if (_disposed) {
      lease._ended = true;
      return lease;
    }
    final previous = _active ?? _attention ?? _notice;
    if (previous != null) previous._interrupt();
    _active = lease;
    _attention = null;
    _notice = null;
    if (previous != null) {
      await _send(() =>
          _bridge.finish({..._payload(previous), 'outcome': 'cancelled'}));
    }
    if (_disposed || _active != lease) {
      lease._ended = true;
      return lease;
    }
    // Capture attempt identity must be durable before native Stop is exposed.
    try {
      if (beforeStart != null) await beforeStart(lease.id);
    } catch (_) {
      lease._interrupt();
      if (_active == lease) _active = null;
      rethrow;
    }
    if (_disposed || _active != lease || lease.isInterrupted) return lease;
    try {
      final granted = await _bridge.start({
        ..._payload(lease),
        if (initialOutcome != null) 'outcome': initialOutcome.name
      });
      lease._granted = initialOutcome == null && granted;
    } catch (_) {
      // Foreground processing and durable resume still work without a lease.
    }
    if (_disposed || _active != lease) {
      lease._ended = true;
      await _send(
          () => _bridge.finish({..._payload(lease), 'outcome': 'cancelled'}));
    }
    return lease;
  }

  Map<String, dynamic> _payload(AiExecutionLease lease) => {
        'id': lease.id,
        'captureId': lease.captureId,
        'userId': lease.userId,
        'messages': lease.messages,
        'background': !_presentationAllowed,
      };

  Future<void> update(AiExecutionLease lease, String stage) async {
    if (_disposed || _active != lease || lease._ended) return;
    await _send(() => _bridge.update({..._payload(lease), 'stage': stage}));
  }

  Future<void> setPresentationAllowed(bool allowed) async {
    _presentationAllowed = allowed;
    if (allowed && !_disposed) {
      final callbacks = List<void Function()>.from(_deferredPresentation);
      _deferredPresentation.clear();
      for (final callback in callbacks) {
        callback();
      }
    }
    final lease = _active ?? _attention;
    if (_disposed || lease == null) return;
    await _send(() => _bridge.update(_payload(lease)));
  }

  void presentWhenAllowed(void Function() callback) {
    if (_disposed) return;
    if (_presentationAllowed) {
      callback();
    } else {
      _deferredPresentation.add(callback);
    }
  }

  Future<void> finish(
      AiExecutionLease lease, AiExecutionOutcome outcome) async {
    if (_disposed || _active != lease) return;
    if (lease.isCancelled) outcome = AiExecutionOutcome.cancelled;
    lease._ended = true;
    _active = null;
    _notice = outcome == AiExecutionOutcome.cancelled ? null : lease;
    _attention = outcome == AiExecutionOutcome.needsInput ||
            outcome == AiExecutionOutcome.error ||
            outcome == AiExecutionOutcome.paused
        ? lease
        : null;
    await _send(
        () => _bridge.finish({..._payload(lease), 'outcome': outcome.name}));
  }

  /// [clearOrphans] also removes native presentation that this process does
  /// not own, so a previous actor's attention state cannot remain visible.
  Future<void> revoke({bool clearOrphans = false}) async {
    _deferredPresentation.clear();
    final lease = _active ?? _attention ?? _notice;
    _active = null;
    _attention = null;
    _notice = null;
    if (lease == null) {
      if (clearOrphans && !_disposed) await _send(_bridge.clear);
      return;
    }
    lease._interrupt();
    await _send(
        () => _bridge.finish({..._payload(lease), 'outcome': 'cancelled'}));
  }

  Future<void> _send(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Notification/OS failures cannot rewrite financial or capture state.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await revoke();
    await _expirationSubscription.cancel();
    await _stopSubscription.cancel();
    await _bridge.dispose();
  }
}

final aiExecutionBridgeProvider =
    Provider<AiExecutionBridge>((ref) => MethodChannelAiExecutionBridge());

/// Native expiration may run just before suspension. Recover its durable marker
/// before foreground resume can reinterpret that interruption as an auto-retry.
Future<void> reconcileAiInputFailures(ProviderContainer container) async {
  final bridge = container.read(aiExecutionBridgeProvider);
  for (final failure in await bridge.pendingFailures()) {
    final repository =
        await container.read(aiInputCaptureRepositoryProvider.future);
    final captures = await repository.pending(failure['userId'] as String);
    for (final capture in captures) {
      if (capture.id != failure['captureId'] ||
          capture.payload['executionId'] != failure['id']) {
        continue;
      }
      if (capture.payload['requiresAnalysisRetry'] != true) {
        await repository.checkpoint(capture, {'requiresAnalysisRetry': true});
      }
    }
    await bridge.acknowledgeFailure(failure['id'] as String);
  }
}

final aiBackgroundExecutionProvider = Provider<AiBackgroundExecution>((ref) {
  final owner = AiBackgroundExecution(ref.read(aiExecutionBridgeProvider),
      onStopped: () => ref.read(aiInputCancellationProvider).reconcile());
  void publishVisibility() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    unawaited(owner.setPresentationAllowed(
      (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          !ref.read(appLockControllerProvider).shouldBlockApp,
    ));
  }

  final lifecycle =
      AppLifecycleListener(onStateChange: (_) => publishVisibility());
  ref.listen(appLockControllerProvider, (previous, next) {
    publishVisibility();
    if (previous?.shouldBlockApp == true && !next.shouldBlockApp) {
      ref.read(aiInputResumeControllerProvider).wake();
      ref.read(aiInputResumeSignalProvider.notifier).state += 1;
    }
  });
  ref.listen(authProvider, (previous, next) {
    // Session restoration (empty -> actor) keeps a previous process's attention
    // presentation for the same user; a real actor change removes it.
    if (previous?.uid != next.uid) {
      unawaited(owner.revoke(
          clearOrphans: previous?.uid.isNotEmpty == true));
    }
  });
  ref.listen(aiProcessingConsentProvider, (_, next) {
    if (!next.mayProcess) unawaited(owner.revoke(clearOrphans: true));
  });
  publishVisibility();
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(owner.dispose());
  });
  return owner;
});

Map<String, String> aiExecutionMessages(AppLocalizations l10n) => {
      'title': l10n.appTitle,
      'analyzing': l10n.analyzingExpense,
      'saving': l10n.aiProgressFinishingUp,
      'needsInput': l10n.aiBackgroundNeedsInput,
      'queued': l10n.aiBackgroundQueued,
      'paused': l10n.aiBackgroundPaused,
      'review': l10n.aiBackgroundReview,
      'channel': l10n.aiBackgroundChannel,
      'attentionChannel': l10n.aiBackgroundAttentionChannel,
      'stop': l10n.aiBackgroundStop,
      'cancel': l10n.cancel,
      'loadingTitle': l10n.aiBackgroundLoadingTitle,
      'successTitle': l10n.aiBackgroundSuccessTitle,
      'errorTitle': l10n.aiBackgroundErrorTitle,
      'confirmationTitle': l10n.aiBackgroundConfirmationTitle,
      'error': l10n.aiBackgroundError,
    };

// English catalog fallbacks until the normal translation export generates members.
extension AiBackgroundLocalizations on AppLocalizations {
  String get aiBackgroundLoadingTitle => 'Analyzing';
  String get aiBackgroundSuccessTitle => 'Analysis complete';
  String get aiBackgroundErrorTitle => 'Analysis failed';
  String get aiBackgroundConfirmationTitle => 'Confirmation required';
  String get aiBackgroundError =>
      'Analysis could not finish. Open Moneko to retry or cancel.';
  String get aiBackgroundStop => 'Stop';
  String get aiBackgroundNeedsInput =>
      'Additional confirmation required. Open Moneko to continue.';
  String get aiBackgroundQueued =>
      'Analysis complete. Transactions queued to sync.';
  String get aiBackgroundPaused => 'Analysis paused. Open Moneko to continue.';
  String get aiBackgroundChannel => 'Expense analysis';
  String get aiBackgroundAttentionChannel => 'Expense analysis alerts';
  String get aiBackgroundReview => 'Analysis complete. Open Moneko to review.';
}
