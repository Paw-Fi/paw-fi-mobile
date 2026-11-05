import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

enum AiExecutionOutcome { needsInput, queued, review, paused, cancelled }

abstract interface class AiExecutionBridge {
  Stream<String> get expired;
  Future<bool> start(Map<String, dynamic> payload);
  Future<void> update(Map<String, dynamic> payload);
  Future<void> finish(Map<String, dynamic> payload);
  Future<void> dispose();
}

class MethodChannelAiExecutionBridge implements AiExecutionBridge {
  MethodChannelAiExecutionBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'expired' && call.arguments is String) {
        _expired.add(call.arguments as String);
      }
    });
  }

  static const _channel = MethodChannel('moneko/ai_background_execution');
  final _expired = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> get expired => _expired.stream;

  @override
  Future<bool> start(Map<String, dynamic> payload) async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      return false;
    }
    try {
      // A denied notification permission must not discard a captured input.
      await Permission.notification.request();
    } catch (_) {
      // Native execution may still be available when permission UI is absent.
    }
    return await _channel.invokeMethod<bool>('start', payload) ?? false;
  }

  @override
  Future<void> update(Map<String, dynamic> payload) =>
      _channel.invokeMethod<void>('update', payload);
  @override
  Future<void> finish(Map<String, dynamic> payload) =>
      _channel.invokeMethod<void>('finish', payload);
  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _expired.close();
  }
}

class AiExecutionLease {
  AiExecutionLease(this.id, this.messages);
  final String id;
  final Map<String, String> messages;
  bool _granted = false;
  bool _ended = false;
  bool _interrupted = false;
  final _interruption = Completer<void>();
  bool get isInterrupted => _interrupted;
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
  AiBackgroundExecution(this._bridge) {
    _expirationSubscription = _bridge.expired.listen((id) {
      if (_active?.id == id) {
        _active!._interrupt();
      }
    });
  }

  final AiExecutionBridge _bridge;
  late final StreamSubscription<String> _expirationSubscription;
  AiExecutionLease? _active;
  AiExecutionLease? _attention;
  AiExecutionLease? _notice;
  bool _presentationAllowed = true;
  bool _disposed = false;
  int _attempt = 0;
  final _deferredPresentation = <void Function()>[];

  Future<AiExecutionLease> start(String captureId,
      {required Map<String, String> messages}) async {
    final lease = AiExecutionLease(
        '$captureId:${DateTime.now().microsecondsSinceEpoch}:${++_attempt}',
        Map.unmodifiable(messages));
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
    try {
      lease._granted = await _bridge.start(_payload(lease));
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
    lease._ended = true;
    _active = null;
    _notice = outcome == AiExecutionOutcome.cancelled ? null : lease;
    _attention = outcome == AiExecutionOutcome.needsInput ||
            outcome == AiExecutionOutcome.paused
        ? lease
        : null;
    await _send(
        () => _bridge.finish({..._payload(lease), 'outcome': outcome.name}));
  }

  Future<void> revoke() async {
    _deferredPresentation.clear();
    final lease = _active ?? _attention ?? _notice;
    _active = null;
    _attention = null;
    _notice = null;
    if (lease == null) return;
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
    await _bridge.dispose();
  }
}

final aiExecutionBridgeProvider =
    Provider<AiExecutionBridge>((ref) => MethodChannelAiExecutionBridge());

final aiBackgroundExecutionProvider = Provider<AiBackgroundExecution>((ref) {
  final owner = AiBackgroundExecution(ref.read(aiExecutionBridgeProvider));
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
    if (previous?.uid != next.uid) unawaited(owner.revoke());
  });
  ref.listen(aiProcessingConsentProvider, (_, next) {
    if (!next.mayProcess) unawaited(owner.revoke());
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
    };

// English catalog fallbacks until the normal translation export generates members.
extension AiBackgroundLocalizations on AppLocalizations {
  String get aiBackgroundNeedsInput => 'Open Moneko to answer a question.';
  String get aiBackgroundQueued =>
      'Analysis complete. Transactions queued to sync.';
  String get aiBackgroundPaused => 'Analysis paused. Open Moneko to continue.';
  String get aiBackgroundChannel => 'Expense analysis';
  String get aiBackgroundReview => 'Analysis complete. Open Moneko to review.';
}
