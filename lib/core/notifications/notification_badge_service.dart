import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The launcher badge represents notifications received while Moneko is away.
/// Opening the app acknowledges it independently of auth and push registration.
class NotificationBadgeService {
  AppLifecycleListener? _lifecycleListener;

  void start() {
    if (_lifecycleListener != null) return;
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(clear()),
    );
    // A cold launch may already be resumed before the listener is installed.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      unawaited(clear());
    }
  }

  Future<void> clear() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (_) {
      // Unsupported launchers/plugin failures must not interrupt navigation.
      // The next app resume or notification tap will try again.
    }
  }

  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}

final notificationBadgeServiceProvider = Provider<NotificationBadgeService>(
  (ref) {
    final service = NotificationBadgeService();
    ref.onDispose(service.dispose);
    return service;
  },
);
