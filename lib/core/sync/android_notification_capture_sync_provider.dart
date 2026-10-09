import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/features/auth/auth.dart';

final androidNotificationCaptureSyncRevisionProvider =
    StateProvider<int>((ref) => 0);

/// Native captures are outside the SQLite outbox. Start recovery alongside delta
/// sync and reconcile again when a live/background request finishes after a pull.
final androidNotificationCaptureSyncProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return (_) async {};
  }
  final service = NotificationCaptureService.instance;
  var disposed = false;
  var checking = false;

  bool canSync(String userId) =>
      !disposed &&
      userId.isNotEmpty &&
      ref.read(authProvider).uid == userId &&
      !ref.read(previewModeProvider).isActive &&
      !ref.read(userFinancialCacheCleanupInProgressProvider);

  final subscription = service.capturesSynced.listen((userId) {
    if (!canSync(userId)) return;
    ref.read(androidNotificationCaptureSyncRevisionProvider.notifier).state +=
        1;
  });

  Future<void> drain(String userId) async {
    if (!canSync(userId)) return;
    await service.syncPendingCaptures();
  }

  final timer = Timer.periodic(networkReachabilityCheckInterval, (_) async {
    if (disposed ||
        checking ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ref.read(networkReachabilityProvider).valueOrNull == false) {
      return;
    }
    final userId = ref.read(authProvider).uid;
    if (!canSync(userId)) return;
    checking = true;
    try {
      // Also recovers completion events sent before the Flutter bridge existed.
      final status = await service.getPendingCaptureStatus();
      if (canSync(userId) &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (status['remaining'] as num? ?? 0) > 0) {
        await drain(userId);
      }
    } catch (_) {
      // Native storage and WorkManager retain ownership of retryable captures.
    } finally {
      checking = false;
    }
  });
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(subscription.cancel());
  });
  return drain;
});
